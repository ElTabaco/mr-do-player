#!/bin/bash
set -euo pipefail
SNAPCAST_VERSION=26
#SNAPCAST_VERSION=0.26.0
BOOST_VERSION=1.78.0
BOOST_VERSION_UNDERSCORED=1_78_0
ARCH=arm64
echo ${SNAPCAST_VERSION}

docker build -t riemerk/mr-do-snapserver --build-arg ARCH=${ARCH} .
docker tag riemerk/mr-do-snapserver:latest riemer/mr-do-snapserver:${SNAPCAST_VERSION}-${ARCH}
