#!/usr/bin/env bash

# 2012

VERSION="0.4"

RUN_USER="photofile-backup"
MINCAP_PER="7"
RSYNC_VERBOSE="-q"
RSYNC_DELETE=""
RSYNC_COMMAND="env RSYNC_PASSWORD=hidden rsync -Waup --safe-links"

BACKUP_SERVER=`hostname -s`

if [[ $UID -eq 0 ]]; then
    RSYNC_ENV="sudo -u $RUN_USER"
elif [[ $UID -eq $(id -u $RUN_USER) ]]; then
    RSYNC_ENV=""
else
    echo "This script must be run only by root or $RUN_USER"
    exit 1
fi

while getopts ":dVhv" opt; do
    case $opt in
        d)  RSYNC_DELETE="--delete-before"
        ;;
        V)  RSYNC_VERBOSE="-v"
        ;;
        h)  echo "`basename $0` is the command line program for doing smotri.com video files backups"
            echo -e "\t-d: run rsync with --delete-before option and ignore free capacity statement"
            echo -e "\t-V: verbose mode"
            echo -e "\t-h: print this help"
            exit 0
        ;;
        v)  echo "`basename $0`: $VERSION"
            exit 1
        ;;
        *)  echo "Unknown key. Run '$0 -h' for help"
            exit 1
    esac
done

saveit () {
    [[ ! -d $2 ]] && ( echo "The directory $2 not found!"; exit 1)
    capacity=$(BLOCKSIZE=1G df $2 | awk '{print $4}' | tail -n +2)
    if [[ $capacity -ge $MINCAP_PER ]] || [[ -n $RSYNC_DELETE ]]; then
        $RSYNC_ENV $RSYNC_COMMAND $RSYNC_VERBOSE $RSYNC_DELETE $1 $2
    else
        echo "Out of space for $2: $capacity GB"
        exit 1
    fi
}

mysql --skip-column-names -e "SELECT server_num,name FROM file_server WHERE backup_server='$BACKUP_SERVER' AND offline='0'" -h mysql2.photofile.ru -u photofile_slave -p'N3)aSn!u' app_system | while read i
do
    SERVER_NUM=`echo $i | cut -d' ' -f1`
    MASTER=`echo $i | cut -d' ' -f2`
    BACKUP_PART=""
    if [[ -d "/backup" ]]; then
        BACKUP_PART="/backup"
    elif [[ -d "/www" ]]; then
        BACKUP_PART="/www"
    else
        echo "Backup partition not found!"
        exit 1
    fi
    saveit photofile.ru@$MASTER::photo$SERVER_NUM/ $BACKUP_PART/ff$SERVER_NUM.backups.photofile.ru/data/photo/
done

