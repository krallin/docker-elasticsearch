#!/bin/bash
set -o errexit
set -o nounset

IMG="$REGISTRY/$REPOSITORY:$TAG"

./test-restart.sh "$IMG"
./test-exit-code.sh "$IMG"
./test-xpack.sh "$IMG"
./test-plugin.sh "$IMG"

echo "#############"
echo "# Tests OK! #"
echo "#############"
