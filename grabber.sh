#!/bin/bash
# Released under GPL License
# by Meir Michanie 
# meirm ( at ) riunx.com
# Version 0.4 Oct 2017
# Version 0.3 June 2017
# Version 0.2 April 2017
# Version 0.1 October 2006

##### Support functions
printerror() {
echo $@  1>&2
}

printusage() {
printerror "Usage:" 
printerror "$0 <grabbername> <clusterpath>"
}

###########

if [ $# -ne 2 ] ; then
	printusage $0
	exit 0
fi

if [ ! -d "$2" ] ; then
	printerror "CRITICAL: <clusterpath>  dir ($2)  doesn't exist"
	exit 1
fi

export GRABBERNAME=$1;
export CLUSTERPATH=$2;
export QUEUEVARLOCK="$CLUSTERPATH/varlock";
export QUEUE="$CLUSTERPATH/queue/";
export SPOOL="$CLUSTERPATH/spool/$GRABBERNAME";
export CTRLQUEUE="$CLUSTERPATH/ctrl/$GRABBERNAME";
export SPOOLLOG="$CLUSTERPATH/log";
export LOCKFILE=$QUEUEVARLOCK/$GRABBERNAME.lock
if [ -f $LOCKFILE ]; then
	printerror  "Error: Grabber $GRABBERNAME already running"
	printerror  "or stalled, remove $LOCKFILE"
	printerror  "and try again"
	exit 251;
fi
if [ ! -d $QUEUE ] ; then
	printerror "CRITICAL: QUEUE: $QUEUE dir doesn't exist"
	exit 1
fi
umask 0002
# We take jobs by moving the scripts to our own spool.
mkdir -p $SPOOL || ( printerror "CRITICAL: SPOOL $SPOOL can't be created"; exit 2)
# Besides being able to take jobs from a common queue, we can take jobs from our dedicated ctrl queue.
# Jobs in the ctrl queue have priotity to the jobs in the common queue.
mkdir -p $CTRLQUEUE || ( printerror "CRITICAL: CTRLQUEUE $CTRLQUEUE can't be created"; exit 2)

#Avoid running twice on the same directory 
[ -f $LOCKFILE ] && ( printerror "MAJOR: Lockfile exists, exiting to avoid running twice"; exit 3) 
# Upon exit, remove lockfile.
trap "{ rm -f $LOCKFILE ; exit 255; }" EXIT

# Create lockfile
echo $$ > $LOCKFILE

# Start our infinite job patrol
while [ true ] ; do
	# In order to know that we are still running we update the lockfile.
	# this maybe problematic on a Raspberry pi or any other filesystem running on a SDcard or SSD.
	touch $LOCKFILE

	# Try to pick a job from our dedicated queue if empty, try then the common queue.
	ACTIVEQ=$CTRLQUEUE
        FILE=`ls -1 $ACTIVEQ/ | head -n 1`;
        if [ "X$FILE" != "X" -a -f "$ACTIVEQ/$FILE" ] ; then
		# running from ctrl dir
		true
	else
		ACTIVEQ=$QUEUE
        	FILE=`ls -1 $ACTIVEQ/ | head -n 1`;
	fi

	# If there is a job pending try to grab it by moving the jobfile to our own spool 
        if [ "X$FILE" != "X" -a -f "$ACTIVEQ/$FILE" ] ; then
                printerror "GRABBER: $GRABBERNAME testing file $FILE";
                DATE=`date "+%Y%m%d%H%M%S"`
                mv $ACTIVEQ/$FILE $SPOOL/$FILE-$DATE
		# Check if we succeeded to grab the job, if not continue the loop.
                if [ -f "$SPOOL/$FILE-$DATE" ]; then
			# Prepare jobfile for execution.
			mv $SPOOL/$FILE-$DATE $SPOOL/$FILE-$DATE-RUNNING
			if [ ! -x $SPOOL/$FILE-$DATE-RUNNING ]; then 
				chmod +x $SPOOL/$FILE-$DATE-RUNNING
			fi
			RET=0;
			printerror "GRABBER: $GRABBERNAME running $FILE"
			# Execute jobfile
                        $SPOOL/$FILE-$DATE-RUNNING >$SPOOL/$FILE-$DATE.log 2>$SPOOL/$FILE-$DATE.err
                        RET=$?
			# Rename file after execution according if it finished error free or not.
                        if [ "$RET" == "0" ]; then
                                mv $SPOOL/$FILE-$DATE-RUNNING $SPOOL/$FILE-$DATE-DONE
                        else
				if [ "$RET"  == "124" ]; then 
                                	mv $SPOOL/$FILE-$DATE-RUNNING $SPOOL/$FILE-$DATE-TIMEOUT
				else
                                	mv $SPOOL/$FILE-$DATE-RUNNING $SPOOL/$FILE-$DATE-FAILED
				fi
                        fi
			# Keep tali 
			echo "$FILE,$DATE,ExitCode($RET)">> $SPOOLLOG/grab.log
                fi
        fi
	# We sleep for 3 seconds in order to avoid CPU hog
	sleep 3;

	# Allow us to pause grabbers
        while [ -f $QUEUEVARLOCK/$GRABBERNAME.pause ]; do
		if [ -s $QUEUEVARLOCK/$GRABBERNAME.pause ]; then
                	touch $QUEUEVARLOCK/$GRABBERNAME.pause
		else
			echo Paused > $QUEUEVARLOCK/$GRABBERNAME.pause
		fi
                sleep 3;
        done

	# If we have a flag to stop, we cleanup after ourselves and we exit.
	if [ -f $QUEUEVARLOCK/$GRABBERNAME.stop ]; then
		rm $QUEUEVARLOCK/$GRABBERNAME.stop
		# We remove the lockfile trapping the exit of the script
		#rm $LOCKFILE
		exit 0;
	fi
done
