#!/bin/bash
set -euo pipefail

SNAPCAST_VERSION="${SNAPCAST_VERSION:-develop}"
SNAPWEB_VERSION="${SNAPWEB_VERSION:-v0.9.3}"
LIBRESPOT_VERSION="${LIBRESPOT_VERSION:-dev}"
IMAGE="riemerk/mr-do-snapserver"

echo "Building ${IMAGE} (snapcast ${SNAPCAST_VERSION}, librespot ${LIBRESPOT_VERSION}, snapweb ${SNAPWEB_VERSION})"

docker buildx build \
    --tag "${IMAGE}:latest" \
    --build-arg SNAPCAST_VERSION="${SNAPCAST_VERSION}" \
    --build-arg LIBRESPOT_VERSION="${LIBRESPOT_VERSION}" \
    --build-arg SNAPWEB_VERSION="${SNAPWEB_VERSION}" \
    .

# Unique tag: <snapserver>-librespot<version>-<commit>, e.g. 0.35.0-librespot0.8.0-939dc5e
# (the deployment uses imagePullPolicy IfNotPresent, so every rebuild needs a new tag)
SNAP_VER=$(docker run --rm "${IMAGE}:latest" snapserver -v 2>/dev/null | awk 'NR==1 {print $2}' | sed 's/^v//' || echo "dev")
LS_VER=$(docker run --rm --entrypoint librespot "${IMAGE}:latest" --version 2>/dev/null | awk 'NR==1 {print $2"-"$3}' || echo "dev")
VERSION="${SNAP_VER}-librespot${LS_VER}"
docker tag "${IMAGE}:latest" "${IMAGE}:${VERSION}"
echo "Tagged ${IMAGE}:${VERSION}"
