#!/usr/bin/env bash

sed -E '/(^\/dev\/[a-zA-Z0-9\/]+)([[:space:]]+)(\/www[0-9]*|\/backup[0-9s]*|\/logs)([[:space:]]+)(ufs)([[:space:]]+)/s/([[:space:]]+)(rw|rw,async)([[:space:]]+)/\1\2,noatime\3/1' /etc/fstab
