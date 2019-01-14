#!/bin/bash

# nablas@gmail.com
# azavatsky@rbc.ru
#
# Version history
#
# 0.1:  First release
# 0.2:  The path /proc/sys/net/ipv4/netfilter/ip_conntrack_count may be 
#   differtent in each distribution, so now the script search for it.
# 0.3:  Revamp script for works like as active check through the snmpd exec function
#        

# Thresholds (in pers)
CRIT=90
WARN=70

# Check stuff
if [ `uname -s` != "Linux" ]; then
    echo "OK: Conntrack table exists only in linux kernel"
    exit -1
fi

if [ `dmesg | grep -q "ip_conntrack: table full"` ]; then
    echo "ERROR: message buffer's containing such errors: 'ip_conntrack: table full'"
    exit 2
fi


COUNT_FILE=`find /proc/sys -name *conntrack_count | head -n 1`
MAX_FILE=`find /proc/sys -name *conntrack_max | head -n 1`
if [ -z $MAX_FILE ] || [ -z $COUNT_FILE ]; then
    echo "UNKNOWN: Couldn't find required files in procfs"
    exit -1
fi


COUNT=`cat $COUNT_FILE | head -n 1`
MAX=`cat $MAX_FILE | head -n 1 `

RESULT=`expr $COUNT \/ $MAX \* 100`

if [ $RESULT -ge $CRIT ]; then
        echo "CRITITCAL: Conntrack table is filled ${RESULT}% |con=$COUNT"
        exit 2
fi

if [ $RESULT -ge $WARN ]; then
        echo "WARNING: Conntrack table is filled ${RESULT}% |con=$COUNT"
        exit 1
fi

if [ $RESULT -ge 0 ]; then
        echo "OK: Conntrack table is filled ${RESULT}% |con=$COUNT"
        exit 0
fi

echo "UNKNOWN: Unexpected error"
exit -1
