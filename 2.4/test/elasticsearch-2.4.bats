#!/usr/bin/env bats

@test "It should install Elasticsearch 2.4.5" {
  run elasticsearch-wrapper --version
  [[ "$output" =~ "Version: 2.4.5"  ]]
}

@test "It should have the cloud-aws plugin installed" {
  /elasticsearch/bin/plugin list | grep -q "cloud-aws"
}
