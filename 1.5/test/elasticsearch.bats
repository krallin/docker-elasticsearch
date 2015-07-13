#!/usr/bin/env bats

@test "It should install Elasticsearch 1.5.2" {
  run /elasticsearch/bin/elasticsearch -v
  [[ "$output" =~ "Version: 1.5.2"  ]]
}

wait_for_elasticsearch() {
  /usr/sbin/nginx-wrapper > $BATS_TEST_DIRNAME/nginx.log &
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

teardown() {
  export DATA_DIRECTORY="$OLD_DATA_DIRECTORY"
  export SSL_DIRECTORY="$OLD_SSL_DIRECTORY"
  unset OLD_DATA_DIRECTORY
  unset OLD_SSL_DIRECTORY
  PID=$(pgrep java) || return 0
  run pkill java
  run pkill nginx
  while [ -n "$PID" ] && [ -e /proc/$PID ]; do sleep 0.1; done
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
  run grep "discovery.zen.ping.multicast.enabled" elasticsearch/config/elasticsearch.yml
  [[ "$output" =~ "false" ]]
}

@test "It should not send multicast discover ping requests" {
  run timeout 5 /elasticsearch/bin/elasticsearch -Des.logger.discovery=TRACE
  ! [[ "$output" =~ "sending ping request" ]]
}

@test "It should have the cloud-aws plugin installed" {
  /elasticsearch/bin/plugin --list | grep -q "cloud-aws"
}
