#!/bin/sh
#https://wiki.archlinux.org/title/Systemd/Timers#MAILTO

/usr/bin/sendmail -t <<ERRMAIL
To: $1
From: systemd <root@$HOSTNAME>
Subject: [Failed] $2
Content-Transfer-Encoding: 8bit
Content-Type: text/plain; charset=UTF-8

$(systemctl status --full "$2" -n 200)
ERRMAIL