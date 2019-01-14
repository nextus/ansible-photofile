#!/usr/bin/env bash

for i in `ps ax -o pid,comm,etime | grep convert | egrep '([0-9]{2}:)?([0-5][1-9]:[0-5][0-9])' | awk '{print $1}'`; do
    echo "Killing pid: $i"
    if [[ $i -eq 1 ]]; then
        echo "OH FUCK!"
        exit 1
    fi
    kill -9 $i
    sleep 5
done
