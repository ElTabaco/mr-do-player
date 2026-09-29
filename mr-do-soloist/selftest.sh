#!/bin/bash
# Self-test for the mr-do-soloist image (used by CI, also runnable locally).
# Needs Docker and internet access; no Spotify account or real API key.
#
# Checks:
#   1. the Soloist binary downloads and starts (glibc/library compatibility)
#   2. healthcheck.sh passes (PulseAudio pipe sink + Soloist daemon running)
#   3. audio played into PulseAudio arrives in the FIFO (non-silent PCM)
#   4. the container stops cleanly (exit code 0)
#   5. the whole container log has NO warning or error lines
set -euo pipefail

IMAGE="${1:?usage: selftest.sh <image>}"
name="soloist-selftest-$$"
work="$(mktemp -d)"
cleanup() {
    docker rm -f "${name}" >/dev/null 2>&1 || true
    # files in the bind mounts are owned by the container user 1000: remove them as root in a container
    docker run --rm --user 0 --entrypoint rm -v "${work}:/w" "${IMAGE}" -rf /w/music /w/data >/dev/null 2>&1 || true
    rm -rf "${work}"
}
trap cleanup EXIT

mkdir -p "${work}/music" "${work}/data"
chmod 0777 "${work}/music" "${work}/data"
mkfifo -m 0666 "${work}/music/spotifyfifo"

# reader, like snapserver (open blocks until PulseAudio opens the FIFO)
timeout 120 cat "${work}/music/spotifyfifo" > "${work}/out.raw" &
reader=$!

docker run -d --name "${name}" --user 1000:1000 --read-only \
    --tmpfs /run/soloist:mode=1777 --tmpfs /cache:mode=1777 \
    -v "${work}/music:/tmp/music" -v "${work}/data:/data" \
    -e SOLOIST_API_KEY=selftest-dummy-key -e SOLOIST_DEVICE_NAME=selftest \
    "${IMAGE}" >/dev/null

ok=0
for _ in $(seq 1 60); do
    if docker exec "${name}" /usr/local/bin/healthcheck.sh >/dev/null 2>&1; then ok=1; break; fi
    sleep 2
done
if [ "${ok}" != 1 ]; then docker logs "${name}" 2>&1; echo "FAIL: healthcheck never passed"; exit 1; fi
# every shared library the downloaded Soloist binary links must resolve in the image
if docker exec "${name}" sh -c 'ldd /data/bin/soloist' | grep "not found"; then echo "FAIL: missing library for soloist"; exit 1; fi
echo "OK: healthcheck"

# 2 s of noise at 44.1 kHz (Spotify's rate) through PulseAudio -> resampled -> pipe sink (48 kHz)
docker exec "${name}" sh -c 'head -c 352800 /dev/urandom | pacat --raw --format=s16le --rate=44100 --channels=2'
sleep 2
# a second health check after playback (liveness probe path)
docker exec "${name}" /usr/local/bin/healthcheck.sh

docker stop -t 30 "${name}" >/dev/null
rc="$(docker inspect -f '{{.State.ExitCode}}' "${name}")"
wait "${reader}" 2>/dev/null || true
docker logs "${name}" > "${work}/log" 2>&1

echo "---- container log ----"
cat "${work}/log"
echo "-----------------------"

fail=0
bytes="$(stat -c %s "${work}/out.raw")"
nonsilent="$(tr -d '\000' < "${work}/out.raw" | wc -c)"
echo "FIFO: ${bytes} bytes read, ${nonsilent} non-zero bytes"
[ "${rc}" = 0 ] || { echo "FAIL: container exit code ${rc}"; fail=1; }
[ "${nonsilent}" -gt 100000 ] || { echo "FAIL: played audio did not arrive in the FIFO"; fail=1; }
if grep -n -i -E '(^|[^a-z])(e|w): |error|warn|fail|fatal|panic|unable|denied' "${work}/log"; then
    echo "FAIL: warning/error lines in the container log"; fail=1
fi
[ "${fail}" = 0 ] && echo "SELFTEST PASSED"
exit "${fail}"
