#!/bin/bash

if [[ "$1" == "--initialize" ]]; then
  htpasswd -b -c "$DATA_DIRECTORY"/auth_basic.htpasswd "${USERNAME:-aptible}" "$PASSPHRASE"
  exit
fi

/usr/sbin/nginx-wrapper
