#!/bin/bash
VERSION=27
ARCH=arm64
echo ${VERSION}

#docker image push --all-tags riemerk/mr-do-upnp
docker login -u "myusername" -p "mypassword" docker.io
docker push riemerk/mr-do-upnp:latest
docker push riemerk/mr-do-upnp:${VERSION}-ARCH=${ARCH}
