#!/bin/bash
set -euo pipefail

IMAGE="riemerk/mr-do-snapserver"

# Requires: docker login done beforehand (or DOCKER_USERNAME / DOCKER_PASSWORD env vars)
if [[ -n "${DOCKER_USERNAME:-}" && -n "${DOCKER_PASSWORD:-}" ]]; then
    echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin
fi

# Unique tag: <snapserver version>-<snapcast commit>, e.g. 0.35.0-4fed179
# (the deployment uses imagePullPolicy IfNotPresent, so every rebuild needs a new tag)
SNAP_VER=$(docker run --rm "${IMAGE}:latest" snapserver -v 2>/dev/null | awk 'NR==1 {print $2}' | sed 's/^v//' || echo "dev")
SNAP_COMMIT=$(docker run --rm --entrypoint cat "${IMAGE}:latest" /usr/share/snapserver/snapcast-commit 2>/dev/null || echo "dev")
VERSION="${SNAP_VER}-${SNAP_COMMIT}"

docker push "${IMAGE}:latest"
docker push "${IMAGE}:${VERSION}"
echo "Pushed ${IMAGE}:latest and ${IMAGE}:${VERSION}"
