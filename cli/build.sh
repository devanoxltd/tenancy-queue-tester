#!/bin/bash

tag="tenancy-queue-test-cli"
php="8.4"

docker build --build-arg PHP_VERSION=$php -t $tag .
