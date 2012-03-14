#!/bin/sh
#
# author:   Aaron Russo <arusso@berkeley.edu>
# purpose:  check for processes holding old libraries in memory and suggest
#           a method of fixing
# date:     22-Feb-2012
# url:      https://github.com/arusso23/verifypatches

# Load our configuration file
# optionally, we could put everything up here, but it's cleaner to inlude the
# external config
CONFIG_FILE=./verifypatches.conf
if [ -r $CONFIG_FILE ]; then
    echo "loading config '$CONFIG_FILE'..."
    . "$CONFIG_FILE"
fi

# Clean up our config options
EMAIL_NOTIFICATION=`echo $EMAIL_NOTIFICATION | tr [:lower:] [:upper:]`

# function returns value in $SERVICE
function get_service_name() {
    SERVICE=""
    case $1 in
	acpid) # acpi daemon
	    SERVICE=acpid ;;
	atd) # at daemon
	    SERVICE=atd ;;
	auditd) # audit daemon
	    SERVICE=auditd ;;
	cfexecd) # cfengine agent daemon
	    SERVICE=cfexecd ;;
	conntrack) # conntrack logging daemon
	    SERVICE=conntrack-log ;;
	crond) # cron daemon
	    SERVICE=crond ;;
	exim)
	    SERVICE=exim ;;
	httpd)
	    SERVICE=httpd ;;
	iscsid) # iscsi daemon
	    SERVICE=iscsid ;;
	mysqld) # mysql daemon
	    SERVICE=mysqld ;;
	ntpd) 
	    SERVICE=ntpd ;;
	puppetd)
	    SERVICE=puppetd ;;
	rsyslogd)
	    SERVICE=rsyslogd ;;
	snmpd)
	    SERVICE=snmpd ;;
	'ssh'|'sshd')
	    SERVICE=openssh-daemon ;;
	xinetd)
	    SERVICE=xinetd ;;
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

# based on lsof version, get a list of all the process names that have old
# libraries loaded
case "$LSOF_VER" in
    "4.78") # RHEL5
	OLD_LIBS=(`lsof -T | grep inode= | cut -d ' ' -f 1 | sort -u`)
	;;
    "4.82") # RHEL6
	OLD_LIBS=(`lsof -T | grep DEL | grep -Ev ' /tmp/|' /dev/zero' | cut -d ' ' -f 1 | sort -u`)
	;;
    *) # default
	# bad version of LSOF
	if [ "$EMAIL_NOTIFICATION" == "YES" ]; then       
	    echo -e "$OUTPUT" | /bin/mail -s "WARNING: This version of lsof (${LSOF_VER}) has not been account for" $EMAIL_TO	
	else
	    echo "This version of lsof (${LSOF_VER}) has not been accounted for."
	fi
	exit $ERR_BAD_LSOF_VER
esac

# Now lets iterate through our list and recommend a service to restart
declare -a RESTART_SERVER
declare -a RESTART_SERVICE
for PROCESS in ${OLD_LIBS[@]}
  do
    get_service_name $PROCESS
    if [ "$SERVICE" == "" ]; then
	RESTART_SERVER=( "${RESTART_SERVER[@]}" "$PROCESS" )
    else
	RESTART_SERVICE=( "${RESTART_SERVICE[@]}" "$SERVICE" )
    fi
done

# Generate our output
SERVER_RESTART_SUGGESTED=0
SERVICE_RESTART_SUGGESTED=0
HOSTNAME="`hostname | tr [:upper:] [:lower:]`"
OUTPUT="Output of verifyupdates on ${HOSTNAME}:"
if [ ${#RESTART_SERVER[0]} -gt 0 ]; then
    SERVER_RESTART_SUGGESTED=1
    OUTPUT="${OUTPUT}""\n\n*** The following processes have no know affiliated service, and require a restart (or other undefined intervention) to reload:"
    for PROCESS in ${RESTART_SERVER[@]}
    do
	OUTPUT="${OUTPUT}""\n\t${PROCESS}"
    done
    OUTPUT="${OUTPUT}""\n\n"
fi
    
if [ ${#RESTART_SERVICE[0]} -gt 0 ]; then
    SERVICE_RESTART_SUGGESTED=1
    OUTPUT="${OUTPUT}""\n*** The following services can be restarted:"
    for SERVICE in ${RESTART_SERVICE[@]}
    do
	OUTPUT="${OUTPUT}""\n\tservice $SERVICE restart"
    done
    OUTPUT="${OUTPUT}""\n\n"
fi    

SUBJ_PREFIX="WARNING:";
# if we have nothing to do, lets say so
if [ ${#RESTART_SERVICE[0]} -eq 0 ]  && [ ${#RESTART_SERVER[0]} -eq 0 ]; then
    OUTPUT="${OUTPUT}""\n\nNothing to do..."
    SUBJ_PREFIX="OK:";
fi

# Send notification, either to email or to screen
if [ "$EMAIL_NOTIFICATION" == "YES" ]; then
    # Send an email to the user at $EMAIL_TO	
    echo -e "$OUTPUT" | /bin/mail -s "${SUBJ_PREFIX} patch verification on ${HOSTNAME}" $EMAIL_TO
else  # assume NO
    # Print to screen
    echo "$OUTPUT"
fi
