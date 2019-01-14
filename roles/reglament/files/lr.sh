#!/bin/sh
#
# $Id: lr.sh,v 1.4 2001/02/08 21:22:33 root Exp $
# $NewMachine: 1.7 $
#

PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

log_dirs='/logs'
pid_dirs='/logs /var/run /var/run/httpd'
httpds='"*http*" "apache*" "nginx"'

for log_dir in $log_dirs; do
    find $log_dir -type f -name '*_log.*.gz' -mtime +7 -delete > /dev/null
done

if uname | grep -qi linux; then
    # Linux
    yesterday () {
	date -d "12 hours ago" +%Y%m%d
    }
    before_yesterday () {
	date -d "36 hours ago" +%Y%m%d
    }
elif uname | grep -qi freebsd; then
    # FreeBSD
    if uname -r | grep -q ^4; then
	# 4* FreeBSD
	yesterday () {
	    date -j -v -12H +%Y%m%d
	}
	before_yesterday () {
	    date -j -v -36H +%Y%m%d
	}
    else
	# other, use old 'date'
	yesterday () {
	    sec=`date +%s`
	    date -r `expr $sec - 43200` +%Y%m%d
	}
	before_yesterday () {
	    sec=`date +%s`
	    date -r `expr $sec - 129600` +%Y%m%d
	}
    fi
else
    # Other
    echo "Don't know this operating system: `uname`" 2>&1
    exit 1
fi

mysql_rotate_log () {
#echo Rotating: "$logfile to $logfile.$date"
mv $logfile $logfile.$date
if test -x /usr/local/bin/mysqladmin && /usr/local/bin/mysqladmin ping >/dev/null 2>&1 
        then
           /usr/local/bin/mysqladmin flush-logs
        fi
gzip -f $logfile.$date
}

walk_with () {
    cmd=$1
    for log_dir in $log_dirs; do
	for d in $log_dir $log_dir/*; do
	    if [ -d $d ]; then
		for log in $d/*_log; do
		    [ -f $log ] && eval "$cmd"
		done
	    fi
	done
    done
}

date=`yesterday`

walk_with '[ -f $log -a -s $log ] && mv -f $log $log.$date'

for pid_dir in $pid_dirs; do
    for httpd in $httpds; do
	httpd=`echo $httpd | sed 's/^"\(.*\)"$/\1/'`
	for pid_file in $pid_dir/$httpd.pid; do
	    if [ -f $pid_file ]; then
		if ! echo $pid_file | grep -q thttp; then
		    # rotate log apache
		    kill -USR1 `cat $pid_file`
		else
		    # rotate log thttpd
		    thttpd_script=/usr/local/etc/rc.d/thttpd.sh
		    if [ -x $thttpd_script ]; then
			sh -c "$thttpd_script restart | grep -v thttpd"
		    else
			echo "please move start of thttpd from /etc/rc.local to /usr/local/etc/rc.d/thttpd.sh" 2>&1
		    fi
		fi
	    fi
	done
    done
done
sleep 15

# gzip files yesterday

date=`yesterday`

walk_with '[ -f $log.$date ] && gzip $log.$date'


##################################
##	MySQL log rotation	##
##################################
if [ `uname` = "Linux" ]; then 
#	echo "No need rotate mysql logs on Linux, exit.."
	exit
fi
date=`yesterday`
mysql_log_dir=$log_dirs/mysql
if [ -d "$mysql_log_dir" ]; then
#        echo "MySQL enable"
for logfile in $mysql_log_dir/mysql $mysql_log_dir/mysql.err $mysql_log_dir/mysql-slow.log; do
        [ -f $logfile ] && mysql_rotate_log;
        done
#       echo "Purge old log files"
        find -L $mysql_log_dir -type f -name '*.gz' -mtime +7d -delete
else
#        echo "MySQL disable"
fi
