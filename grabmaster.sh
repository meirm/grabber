#!/bin/bash
# Released under GPL License
# by Meir Michanie 
# meirm@riunx.com
# Version October 2017
# Fist version October 2006
SLAVES=${SLAVES:-3}
TRANS_DIR=${TRANS_DIR:-$HOME}
DAEMONIZER=${DAEMONIZER:-daemon.pl}
GRABBER=`which grabber.sh`
 
mkdir -p $TRANS_DIR/Grabber/{log,queue,spool,varlock,tmp}

case $1  in  

	start)
	for i in `seq 1 $SLAVES`; do daemon.pl $GRABBER grabber$i $TRANS_DIR/Grabber;done
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
	find $TRANS_DIR/Grabber/varlock/ -type f -exec rm {} \;
	for i in `seq 1 $SLAVES`; do daemon.pl $GRABBER grabber$i $TRANS_DIR/Grabber;done
	$0 status
	;;

	status)
	ps -ef | grep grabber.s[h]
	;;

	stop)
	for i in `seq 1 $SLAVES`; do touch $TRANS_DIR/Grabber/varlock/grabber$i.stop;done
	;;

	force-stop)
	killall grabber.sh
	find $TRANS_DIR/Grabber/varlock/ -type f -exec rm {} \;
	;;

	clear-queue)
	find $TRANS_DIR/Grabber/queue/ -type f -exec rm {} \;
	;;

	clear-spool)
	find $TRANS_DIR/Grabber/spool/ -type f -exec rm {} \;
	;;

	clear-all)
	$0 clear-spool
	$0 clear-queue
	;;

	queue)
	find $TRANS_DIR/Grabber/queue -type f -ls
	;;

	spool)
	find $TRANS_DIR/Grabber/spool -type f -ls
	;;

	test)
	for i in `seq 1 $SLAVES`; do echo "date;sleep 10" > $TRANS_DIR/Grabber/queue/task$i.sh;done
	;;

	usage|*)
	echo
	echo
	echo "Grabmaster - grabber by Meir Michanie meirm@riunx.com"
	echo "Released under GPL License"
	echo
	echo "Usage:"
	echo $0 "[start|status|stop|cond-restart|restart|force-stop|clear-queue|clear-spool|clear-all|queue|spool|test]"
	echo
	echo "[daemon.pl] grabber.sh grabberuniquename queue"
	echo "grabber.sh grabber1 /home/mark/Transformation/Grabber"
	;;	
esac
