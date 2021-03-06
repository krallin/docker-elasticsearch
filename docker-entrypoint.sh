#!/bin/bash
set -e

NAME='elasticsearch'

if [ "$1" = "$NAME" ]; then
  # Those are just defaults, they can be overriden with -Des.config=...
  CONF_DIR=/etc/$NAME
  CONF_FILE=$CONF_DIR/elasticsearch.yml

  WORK_DIR=/tmp/$NAME

  OPTS="--default.config=$CONF_FILE --default.path.home=$ES_HOME --default.path.logs=$ES_LOGS --default.path.data=$ES_DATA --default.path.work=$WORK_DIR --default.path.conf=$CONF_DIR"
  mkdir -p "$ES_LOGS" "$ES_DATA" "$WORK_DIR" && chown -R "$ES_USER":"$ES_GROUP" "$ES_LOGS" "$ES_DATA" "$WORK_DIR"

  shift
  set -- gosu "$ES_USER:$ES_GROUP" "$NAME" $OPTS "$@"
fi

exec "$@"
