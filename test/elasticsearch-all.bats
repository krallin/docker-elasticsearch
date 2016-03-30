#!/usr/bin/env bats

initialize_elasticsearch() {
  USERNAME=aptible PASSPHRASE=password run-database.sh --initialize
}

wait_for_elasticsearch() {
  # We pass the ES_PID via a global variable because we can't rely on
  # $(wait_for_elasticsearch) as it would result in orpahning the ES process
  # (which makes us unable to `wait` it).
  run-database.sh "$@" > $BATS_TEST_DIRNAME/nginx.log 2>&1 &
  ES_PID="$!"
  while ! grep -q "started" $BATS_TEST_DIRNAME/nginx.log 2>/dev/null; do
    sleep 0.1
  done
}

setup() {
  export OLD_DATA_DIRECTORY="$DATA_DIRECTORY"
  export OLD_SSL_DIRECTORY="$SSL_DIRECTORY"
  export DATA_DIRECTORY=/tmp/datadir
  export SSL_DIRECTORY=/tmp/ssldir
  rm -rf "$DATA_DIRECTORY"
  rm -rf "$SSL_DIRECTORY"
  mkdir -p "$DATA_DIRECTORY"
  mkdir -p "$SSL_DIRECTORY"
}

shutdown_nginx() {
  NGINX_PID=$(pgrep nginx) || return 0
  run pkill nginx
  while [ -n "$NGINX_PID" ] && [ -e "/proc/${NGINX_PID}" ]; do sleep 0.1; done
}

shutdown_elasticsearch() {
  JAVA_PID=$(pgrep java) || return 0
  run pkill java
  while [ -n "$JAVA_PID" ] && [ -e "/proc/${JAVA_PID}" ]; do sleep 0.1; done
}

teardown() {
  shutdown_elasticsearch
  shutdown_nginx
  export DATA_DIRECTORY="$OLD_DATA_DIRECTORY"
  export SSL_DIRECTORY="$OLD_SSL_DIRECTORY"
  unset OLD_DATA_DIRECTORY
  unset OLD_SSL_DIRECTORY
}

@test "It should provide an HTTP wrapper" {
  initialize_elasticsearch
  rm "$DATA_DIRECTORY/auth_basic.htpasswd"  # Disable auth for this test
  wait_for_elasticsearch
  run wget -qO- http://localhost > "${BATS_TEST_DIRNAME}/test-output"
  run wget -qO- http://localhost
  [[ "$output" =~ "tagline"  ]]
}

@test "It should expose Elasticsearch over HTTP with Basic Auth" {
  initialize_elasticsearch
  wait_for_elasticsearch
  run wget -qO- http://aptible:password@localhost
  [[ "$output" =~ "tagline"  ]]
}

@test "It should expose Elasticsearch over HTTPS with Basic Auth" {
  initialize_elasticsearch
  wait_for_elasticsearch
  run wget -qO- --no-check-certificate https://aptible:password@localhost
  [[ "$output" =~ "tagline"  ]]
}

@test "It should allow the SSL certificate and key to be configured via ENV" {
  mkdir /tmp/cert
  openssl req -x509 -batch -nodes -newkey rsa:2048 -keyout /tmp/cert/server.key \
    -out /tmp/cert/server.crt -subj /CN=elasticsearch-bats-test.com
  export SSL_CERTIFICATE="$(cat /tmp/cert/server.crt)"
  export SSL_KEY="$(cat /tmp/cert/server.key)"
  rm -rf /tmp/cert
  initialize_elasticsearch
  wait_for_elasticsearch
  curl -kv https://localhost 2>&1 | grep "CN=elasticsearch-bats-test.com"
}

@test "It should reject unauthenticated requests with Basic Auth enabled over HTTP" {
  initialize_elasticsearch
  wait_for_elasticsearch
  run wget -qO- http://localhost
  [ "$status" -ne "0" ]
  ! [[ "$output" =~ "tagline"  ]]
}

@test "It should reject unauthenticated requests with Basic Auth enabled over HTTPS" {
  initialize_elasticsearch
  wait_for_elasticsearch
  run wget -qO- --no-check-certificate https://localhost
  [ "$status" -ne "0" ]
  ! [[ "$output" =~ "tagline"  ]]
}

@test "It should disable multicast cluster discovery in config" {
  initialize_elasticsearch
  run grep "discovery.zen.ping.multicast.enabled" /elasticsearch/config/elasticsearch.yml
  [[ "$output" =~ "false" ]]
}

@test "It should not send multicast discovery ping requests" {
  initialize_elasticsearch
  run timeout 5 elasticsearch-wrapper -Des.logger.discovery=TRACE
  ! [[ "$output" =~ "sending ping request" ]]
  ! [[ "$output" =~ "multicast" ]]
}

@test "It should support compatible --dump and --restore commands" {
  url="http://aptible:password@localhost"
  dump="${BATS_TEST_DIRNAME}/dump-file"

  initialize_elasticsearch
  wait_for_elasticsearch

  curl -s -XPUT "http://localhost:9200/tests/test/1" -d'{
    "testId": 1,
    "testValue": "TEST_VALUE"
  }'
  curl -s "http://localhost:9200/tests/test/1" | grep "TEST_VALUE"

  # We have to repeat the dump a few times, because it originally
  # comes out empty (most likely a question of timing).
  until [[ -s "$dump" ]]; do
    run-database.sh --dump "$url" > "$dump"
  done

  teardown
  setup

  initialize_elasticsearch
  wait_for_elasticsearch

  run-database.sh --restore "$url" < "$dump"
  curl -s "http://localhost:9200/tests/test/1" | grep "TEST_VALUE"
}

@test "It should exit when ES exits (or is killed) and report the exit code" {
  initialize_elasticsearch
  wait_for_elasticsearch

  # Check that our PID is valid
  run ps af --pid "$ES_PID"
  [[ "$output" =~ "$ES_PID" ]]

  # Check that Java and Nginx are children
  run ps --ppid "$ES_PID"
  [[ "$output" =~ "nginx" ]]
  [[ "$output" =~ "java" ]]

  # Kill ES (emulate a OOM process kill)
  kill -KILL "$ES_PID"

  # Check that we exited with ES's status code
  wait "$ES_PID" || exit_code="$?"
  [[ "$exit_code" -eq "$((128+9))" ]]
}

@test "It should support --readonly mode" {
  initialize_elasticsearch
  wait_for_elasticsearch "--readonly"

  curl "http://aptible:password@localhost"

  run curl --fail -XPOST "http://aptible:password@localhost"
  [[ "$output" =~ "Forbidden" ]]
  [[ "$status" -eq 22 ]]  # CURLE_HTTP_RETURNED_ERROR - https://curl.haxx.se/libcurl/c/libcurl-errors.html
}

@test "It should support ES_HEAP_SIZE=256m" {
  initialize_elasticsearch
  ES_HEAP_SIZE=256m wait_for_elasticsearch
  run ps auxwww
  [[ "$output" =~ "-Xms256m -Xmx256m" ]]
}

@test "It should support ES_HEAP_SIZE=512m" {
  initialize_elasticsearch
  ES_HEAP_SIZE=512m wait_for_elasticsearch
  run ps auxwww
  [[ "$output" =~ "-Xms512m -Xmx512m" ]]
}
