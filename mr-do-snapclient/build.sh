#!/bin/bash
set -euo pipefail

SNAPCAST_VERSION="${SNAPCAST_VERSION:-master}"
IMAGE="riemerk/mr-do-snapclient"

echo "Building ${IMAGE} (snapcast ${SNAPCAST_VERSION})"

docker buildx build \
    --tag "${IMAGE}:latest" \
    --build-arg SNAPCAST_VERSION="${SNAPCAST_VERSION}" \
    .

VERSION=$(docker run --rm "${IMAGE}:latest" snapclient -v 2>/dev/null | awk 'NR==1 {print $2}' | sed 's/^v//' || echo "dev")
docker tag "${IMAGE}:latest" "${IMAGE}:${VERSION}"
echo "Tagged ${IMAGE}:${VERSION}"
