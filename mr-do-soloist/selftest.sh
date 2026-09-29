#!/bin/bash
# Self-test for the mr-do-soloist images (used by CI, also runnable locally).
# Needs Docker and internet access; no Spotify account or real API key.
#
# Usage: selftest.sh <runtime image> <fetch image>
#
# Checks:
#   1. the fetch image downloads the Soloist binary (as uid 1000, read-only root), and a
#      second run finds the cached copy up to date (conditional download)
#   2. every shared library the Soloist binary links resolves in the distroless runtime image,
#      and libpulse.so.0 (loaded by Soloist at runtime) is present
#   3. the runtime image starts: healthcheck.sh passes (PulseAudio pipe sink + Soloist running)
#   4. audio played into PulseAudio arrives in the FIFO (non-silent PCM)
#   5. the container stops cleanly (exit code 0)
#   6. the logs of all containers have NO warning or error lines
set -euo pipefail

IMAGE="${1:?usage: selftest.sh <runtime image> <fetch image>}"
FETCH_IMAGE="${2:?usage: selftest.sh <runtime image> <fetch image>}"
name="soloist-selftest-$$"
work="$(mktemp -d)"
cleanup() {
    docker rm -f "${name}" >/dev/null 2>&1 || true
    # files in the bind mounts are owned by the container user 1000: remove them as root in a container
    docker run --rm --user 0 --entrypoint rm -v "${work}:/w" "${FETCH_IMAGE}" -rf /w/music /w/data >/dev/null 2>&1 || true
    rm -rf "${work}"
}
trap cleanup EXIT

mkdir -p "${work}/music" "${work}/data"
chmod 0777 "${work}/music" "${work}/data"
mkfifo -m 0666 "${work}/music/spotifyfifo"
fail=0

# ---- 1. fetch image ---------------------------------------------------------
fetch() {
    docker run --rm --user 1000:1000 --read-only --tmpfs /tmp:mode=1777 \
        -v "${work}/data:/data" -e SOLOIST_UPDATE_INTERVAL=0 "${FETCH_IMAGE}"
}
fetch > "${work}/fetch1.log" 2>&1 || { cat "${work}/fetch1.log"; echo "FAIL: fetch image (download)"; exit 1; }
fetch > "${work}/fetch2.log" 2>&1 || { cat "${work}/fetch2.log"; echo "FAIL: fetch image (cached)"; exit 1; }
echo "---- fetch log (download) ----"; cat "${work}/fetch1.log"
echo "---- fetch log (cached)   ----"; cat "${work}/fetch2.log"
grep -q "downloaded https://" "${work}/fetch1.log" || { echo "FAIL: first fetch did not download"; fail=1; }
grep -q "is up to date" "${work}/fetch2.log" || { echo "FAIL: second fetch did not use the cached binary"; fail=1; }
[ -x "${work}/data/bin/soloist" ] || { echo "FAIL: no soloist binary in /data/bin"; exit 1; }

# ---- 2. libraries of the Soloist binary in the runtime image ----------------
# (distroless has no ldd: the dynamic loader lists the resolved libraries)
docker run --rm --user 1000:1000 --read-only -v "${work}/data:/data:ro" --entrypoint sh "${IMAGE}" -c '
    for l in /lib64/ld-linux-x86-64.so.2 /lib/ld-linux-aarch64.so.1 /lib/ld-linux-armhf.so.3; do
        [ -e "$l" ] && exec "$l" --list /data/bin/soloist
    done
    echo "no dynamic loader found"; exit 1' > "${work}/libs.txt" 2>&1 || true
cat "${work}/libs.txt"
if grep -q -E "not found|no dynamic loader" "${work}/libs.txt" || ! grep -q "libc.so.6 =>" "${work}/libs.txt"; then
    echo "FAIL: missing library for soloist"; exit 1
fi
docker run --rm --entrypoint sh "${IMAGE}" -c 'ls /usr/lib/libpulse.so.0' >/dev/null \
    || { echo "FAIL: libpulse.so.0 missing"; exit 1; }
echo "OK: libraries"

# ---- 3. runtime image --------------------------------------------------------
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
echo "OK: healthcheck"

# ---- 4. 2 s of noise at 44.1 kHz (Spotify's rate) through PulseAudio -> resampled -> pipe sink (48 kHz)
docker exec "${name}" sh -c 'head -c 352800 /dev/urandom | pacat --raw --format=s16le --rate=44100 --channels=2'
sleep 2
# a second health check after playback (liveness probe path)
docker exec "${name}" /usr/local/bin/healthcheck.sh

# ---- 5. clean stop -----------------------------------------------------------
docker stop -t 30 "${name}" >/dev/null
rc="$(docker inspect -f '{{.State.ExitCode}}' "${name}")"
wait "${reader}" 2>/dev/null || true
docker logs "${name}" > "${work}/log" 2>&1

echo "---- container log ----"
cat "${work}/log"
echo "-----------------------"

# ---- 6. results --------------------------------------------------------------
bytes="$(stat -c %s "${work}/out.raw")"
nonsilent="$(tr -d '\000' < "${work}/out.raw" | wc -c)"
echo "FIFO: ${bytes} bytes read, ${nonsilent} non-zero bytes"
[ "${rc}" = 0 ] || { echo "FAIL: container exit code ${rc}"; fail=1; }
[ "${nonsilent}" -gt 100000 ] || { echo "FAIL: played audio did not arrive in the FIFO"; fail=1; }
if grep -n -i -E '(^|[^a-z])(e|w): |error|warn|fail|fatal|panic|unable|denied' \
        "${work}/log" "${work}/fetch1.log" "${work}/fetch2.log"; then
    echo "FAIL: warning/error lines in the container logs"; fail=1
fi
[ "${fail}" = 0 ] && echo "SELFTEST PASSED"
exit "${fail}"
