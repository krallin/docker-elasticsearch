#!/usr/bin/env bats

@test "It should install Elasticsearch 1.5.2" {
  run /elasticsearch/bin/elasticsearch -v
  [[ "$output" =~ "Version: 1.5.2"  ]]
}

@test "It should have the cloud-aws plugin installed" {
  /elasticsearch/bin/plugin --list | grep -q "cloud-aws"
}

@test "It should have JRE 7 installed" {
  run java -version
  [[ "$output" =~ "1.7" ]]
}
