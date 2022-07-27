#!/bin/bash

echo "Running before-install.sh"

/usr/bin/mkdir -p /var/lib/openmeteo-api/
/usr/sbin/useradd --user-group openmeteo-api
