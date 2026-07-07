#!/bin/bash
set -euo pipefail

SNAPCAST_VERSION="${SNAPCAST_VERSION:-develop}"
LIBRESPOT_VERSION="${LIBRESPOT_VERSION:-dev}"
IMAGE="riemerk/mr-do-snapserver"

echo "Building ${IMAGE} (snapcast ${SNAPCAST_VERSION})"

docker buildx build \
    --tag "${IMAGE}:latest" \
    --build-arg SNAPCAST_VERSION="${SNAPCAST_VERSION}" \
    --build-arg LIBRESPOT_VERSION="${LIBRESPOT_VERSION}" \
    .

# Tag the version if the binary can report one
VERSION=$(docker run --rm "${IMAGE}:latest" snapserver -v 2>/dev/null | awk 'NR==1 {print $2}' | sed 's/^v//' || echo "dev")
docker tag "${IMAGE}:latest" "${IMAGE}:${VERSION}"
echo "Tagged ${IMAGE}:${VERSION}"
