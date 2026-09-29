#!/bin/bash
set -euo pipefail

SNAPCAST_VERSION="${SNAPCAST_VERSION:-develop}"
SNAPWEB_VERSION="${SNAPWEB_VERSION:-v0.9.3}"
IMAGE="riemerk/mr-do-snapserver"

echo "Building ${IMAGE} (snapcast ${SNAPCAST_VERSION}, snapweb ${SNAPWEB_VERSION})"

docker buildx build \
    --tag "${IMAGE}:latest" \
    --build-arg SNAPCAST_VERSION="${SNAPCAST_VERSION}" \
    --build-arg SNAPWEB_VERSION="${SNAPWEB_VERSION}" \
    .

# Unique tag: <snapserver version>-<snapcast commit>, e.g. 0.35.0-4fed179
# (the deployment uses imagePullPolicy IfNotPresent, so every rebuild needs a new tag)
SNAP_VER=$(docker run --rm "${IMAGE}:latest" snapserver -v 2>/dev/null | awk 'NR==1 {print $2}' | sed 's/^v//' || echo "dev")
SNAP_COMMIT=$(docker run --rm --entrypoint cat "${IMAGE}:latest" /usr/share/snapserver/snapcast-commit 2>/dev/null || echo "dev")
VERSION="${SNAP_VER}-${SNAP_COMMIT}"
docker tag "${IMAGE}:latest" "${IMAGE}:${VERSION}"
echo "Tagged ${IMAGE}:${VERSION}"
