#!/bin/bash

. /usr/bin/utilities.sh

if [[ "$1" == "--initialize" ]]; then
  sed -i "s:SSL_DIRECTORY:${SSL_DIRECTORY}:g" /etc/nginx/nginx.conf
  htpasswd -b -c "$DATA_DIRECTORY"/auth_basic.htpasswd "${USERNAME:-aptible}" "$PASSPHRASE"
  if [ -n "$SSL_CERTIFICATE" ] && [ -n "$SSL_KEY" ]; then
    echo "$SSL_CERTIFICATE" > "$SSL_DIRECTORY"/server.crt
    echo "$SSL_KEY" > "$SSL_DIRECTORY"/server.key
    chmod og-rwx "$SSL_DIRECTORY"/server.key
  fi
  exit

elif [[ "$1" == "--client" ]]; then
  echo "This image does not support the --client option. Use curl instead." && exit 1

elif [[ "$1" == "--dump" ]]; then
  [ -z "$2" ] && echo "docker run aptible/elasticsearch --dump https://... > dump.es" && exit
  parse_url "$2"
  elasticdump --all=true --input=${protocol:-https}"://"$user":"$password"@"$host":"${port:-80}"" --output=$

elif [[ "$1" == "--restore" ]]; then
  [ -z "$2" ] && echo "docker run -i aptible/elasticsearch --restore https://... < dump.es" && exit
  parse_url "$2"
  elasticdump --bulk=true --input=$ --output=${protocol:-https}"://"$user":"$password"@"$host":"${port:-80}""

elif [[ "$1" == "--readonly" ]]; then
  READONLY=1 /usr/sbin/nginx-wrapper

else
  /usr/sbin/nginx-wrapper

fi
