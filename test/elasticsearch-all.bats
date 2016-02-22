#!/usr/bin/env bats

wait_for_elasticsearch() {
  run-database.sh > $BATS_TEST_DIRNAME/nginx.log &
  while  ! grep "started" $BATS_TEST_DIRNAME/nginx.log ; do sleep 0.1; done
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
  wait_for_elasticsearch
  run wget -qO- http://localhost > /test-output
  run wget -qO- http://localhost
  [[ "$output" =~ "tagline"  ]]
}

@test "It should expose Elasticsearch over HTTP with Basic Auth" {
  USERNAME=aptible PASSPHRASE=password run-database.sh --initialize
  wait_for_elasticsearch
  run wget -qO- http://aptible:password@localhost
  [[ "$output" =~ "tagline"  ]]
}

@test "It should expose Elasticsearch over HTTPS with Basic Auth" {
  USERNAME=aptible PASSPHRASE=password run-database.sh --initialize
  wait_for_elasticsearch
  run wget -qO- --no-check-certificate https://aptible:password@localhost
  [[ "$output" =~ "tagline"  ]]
}

@test "It should allow the SSL certificate and key to be configured via ENV" {
  mkdir /tmp/cert
  openssl req -x509 -batch -nodes -newkey rsa:2048 -keyout /tmp/cert/server.key \
    -out /tmp/cert/server.crt -subj /CN=elasticsearch-bats-test.com
  export SSL_CERTIFICATE=$(cat /tmp/cert/server.crt)
  export SSL_KEY=$(cat /tmp/cert/server.key)
  rm -rf /tmp/cert
  USERNAME=aptible PASSPHRASE=password run-database.sh --initialize
  wait_for_elasticsearch
  openssl s_client -connect localhost:443 | grep -q "subject=/CN=elasticsearch-bats-test.com"
}

@test "It should reject unauthenticated requests with Basic Auth enabled over HTTP" {
  USERNAME=aptible PASSPHRASE=password run-database.sh --initialize
  wait_for_elasticsearch
  run wget -qO- http://localhost
  [ "$status" -ne "0" ]
  ! [[ "$output" =~ "tagline"  ]]
}

@test "It should reject unauthenticated requests with Basic Auth enabled over HTTPS" {
  USERNAME=aptible PASSPHRASE=password run-database.sh --initialize
  wait_for_elasticsearch
  run wget -qO- --no-check-certificate https://localhost
  [ "$status" -ne "0" ]
  ! [[ "$output" =~ "tagline"  ]]
}

@test "It should disable multicast cluster discovery in config" {
  USERNAME=aptible PASSPHRASE=password run-database.sh --initialize
  run grep "discovery.zen.ping.multicast.enabled" /elasticsearch/config/elasticsearch.yml
  [[ "$output" =~ "false" ]]
}

@test "It should not send multicast discover ping requests" {
  USERNAME=aptible PASSPHRASE=password run-database.sh --initialize
  run timeout 5 /elasticsearch/bin/elasticsearch -Des.logger.discovery=TRACE
  ! [[ "$output" =~ "sending ping request" ]]
  ! [[ "$output" =~ "multicast" ]]
}

@test "It should support compatible --dump and --restore commands" {
  url="http://aptible:password@localhost"
  dump="${BATS_TEST_DIRNAME}/dump-file"

  USERNAME=aptible PASSPHRASE=password run-database.sh --initialize
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

  USERNAME=aptible PASSPHRASE=password run-database.sh --initialize
  wait_for_elasticsearch

  run-database.sh --restore "$url" < "$dump"
  curl -s "http://localhost:9200/tests/test/1" | grep "TEST_VALUE"
}
