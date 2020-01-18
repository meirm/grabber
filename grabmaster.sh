#!/bin/bash
# Released under GPL License
# by Meir Michanie 
# meirm@riunx.com
# Version February 2019
SCRIPTVERSION="0.1"
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
SCRIPTNAME="$( basename $0)"
VERBOSE=${VERBOSE:-"0"}


log_echo(){
    ERROR=0;INFO=1;DEBUG=2;
    literal=$1;shift
    eval lvl='$'"$literal"
    msg="$@"
    if [ "$lvl" -ge $VERBOSE ]; then
        echo "$literal: $msg"
    fi
}

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

usage(){
        echo
        echo
        echo "Grabmaster - grabber by Meir Michanie meirm@riunx.com"
        echo "Released under GPL License v2"
        echo
        echo "Config file: ~/.grabberrc"
        echo 
        echo "Environment variables:"
        echo "WORKERNAME # default value 'grabber'"
        echo "SLAVES # default value 3"
        echo 'GRAB_BASEDIR # default value $HOME'
        echo 'DAEMONIZER # default value daemon.pl'
        echo
        echo "Usage:"
        echo $SCRIPTNAME "[OPTIONS] [start|status|stop|cond-restart|restart|force-stop|clear-queue|clear-spool|clear-all|queue|spool|test]"
        echo "options: -v n #verbose level: 0,1,2"
        echo
        exit $1
}

function create_config {
    log_echo "DEBUG" "Creating config file at $HOME/.grabberrc"
    cat << EOF
####################
# Default location:
# ~/.grabberrc
#
# To use another file set the var GRABBERCONF
####################
SLAVES=2
# GRAB_BASEDIR is the hosting branch of our grabber directory structure
# GRAB_BASEDIR/Grabber
#                   |_> log # Here we keep a tali
#                   |_> queue # Common queue for grabbers to fetch a job to execute
#                   |_> spool/<grabnameX> # Here each grabber will grab the jobfile
#                   |_> ctrl/<grabnameX> # Each grabber dedicated queue
#                   |_> varlock # control the grabbers through files here.
#                   |_> tmp # Temporary support directory
GRAB_BASEDIR="$GRAB_BASEDIR"

# We use daemon.pl from http://github.com/meirm/ instead of nohup
# daemon.pl by default sends all output to /dev/null and runs the program in the background
# if we need to redirect or put in background as when running nohup
DAEMONIZER="$DAEMONIZER"
# We need to have the grabber command in our executable path or
# we need to provide the full path to the executable.
GRABBER="$GRABBER"

# By default each grabber share a common prefix in its name and only get a number for differentiation.
WORKERNAME="$WORKERNAME"
EOF
}

init_app(){
    ##### 
    # *** DO NOT EDIT THIS VALUES ***
    # 
    # You can replace their values reading their value from a config file
    #
    #
    # Set some basic values
    # ---------------------
    # You can override these values with exported environment variables.

    # SLAVES are the number of grabbers we will launch
    SLAVES=${SLAVES:-3}

    # GRAB_BASEDIR is the hosting branch of our grabber directory structure
    # $GRAB_BASEDIR/Grabber
    #                   |_> log # Here we keep a tali
    #                   |_> queue # Common queue for grabbers to fetch a job to execute
    #                   |_> spool/<grabnameX> # Here each grabber will grab the jobfile
    #                   |_> ctrl/<grabnameX> # Each grabber dedicated queue
    #                   |_> varlock # control the grabbers through files here.
    #                   |_> tmp # Temporary support directory
    GRAB_BASEDIR=${GRAB_BASEDIR:-$HOME}

    # We use daemon.pl from http://github.com/meirm/ instead of nohup
    # daemon.pl by default sends all output to /dev/null and runs the program in the background
    # if we need to redirect or put in background as when running nohup
    DAEMONIZER=daemon.pl

    # We need to have the grabber command in our executable path or
    # we need to provide the full path to the executable.
    GRABBER=`which grabber.sh`

    # By default each grabber share a common prefix in its name and only get a number for differentiation.
    WORKERNAME=${WORKERNAME:-grabber}
    #
    ######
    GRABBERCONF=${GRABBERCONF:-$HOME/.grabberrc}
}

load_config(){
    if [ -f $GRABBERCONF ] ; then 
        source $GRABBERCONF
    else
        create_config > $HOME/.grabberrc
    fi

    # In case that we choose to use daemon.pl and it is not available, fall back to nohup
    which $DAEMONIZER > /dev/null
    if [ $? -ne 0 ] ; then # fallback to nohup
        on_error 1 "Critical: $DAEMONIZER is not executable"
    fi

    # We make sure that we have a workable filesystem to work on.
    mkdir -p $GRAB_BASEDIR/Grabber/{log,queue,spool,ctrl,varlock,tmp}
    on_error $? "Critical: Failed to create Grabber directory in $GRAB_BASEDIR/"
}
main(){
    if [ "$1" -eq "-v" ];then
        shift;
        VERBOSE=$1
        shift;
    fi
    if [ $# -eq 0 ] || [ "$1" == "--help" ]; then
        usage 0
    fi
    init_app "$@"
    load_config "$@"

    case "$1"  in  

        start)
            for i in `seq 1 $SLAVES`; do 
                echo "$DAEMONIZER $GRABBER $WORKERNAME$i $GRAB_BASEDIR/Grabber" ;
                $DAEMONIZER $GRABBER $WORKERNAME$i $GRAB_BASEDIR/Grabber;
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

        sampleconfig)
        create_config
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
            usage 0
        ;;	
    esac
}

main @
