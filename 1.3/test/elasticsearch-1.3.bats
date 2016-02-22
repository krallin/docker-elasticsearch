#!/usr/bin/env bats

@test "It should install Elasticsearch 1.3.2" {
  run /elasticsearch/bin/elasticsearch -v
  [[ "$output" =~ "Version: 1.3.2"  ]]
}

@test "It should have the cloud-aws plugin installed" {
  /elasticsearch/bin/plugin --list | grep -q "cloud-aws"
}
