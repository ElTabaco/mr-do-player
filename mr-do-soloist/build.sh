#!/bin/bash
set -euo pipefail

# Build the mr-do-soloist images locally. Run from anywhere; the build context is the repo root.
# The Soloist binary is NOT built into any image (downloaded by the fetch image at start).
#   riemerk/mr-do-soloist:<tag>        distroless runtime (PulseAudio compiled from source)
#   riemerk/mr-do-soloist:<tag>-fetch  curl image that downloads/updates the Soloist binary
IMAGE="riemerk/mr-do-soloist"
cd "$(dirname "$0")/.."

echo "Building ${IMAGE}"
docker buildx build --load --target mr-do-soloist \
    --tag "${IMAGE}:latest" --file mr-do-soloist/Dockerfile .
docker buildx build --load --target mr-do-soloist-fetch \
    --tag "${IMAGE}:latest-fetch" --file mr-do-soloist/Dockerfile .

# Unique tag: <pulseaudio version>-<git tree hash of mr-do-soloist/>, e.g. 17.0-a1b2c3d.
# The tree hash only changes when files in mr-do-soloist/ change and is identical on a branch,
# its PR merge ref and main, so CI and the deployment agree on the tag.
# (the deployment uses imagePullPolicy IfNotPresent, so every change needs a new tag)
PA_VER=$(docker run --rm --entrypoint pulseaudio "${IMAGE}:latest" --version | awk '{print $2}' | cut -d+ -f1)
VERSION="${PA_VER}-$(git rev-parse --short=7 HEAD:mr-do-soloist)"
docker tag "${IMAGE}:latest" "${IMAGE}:${VERSION}"
docker tag "${IMAGE}:latest-fetch" "${IMAGE}:${VERSION}-fetch"
echo "Tagged ${IMAGE}:${VERSION} and ${IMAGE}:${VERSION}-fetch"
docker images --format '{{.Repository}}:{{.Tag}} {{.Size}}' | grep -F "${IMAGE}:${VERSION}"

# Self-test: fetch the Soloist binary, start PulseAudio + Soloist, FIFO audio path, clean logs
bash mr-do-soloist/selftest.sh "${IMAGE}:${VERSION}" "${IMAGE}:${VERSION}-fetch"
