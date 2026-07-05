#!/bin/bash
set -euo pipefail

IMAGE="riemerk/mr-do-upnp"
VERSION="${VERSION:-0.1.0}"

if [[ -n "${DOCKER_USERNAME:-}" && -n "${DOCKER_PASSWORD:-}" ]]; then
    echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin
fi

docker push "${IMAGE}:latest"
docker push "${IMAGE}:${VERSION}"
echo "Pushed ${IMAGE}:latest and ${IMAGE}:${VERSION}"
