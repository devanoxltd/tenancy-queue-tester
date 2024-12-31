#!/bin/sh

TENANCY_VERSION=${TENANCY_VERSION:-"dev-master"}

set -e

(cd cli && ./build.sh)

rm -rf src
mkdir -p src
chmod -R 777 src

docker run --rm -e TENANCY_VERSION="${TENANCY_VERSION}" -v .:/var/www/html tenancy-queue-test-cli bash setup/_tenancy_setup.sh
