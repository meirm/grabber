#!/bin/bash
# Released under GPL License
# by Meir Michanie 
# meirm@riunx.com
# Version February 2019
# Fist version October 2006
SLAVES=${SLAVES:-3}
GRAB_BASEDIR=${GRAB_BASEDIR:-$HOME}
DAEMONIZER=${DAEMONIZER:-daemon.pl}
GRABBER=`which grabber.sh`
WORKERNAME=${WORKERNAME:-grabber}
 
mkdir -p $GRAB_BASEDIR/Grabber/{log,queue,spool,varlock,tmp}

case $1  in  

	start)
	for i in `seq 1 $SLAVES`; do $DAEMONIZER $GRABBER $WORKERNAME$i $GRAB_BASEDIR/Grabber;done
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
	ps -ef | grep grabber.s[h]
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
	for i in `seq 1 $SLAVES`; do echo "date;sleep 10" > $GRAB_BASEDIR/Grabber/queue/task$i.sh;done
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
