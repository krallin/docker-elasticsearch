#!/bin/bash
set -o errexit
set -o nounset

IMG="$1"

ES_CONTAINER="es-db"
DATA_CONTAINER="es-data"

function cleanup {
  echo "Cleaning up"
  docker rm -f "$ES_CONTAINER" "$DATA_CONTAINER" || true
}
trap cleanup EXIT
cleanup


docker create --name "$DATA_CONTAINER" "$IMG"
docker run -it --rm --volumes-from "$DATA_CONTAINER" "$IMG" --initialize
docker run -d --name "$ES_CONTAINER" --volumes-from "$DATA_CONTAINER"  "$IMG"

echo "Waiting for container to start"
until docker logs "$ES_CONTAINER" | grep --silent "started"; do sleep 0.5; done

echo "Terminating $ES_CONTAINER"
docker stop "$ES_CONTAINER"

until [[ "$(docker inspect -f "{{ .State.Pid }}" "$ES_CONTAINER")" -eq 0 ]]; do sleep 0.5; done

echo "Checking container exited cleanly"
docker logs "$ES_CONTAINER" | grep "stopped"
docker logs "$ES_CONTAINER" | grep "closed"

echo "Checking Elasticsearch exit code was propagated"
exit_code="$(docker inspect -f "{{ .State.ExitCode }}" "$ES_CONTAINER")"
[[ "$exit_code" -eq "$((128+15))" ]]

echo "Test OK!"
