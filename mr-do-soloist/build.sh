#!/bin/bash
set -euo pipefail

# Build the mr-do-soloist image locally. Run from anywhere; the build context is the repo root.
# The Soloist binary is NOT built into the image (downloaded by the entrypoint at start).
DEBIAN_TAG="${DEBIAN_TAG:-trixie-slim}"
IMAGE="riemerk/mr-do-soloist"
cd "$(dirname "$0")/.."

echo "Building ${IMAGE} (debian ${DEBIAN_TAG})"

docker buildx build \
    --load \
    --tag "${IMAGE}:latest" \
    --build-arg DEBIAN_TAG="${DEBIAN_TAG}" \
    --file mr-do-soloist/Dockerfile \
    .

# Unique tag: <pulseaudio version>-<git tree hash of mr-do-soloist/>, e.g. 17.0-a1b2c3d.
# The tree hash only changes when files in mr-do-soloist/ change and is identical on a branch,
# its PR merge ref and main, so CI and the deployment agree on the tag.
# (the deployment uses imagePullPolicy IfNotPresent, so every change needs a new tag)
PA_VER=$(docker run --rm --entrypoint pulseaudio "${IMAGE}:latest" --version | awk '{print $2}' | cut -d+ -f1)
VERSION="${PA_VER}-$(git rev-parse --short=7 HEAD:mr-do-soloist)"
docker tag "${IMAGE}:latest" "${IMAGE}:${VERSION}"
echo "Tagged ${IMAGE}:${VERSION}"

# Self-test: download + start Soloist, PulseAudio -> FIFO audio path, clean log
bash mr-do-soloist/selftest.sh "${IMAGE}:${VERSION}"
