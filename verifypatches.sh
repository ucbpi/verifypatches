#!/bin/sh
#
# author:   Aaron Russo <arusso@berkeley.edu>
# purpose:  check for processes holding old libraries in memory and suggest
#           a method of fixing
# date:     22-Feb-2012

# function returns value in $SERVICE
function get_service_name() {
    SERVICE=""
    case $1 in
	ntpd) 
	    SERVICE=ntpd
	    ;;
	conntrack) # conntrack logging daemon
	    SERVICE=conntrack-log
	    ;;
	cfexecd) # cfengine agent daemon
	    SERVICE=cfexecd
	    ;;
	crond) # cron daemon
	    SERVICE=crond
	    
    esac
}

LSOF_PATH=/usr/sbin/lsof
ERR_NO_LSOF=1
ERR_NOT_ROOT=2

# check if we are root
if [ "`whoami`" != "root" ]; then
    echo You must be root!
    exit $ERR_NOT_ROOT
fi

# check if lsof is installed
if [ ! -x "$LSOF_PATH" ]; then
    echo Missing lsof...
    exit $ERR_NO_LSOF
fi

# check lsof version
LSOF_VER=`lsof -v 2>&1 | grep 'revision:\ [0-9.]\{3\}' | awk '{print $2}'`
echo LSOF_VER=$LSOF_VER

# based on lsof version, get a list of all the process names that have old
# libraries loaded
if [ "$LSOF_VER" == "4.78" ]; then  # RHEL5
    OLD_LIBS="`lsof -T | grep inode= | cut -d ' ' -f 1 | sort -u`"
elif [ "$LSOF_VER" == "4.82" ]; then  # RHEL6
    OLD_LIBS=""
elif [ "$LSOF_VER" == "4.84" ]; then  # OSX 10.7 (testing mainly)
    OLD_LIBS="ntpd\nconntrack"
fi

# Now lets iterate through our list and recommend a service to restart
echo "$OLD_LIBS" | while read PROCESS; do
    get_service_name $PROCESS
    if [ "$SERVICE" == "" ]; then
	echo No service associated with process \($PROCESS\)... Restart suggested
    else
	echo service restart $SERVICE
    fi
done