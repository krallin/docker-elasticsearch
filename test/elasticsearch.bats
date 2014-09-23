#!/usr/bin/env bats

@test "It should install Elasticsearch 1.3.2" {
  run /elasticsearch/bin/elasticsearch -v
  [[ "$output" =~ "Version: 1.3.2"  ]]
}
