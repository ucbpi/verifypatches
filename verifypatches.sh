#!/bin/sh
#
# author:   Aaron Russo <arusso@berkeley.edu>
# purpose:  check for processes holding old libraries in memory and suggest
#           a method of fixing
# date:     22-Feb-2012
# url:      https://github.com/arusso23/verifypatches

# function returns value in $SERVICE
function get_service_name() {
    SERVICE=""
    case $1 in
	acpid) # acpi daemon
	    SERVICE=acpid
	    ;;
	auditd) # audit daemon
	    SERVICE=auditd
	    ;;
	cfexecd) # cfengine agent daemon
	    SERVICE=cfexecd
	    ;;
	conntrack) # conntrack logging daemon
	    SERVICE=conntrack-log
	    ;;
	crond) # cron daemon
	    SERVICE=crond
	    ;;
	iscsid) # iscsi daemon
	    SERVICE=iscsid
	    ;;
	ntpd) 
	    SERVICE=ntpd
	    ;;
	rsyslogd)
	    SERVICE=rsyslogd
	    ;;
	snmpd)
	    SERVICE=snmpd
	    ;;
	'ssh'|'sshd')
	    SERVICE=openssh-daemon
	    ;;
	xinetd)
	    SERVICE=xinetd
	    ;;
    esac
}

LSOF_PATH=/usr/sbin/lsof
ERR_NO_LSOF=1
ERR_NOT_ROOT=2
ERR_BAD_LSOF_VER=3

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
OLD_LIBS=""
case "$LSOF_VER" in
    "4.78") # RHEL5
	OLD_LIBS="`lsof -T | grep inode= | cut -d ' ' -f 1 | sort -u`"
	;;
    *) # default
	echo "This version of lsof has not been accounted for."
	exit $ERR_BAD_LSOF_VER
esac


# check that we have processes to make recommendations on
if [ "$OLD_LIBS" == "" ]; then
    echo "Everything looks in order here...";
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