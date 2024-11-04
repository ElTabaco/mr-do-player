#!/bin/bash
set -euo pipefail
SNAPCAST_VERSION=master
#SNAPCAST_VERSION=0.27.0
ARCH=arm64
echo ${SNAPCAST_VERSION}

docker buildx build -t riemerk/mr-do-snapclient --build-arg ARCH=${ARCH} .
# docker buildx build -t riemerk/mr-do-snapclient --platform linux/amd64,linux/arm64 --build-arg ARCH=${ARCH} .
docker tag riemerk/mr-do-snapclient:latest riemer/mr-do-snapclient:${SNAPCAST_VERSION}-${ARCH}
