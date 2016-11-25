#!/bin/bash

#shellcheck disable=SC1091
. /usr/bin/utilities.sh

sed "s:SSL_DIRECTORY:${SSL_DIRECTORY}:g" /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

sed "s:SSL_DIRECTORY:${SSL_DIRECTORY}:g" "/elasticsearch/config/elasticsearch.yml.template" \
  | sed "s:DATA_DIRECTORY:${DATA_DIRECTORY}:g" \
  > "/elasticsearch/config/elasticsearch.yml"

if [[ "$1" == "--initialize" ]]; then
  htpasswd -b -c "$DATA_DIRECTORY"/auth_basic.htpasswd "${USERNAME:-aptible}" "$PASSPHRASE"

  if [ -n "$SSL_CERTIFICATE" ] && [ -n "$SSL_KEY" ]; then
    echo "$SSL_CERTIFICATE" > "$SSL_DIRECTORY"/server.crt
    echo "$SSL_KEY" > "$SSL_DIRECTORY"/server.key
    chmod og-rwx "$SSL_DIRECTORY"/server.key
  fi

  es_dirs=("${DATA_DIRECTORY}/data" "${DATA_DIRECTORY}/log" "${DATA_DIRECTORY}/work" "${DATA_DIRECTORY}/scripts")
  mkdir -p "${es_dirs[@]}"
  chown -R "${ES_USER}:${ES_GROUP}" "${es_dirs[@]}"

elif [[ "$1" == "--client" ]]; then
  echo "This image does not support the --client option. Use curl instead." && exit 1

elif [[ "$1" == "--dump" ]]; then
  [ -z "$2" ] && echo "docker run aptible/elasticsearch --dump https://... > dump.es" && exit

  if dpkg --compare-versions "$ES_VERSION" ge 5; then
    echo "Not supported for Elasticsearch ${ES_VERSION}"
    exit 1
  fi

  parse_url "$2"
  # shellcheck disable=SC2154
  elasticdump --all=true --input="${protocol:-"https://"}${user}:${password}@${host}:${port:-80}" '--output=$'

elif [[ "$1" == "--restore" ]]; then
  [ -z "$2" ] && echo "docker run -i aptible/elasticsearch --restore https://... < dump.es" && exit

  if dpkg --compare-versions "$ES_VERSION" ge 5; then
    echo "Not supported for Elasticsearch ${ES_VERSION}"
    exit 1
  fi

  parse_url "$2"
  # shellcheck disable=SC2154
  elasticdump --bulk=true '--input=$' --output="${protocol:-"https://"}${user}:${password}@${host}:${port:-80}"

elif [[ "$1" == "--readonly" ]]; then
  READONLY=1 exec /usr/bin/cluster-wrapper
else
  exec /usr/bin/cluster-wrapper
fi
