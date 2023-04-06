#!/bin/bash
SNAPCAST_VERSION=27
ARCH=arm64
echo ${SNAPCAST_VERSION}

#docker image push --all-tags riemerk/mr-do-snapclient
docker login -u "myusername" -p "mypassword" docker.io
docker push riemerk/mr-do-snapclient:latest
docker push riemerk/mr-do-snapclient:${SNAPCAST_VERSION}-ARCH=${ARCH}
