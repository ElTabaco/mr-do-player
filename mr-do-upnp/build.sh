#!/bin/bash
set -euo pipefail
VERSION=master
#VERSION=0.1.0
ARCH=arm64
echo ${VERSION}

docker buildx -t riemerk/mr-do-upnp --platform linux/amd64,linux/arm64 --build-arg ARCH=${ARCH} .
docker tag riemerk/mr-do-upnp:latest riemer/mr-do-upnp:${VERSION}-${ARCH}
