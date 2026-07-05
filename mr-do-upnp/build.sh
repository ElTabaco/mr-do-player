#!/bin/bash
set -euo pipefail

VERSION="${VERSION:-0.1.0}"
IMAGE="riemerk/mr-do-upnp"

echo "Building ${IMAGE} (version ${VERSION})"

docker buildx build \
    --tag "${IMAGE}:latest" \
    --tag "${IMAGE}:${VERSION}" \
    .
