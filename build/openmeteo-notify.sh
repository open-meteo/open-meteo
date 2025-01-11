#!/bin/sh
#https://wiki.archlinux.org/title/Systemd/Timers#MAILTO

/usr/sbin/sendmail -t <<ERRMAIL
To: $1
Subject: [Failed] $2
Content-Transfer-Encoding: 8bit
Content-Type: text/plain; charset=UTF-8

$(systemctl status --full "$2" -n 200)
ERRMAIL