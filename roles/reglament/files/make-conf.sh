#!/usr/bin/env bash

cat /etc/make.conf |egrep "^PERL_|^(# added by use\.perl)" >> /tmp/make.conf
fetch -o /etc/make.conf https://mnt.itmm.ru/pub/conf-reglament/FreeBSD/make.conf
cat /tmp/make.conf >> /etc/make.conf
rm /tmp/make.conf
fetch -o /etc/src.conf https://mnt.itmm.ru/pub/conf-reglament/FreeBSD/src.conf
