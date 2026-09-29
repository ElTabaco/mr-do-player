#!/bin/sh
# mr-do-soloist entrypoint
#
#   PulseAudio (module-pipe-sink -> FIFO)  ->  Spotify Soloist
#
# snapserver reads the FIFO as a pipe:// stream. The Soloist binary is NOT part of the
# image (Spotify forbids redistribution); the mr-do-soloist-fetch container
# (fetch-soloist.sh) downloads it into ${SOLOIST_BIN_DIR} before this container starts.
# The image is distroless: /bin/sh and the tools used here are busybox applets.
# All settings are documented in mr-do-soloist/README.md.
set -eu

log() { echo "[mr-do-soloist] $*"; }
die() { echo "[mr-do-soloist] ERROR: $*" >&2; exit 1; }

# ---- configuration -----------------------------------------------------------
[ -n "${SOLOIST_API_KEY:-}" ] || die "SOLOIST_API_KEY is not set (create it at https://developer.spotify.com/dashboard/soloist)"
SOLOIST_DEVICE_NAME="${SOLOIST_DEVICE_NAME:-mrSpot}"
SOLOIST_DATA_DIR="${SOLOIST_DATA_DIR:-/data}"
SOLOIST_CACHE_DIR="${SOLOIST_CACHE_DIR:-/cache}"
SOLOIST_CACHE_SIZE_MB="${SOLOIST_CACHE_SIZE_MB:-300}"
SOLOIST_INITIAL_VOLUME="${SOLOIST_INITIAL_VOLUME:-100}"
SOLOIST_BIN_DIR="${SOLOIST_BIN_DIR:-${SOLOIST_DATA_DIR}/bin}"
SOLOIST_VERBOSE="${SOLOIST_VERBOSE:-false}"
FIFO_PATH="${FIFO_PATH:-/tmp/music/spotifyfifo}"
SAMPLE_RATE="${SAMPLE_RATE:-48000}"
PA_LOG_LEVEL="${PA_LOG_LEVEL:-notice}"
PA_TEMPLATE="${PA_TEMPLATE:-/etc/mr-do-soloist/default.pa}"
export HOME="${HOME:-/run/soloist/home}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/soloist/xdg}"
# the root filesystem is read-only: temporary files go to the writable run volume
export TMPDIR="${TMPDIR:-/run/soloist/tmp}"
export PULSE_SERVER="${PULSE_SERVER:-unix:${XDG_RUNTIME_DIR}/pulse-native}"
# PulseAudio re-executes itself to set LD_BIND_NOW unless it is already set, and warns
# "Couldn't canonicalize binary path" when that re-exec is not possible.
export LD_BIND_NOW="${LD_BIND_NOW:-1}"
pa_socket="${PULSE_SERVER#unix:}"
soloist="${SOLOIST_BIN_DIR}/soloist"

pa_pid=""
so_pid=""
stop_children() {
    # Soloist first, then PulseAudio, one at a time: no process loses its peer while running
    for p in ${so_pid} ${pa_pid}; do
        kill -TERM "${p}" 2>/dev/null || true
        wait "${p}" 2>/dev/null || true
    done
}
on_term() { log "stopping"; stop_children; exit 0; }
trap on_term TERM INT

wait_for() {  # wait_for <seconds> <description> <command...>
    t="$1" what="$2"; shift 2
    n=0
    while [ "${n}" -lt $((t * 10)) ]; do
        "$@" >/dev/null 2>&1 && return 0
        sleep 0.1
        n=$((n + 1))
    done
    die "timeout after ${t}s waiting for ${what}"
}

# ---- 1. Soloist binary (downloaded by the mr-do-soloist-fetch container) -----
[ -x "${soloist}" ] || die "${soloist} not found (downloaded by the mr-do-soloist-fetch container, fetch-soloist.sh)"
# Run a hard link, not ${soloist} itself: the fetch container replaces ${soloist} when a newer
# build appears; the link keeps the running build, so healthcheck.sh (`soloist ctl`) always
# uses the same build as the daemon. The next container start links the new build.
if ln -f "${soloist}" "${soloist}.running" 2>/dev/null; then soloist="${soloist}.running"; fi
version="$("${soloist}" --version)" || die "${soloist} does not run"
log "${version}"

# ---- 2. PulseAudio with a pipe sink writing into the snapserver FIFO --------
mkdir -p "${HOME}" "${TMPDIR}" "${XDG_RUNTIME_DIR}" "${SOLOIST_CACHE_DIR}"
chmod 0700 "${XDG_RUNTIME_DIR}"
rm -f "${pa_socket}"
[ -p "${FIFO_PATH}" ] || die "${FIFO_PATH} is not a FIFO (created by the init-fifo init container)"
sed -e "s|@SOCKET@|${pa_socket}|g" \
    -e "s|@FIFO@|${FIFO_PATH}|g" \
    -e "s|@RATE@|${SAMPLE_RATE}|g" \
    "${PA_TEMPLATE}" > "${XDG_RUNTIME_DIR}/default.pa"
set -- -n -F "${XDG_RUNTIME_DIR}/default.pa" \
       --daemonize=no --system=no --use-pid-file=no \
       --realtime=no --high-priority=no \
       --exit-idle-time=-1 --disallow-exit --disallow-module-loading \
       --log-target=stderr --log-level="${PA_LOG_LEVEL}"
if [ -n "${PA_DL_SEARCH_PATH:-}" ]; then set -- "$@" --dl-search-path="${PA_DL_SEARCH_PATH}"; fi
pulseaudio "$@" &
pa_pid=$!
wait_for 20 "PulseAudio" pactl info

# ---- 3. Spotify Soloist ------------------------------------------------------
set -- -n "${SOLOIST_DEVICE_NAME}" -D "${SOLOIST_DATA_DIR}" -C "${SOLOIST_CACHE_DIR}" \
       -z "${SOLOIST_CACHE_SIZE_MB}" -i "${SOLOIST_INITIAL_VOLUME}"
if [ "${SOLOIST_VERBOSE}" = "true" ]; then set -- "$@" -v; fi
log "starting Spotify Connect device '${SOLOIST_DEVICE_NAME}' -> ${FIFO_PATH} (s16le ${SAMPLE_RATE} Hz stereo)"
# the API key is passed only as an argument and never logged
"${soloist}" "$@" -k "${SOLOIST_API_KEY}" &
so_pid=$!

# ---- supervise: if a process exits, stop the other one so the container restarts ----
# (busybox sh has no `wait -n`; `sleep & wait` keeps the TERM trap responsive)
set +e
while kill -0 "${pa_pid}" 2>/dev/null && kill -0 "${so_pid}" 2>/dev/null; do
    sleep 1 &
    wait $!
done
if kill -0 "${so_pid}" 2>/dev/null; then name=pulseaudio; p="${pa_pid}"; else name=soloist; p="${so_pid}"; fi
wait "${p}"
rc=$?
log "${name} exited (rc=${rc}), stopping container"
stop_children
# soloist exit code 10 = build outdated: the container restarts and runs the newer binary
# that the mr-do-soloist-fetch container keeps downloading
exit "${rc}"
