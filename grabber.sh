#!/bin/bash
# Released under GPL License
# by Meir Michanie 
# meirm ( at ) riunx.com
# Version 0.4 Oct 2017
# Version 0.3 June 2017
# Version 0.2 April 2017
# Version 0.1 October 2006

printerror() {
echo $@  1>&2
}

printusage() {
printerror "Usage:" 
printerror "$0 <grabbername> <clusterpath>"
}

if [ $# = 0 ] ; then
	printusage $0
	exit 0
fi
export GRABBERNAME=$1;
export CLUSTERPATH=$2;
export QUEUEVARLOCK="$CLUSTERPATH/varlock";
export QUEUE="$CLUSTERPATH/queue/";
export SPOOL="$CLUSTERPATH/spool/$GRABBERNAME";
export CTRLQUEUE="$CLUSTERPATH/ctrl/$GRABBERNAME";
export SPOOLLOG="$CLUSTERPATH/log";
if [ -f $QUEUEVARLOCK/$GRABBERNAME.lock ]; then
	printerror  "Error: Grabber $GRABBERNAME already running"
	printerror  "or stalled, remove $QUEUEVARLOCK/$GRABBERNAME.lock"
	printerror  "and try again"
	exit 251;
fi
umask 0002
mkdir -p $SPOOL;
mkdir -p $CTRLQUEUE;
echo $$ > $QUEUEVARLOCK/$GRABBERNAME.lock
while [ true ] ; do
	touch $QUEUEVARLOCK/$GRABBERNAME.lock
	ACTIVEQ=$CTRLQUEUE
        FILE=`ls -1 $ACTIVEQ/ | head -n 1`;
        if [ "X$FILE" != "X" -a -f "$ACTIVEQ/$FILE" ] ; then
		# running from ctrl dir
		true
	else
		ACTIVEQ=$QUEUE
        	FILE=`ls -1 $ACTIVEQ/ | head -n 1`;
	fi

        if [ "X$FILE" != "X" -a -f "$ACTIVEQ/$FILE" ] ; then
                printerror "GRABBER: $GRABBERNAME testing file $FILE";
                DATE=`date "+%Y%m%d%H%M%S"`
                mv $ACTIVEQ/$FILE $SPOOL/$FILE-$DATE
                if [ -f "$SPOOL/$FILE-$DATE" ]; then
			mv $SPOOL/$FILE-$DATE $SPOOL/$FILE-$DATE-RUNNING
			if [ ! -x $SPOOL/$FILE-$DATE-RUNNING ]; then 
				chmod +x $SPOOL/$FILE-$DATE-RUNNING
			fi
			RET=0;
			printerror "GRABBER: $GRABBERNAME running $FILE"
                        $SPOOL/$FILE-$DATE-RUNNING >$SPOOL/$FILE-$DATE.log 2>$SPOOL/$FILE-$DATE.err
                        RET=$?
                        if [ "$RET" == "0" ]; then
                                mv $SPOOL/$FILE-$DATE-RUNNING $SPOOL/$FILE-$DATE-DONE
                        else
				if [ "$RET"  == "124" ]; then 
                                	mv $SPOOL/$FILE-$DATE-RUNNING $SPOOL/$FILE-$DATE-TIMEOUT
				else
                                	mv $SPOOL/$FILE-$DATE-RUNNING $SPOOL/$FILE-$DATE-FAILED
				fi
                        fi
			echo "$FILE,$DATE,ExitCode($RET)">> $SPOOLLOG/grab.log
                fi
        fi
	sleep 3;
        while [ -f $QUEUEVARLOCK/$GRABBERNAME.pause ]; do
                touch $QUEUEVARLOCK/$GRABBERNAME.onhold
                sleep 3;
        done

	if [ -f $QUEUEVARLOCK/$GRABBERNAME.stop ]; then
		rm $QUEUEVARLOCK/$GRABBERNAME.stop
		rm $QUEUEVARLOCK/$GRABBERNAME.lock
		exit 0;
	fi
done
