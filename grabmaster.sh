#!/bin/bash
# Released under GPL License
# by Meir Michanie 
# meirm@riunx.com
# Version February 2019

#####
# Support functions.
on_error(){
 lvl=$1;
 shift
 if [ $lvl -ne 0 ]; then
	 echo "$@"
	 exit $lvl
 fi
}

##### 
# Set some basic values
# ---------------------
# You can override these values with exported environment variables.

# SLAVES are the number of grabbers we will launch
SLAVES=${SLAVES:-3}

# GRAB_BASEDIR is the hosting branch of our grabber directory structure
# $GRAB_BASEDIR/Grabber
#                   |_> log
#                   |_> queue
#                   |_> spool
#                   |_> varlock
#                   |_> tmp
GRAB_BASEDIR=${GRAB_BASEDIR:-$HOME}

# We use daemon.pl from http://github.com/meirm/ instead of nohup
# daemon.pl by default sends all output to /dev/null and runs the program in the background
# if we need to redirect or put in background as when running nohup
DAEMONIZER=${DAEMONIZER:-daemon.pl}
DAEMONIZER_REDIR=""
#DAEMONIZER="nohup"
#DAEMONIZER_REDIR=">/dev/null &"

# We need to have the grabber command in our executable path or
# we need to provide the full path to the executable.
GRABBER=`which grabber.sh`

# By default each grabber share a common prefix in its name and only get a number for differentiation.
WORKERNAME=${WORKERNAME:-grabber}

######

# In case that we choose to use daemon.pl and it is not available, fall back to nohup
which $DAEMONIZER > /dev/null
if [ $? -ne 0 ] ; then # fallback to nohup
	on_error 1 "Critical: $DAEMONIZER is not executable"
fi

# We make sure that we have a workable filesystem to work on.
mkdir -p $GRAB_BASEDIR/Grabber/{log,queue,spool,varlock,tmp}
on_error $? "Critical: Failed to create Grabber directory in $GRAB_BASEDIR/"

case $1  in  

	start)
		for i in `seq 1 $SLAVES`; do 
			echo "$DAEMONIZER $GRABBER $WORKERNAME$i $GRAB_BASEDIR/Grabber $DAEMONIZER_REDIR";
			$DAEMONIZER $GRABBER $WORKERNAME$i $GRAB_BASEDIR/Grabber $DAEMONIZER_REDIR;
		done
	$0 status 
	;;

	cond-restart)
	if [ `$0 status | wc -l` -lt $SLAVES ] ;then 
		$0 start
	fi
	if [ `$0 status | wc -l` -lt $SLAVES ] ;then 
		$0 restart	
	fi
	;;

	restart)
	killall grabber.sh
	find $GRAB_BASEDIR/Grabber/varlock/ -type f -exec rm {} \;
	for i in `seq 1 $SLAVES`; do $DAEMONIZER $GRABBER $WORKERNAME$i $GRAB_BASEDIR/Grabber;done
	$0 status
	;;

	status)
	ps -ef | grep grabber.sh | grep $WORKERNAME | grep -v grep
	;;

	stop)
	for i in `seq 1 $SLAVES`; do touch $GRAB_BASEDIR/Grabber/varlock/$WORKERNAME$i.stop;done
	;;

	force-stop)
	killall grabber.sh
	find $GRAB_BASEDIR/Grabber/varlock/ -type f -exec rm {} \;
	;;

	clear-queue)
	find $GRAB_BASEDIR/Grabber/queue/ -type f -exec rm {} \;
	;;

	clear-spool)
	find $GRAB_BASEDIR/Grabber/spool/ -type f -exec rm {} \;
	;;

	clear-all)
	$0 clear-spool
	$0 clear-queue
	;;

	queue)
	find $GRAB_BASEDIR/Grabber/queue -type f -ls
	;;

	spool)
	find $GRAB_BASEDIR/Grabber/spool -type f -ls
	;;

	test)
		(( nr_tasks=$SLAVES + 3 )) 
		for i in `seq 1 $nr_tasks`; do 
			random_sleep=`echo $RANDOM | tail -c 3`
			echo "date;sleep $random_sleep" > $GRAB_BASEDIR/Grabber/queue/task$i.sh;
		done
	;;

	usage|help|*)
	echo
	echo
	echo "Grabmaster - grabber by Meir Michanie meirm@riunx.com"
	echo "Released under GPL License"
	echo
	echo "Environment variables:"
	echo "WORKERNAME # default value 'grabber'"
	echo "SLAVES # default value 3"
	echo 'GRAB_BASEDIR # default value $HOME'
	echo 'DAEMONIZER # default value daemon.pl'
	echo
	echo "Usage:"
	echo $0 "[start|status|stop|cond-restart|restart|force-stop|clear-queue|clear-spool|clear-all|queue|spool|test]"
	echo
	;;	
esac
