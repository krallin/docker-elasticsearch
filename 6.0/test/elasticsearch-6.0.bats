#!/usr/bin/env bats

@test "It should install Elasticsearch 6.0.1" {
  run elasticsearch-wrapper --version
  [[ "$output" =~ "Version: 6.0.1"  ]]
}

@test "It should have the repository-s3 plugin installed" {
  /elasticsearch/bin/elasticsearch-plugin list | grep -q "repository-s3"
}

@test "It should fail when --dump is run" {
  # See: https://github.com/taskrabbit/elasticsearch-dump/issues/259
  url="http://aptible:password@localhost"
  run run-database.sh --dump "$url"
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "Not supported" ]]
}

@test "It should fail when --restore is run" {
# See: https://github.com/taskrabbit/elasticsearch-dump/issues/259
  url="http://aptible:password@localhost"
  run run-database.sh --restore "$url"
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "Not supported" ]]
}
