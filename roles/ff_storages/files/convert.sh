#!/bin/sh

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
export TMPDIR=/www/tmp

ulimit -d 40960

if [ `ps ax | grep '/usr/local/bin/convert' | egrep -v '(grep|convert\.sh)' | wc -l` -le 3 ]; then
  /usr/local/bin/convert "$@"
fi

