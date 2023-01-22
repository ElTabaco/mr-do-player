#!/bin/bash
SNAPCAST_VERSION=26
ARCH=arm64
echo ${SNAPCAST_VERSION}

#docker image push --all-tags riemerk/mr-do-snapserver
docker login -u "myusername" -p "mypassword" docker.io
docker push riemerk/mr-do-snapserver:latest
docker push riemerk/mr-do-snapserver:${SNAPCAST_VERSION}-ARCH=${ARCH}
