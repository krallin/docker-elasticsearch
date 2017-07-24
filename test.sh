#!/bin/bash
set -o errexit
set -o nounset

IMG="$REGISTRY/$REPOSITORY:$TAG"

./test-restart.sh "$IMG"
./test-exit-code.sh "$IMG"
./test-xpack.sh "$IMG"
./test-plugin.sh "$IMG"

if [[ -n ${AWS_ACCESS_KEY_ID:-} ]]; then
  ./test-backup.sh "$IMG"
else
  echo "Skipping S3 backup test, no AWS_ACCESS_KEY_ID set."
fi

echo "#############"
echo "# Tests OK! #"
echo "#############"
