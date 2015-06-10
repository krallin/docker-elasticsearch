#!/bin/bash

. /usr/bin/utilities.sh

if [[ "$1" == "--initialize" ]]; then
  htpasswd -b -c "$DATA_DIRECTORY"/auth_basic.htpasswd "${USERNAME:-aptible}" "$PASSPHRASE"
  exit

elif [[ "$1" == "--client" ]]; then
  echo "This image does not support the --client option. Use curl instead." && exit 1

elif [[ "$1" == "--dump" ]]; then
  [ -z "$2" ] && echo "docker run aptible/elasticsearch --dump http://... > dump.es" && exit
  parse_url "$2"
  elasticdump --all=true --input="http://"$user":"$password"@"$host":"${port:-80}"" --output=$

elif [[ "$1" == "--restore" ]]; then
  [ -z "$2" ] && echo "docker run -i aptible/elasticsearch --restore http://... < dump.es" && exit
  parse_url "$2"
  elasticdump --bulk=true --input=$ --output="http://"$user":"$password"@"$host":"${port:-80}""

elif [[ "$1" == "--readonly" ]]; then
  READONLY=1 /usr/sbin/nginx-wrapper

else
  /usr/sbin/nginx-wrapper

fi
