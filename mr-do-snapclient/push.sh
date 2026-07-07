#!/bin/bash
set -euo pipefail

IMAGE="riemerk/mr-do-snapclient"

if [[ -n "${DOCKER_USERNAME:-}" && -n "${DOCKER_PASSWORD:-}" ]]; then
    echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin
fi

VERSION=$(docker run --rm "${IMAGE}:latest" snapclient -v 2>/dev/null | awk 'NR==1 {print $2}' | sed 's/^v//' || echo "dev")

docker push "${IMAGE}:latest"
docker push "${IMAGE}:${VERSION}"
echo "Pushed ${IMAGE}:latest and ${IMAGE}:${VERSION}"
