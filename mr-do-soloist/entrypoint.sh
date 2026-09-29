#!/bin/bash
# mr-do-soloist entrypoint
#
#   D-Bus session bus  ->  PulseAudio (module-pipe-sink -> FIFO)  ->  Spotify Soloist
#
# snapserver reads the FIFO as a pipe:// stream. The Soloist binary is NOT part of the
# image (Spotify forbids redistribution); it is downloaded from Spotify's CDN on every
# start (only when newer, via If-Modified-Since) and cached in ${SOLOIST_BIN_DIR}.
# All settings are documented in mr-do-soloist/README.md.
set -euo pipefail

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
SOLOIST_DOWNLOAD_BASE="${SOLOIST_DOWNLOAD_BASE:-https://soloist-builds.spotifycdn.com}"
SOLOIST_VERBOSE="${SOLOIST_VERBOSE:-false}"
FIFO_PATH="${FIFO_PATH:-/tmp/music/spotifyfifo}"
SAMPLE_RATE="${SAMPLE_RATE:-48000}"
PA_LOG_LEVEL="${PA_LOG_LEVEL:-notice}"
PA_TEMPLATE="${PA_TEMPLATE:-/etc/mr-do-soloist/default.pa}"
DBUS_SESSION_CONF="${DBUS_SESSION_CONF:-/usr/share/dbus-1/session.conf}"
export HOME="${HOME:-/run/soloist/home}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/soloist/xdg}"
# the root filesystem is read-only: temporary files go to the writable run volume
export TMPDIR="${TMPDIR:-/run/soloist/tmp}"
export PULSE_SERVER="${PULSE_SERVER:-unix:${XDG_RUNTIME_DIR}/pulse-native}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"
# PulseAudio re-executes itself to set LD_BIND_NOW unless it is already set, and warns
# "Couldn't canonicalize binary path" when that re-exec is not possible.
export LD_BIND_NOW="${LD_BIND_NOW:-1}"
pa_socket="${PULSE_SERVER#unix:}"
bus_socket="${DBUS_SESSION_BUS_ADDRESS#unix:path=}"

pids=()
stop_children() {
    # reverse start order (soloist, pulseaudio, dbus), one at a time, so no process
    # loses its peer while it is still running
    for ((i=${#pids[@]}-1; i>=0; i--)); do
        kill -TERM "${pids[$i]}" 2>/dev/null || true
        wait "${pids[$i]}" 2>/dev/null || true
    done
}
on_term() { log "stopping"; stop_children; exit 0; }
trap on_term TERM INT

wait_for() {  # wait_for <seconds> <description> <command...>
    local t="$1" what="$2"; shift 2
    for ((n=0; n<t*10; n++)); do "$@" >/dev/null 2>&1 && return 0; sleep 0.1; done
    die "timeout after ${t}s waiting for ${what}"
}

# ---- 1. fetch / update the Soloist binary ----------------------------------
case "$(uname -m)" in
    x86_64)  arch=x86_64 ;;
    aarch64) arch=arm64 ;;
    armv7l)  arch=arm32 ;;
    *) die "unsupported architecture $(uname -m)" ;;
esac
mkdir -p "${HOME}" "${TMPDIR}" "${SOLOIST_DATA_DIR}" "${SOLOIST_BIN_DIR}" "${SOLOIST_CACHE_DIR}"
url="${SOLOIST_DOWNLOAD_BASE}/soloist_release_${arch}.tar.gz"
archive="${SOLOIST_BIN_DIR}/soloist_release_${arch}.tar.gz"
soloist="${SOLOIST_BIN_DIR}/soloist"
cond=()
[ -s "${archive}" ] && [ -x "${soloist}" ] && cond=(-z "${archive}")
rm -f "${archive}.part"
if curl --fail --silent --show-error --location --retry 3 --connect-timeout 10 --max-time 300 \
        --remote-time "${cond[@]}" -o "${archive}.part" "${url}"; then
    if [ -s "${archive}.part" ]; then
        staging="${SOLOIST_BIN_DIR}/.staging"
        rm -rf "${staging}" && mkdir -p "${staging}"
        tar -xzf "${archive}.part" -C "${staging}"
        "${staging}/soloist" --version >/dev/null || die "downloaded soloist binary does not run"
        mv -f "${staging}/soloist" "${soloist}"
        [ -f "${staging}/CHANGELOG.md" ] && mv -f "${staging}/CHANGELOG.md" "${SOLOIST_BIN_DIR}/CHANGELOG.md"
        mv -f "${archive}.part" "${archive}"
        rm -rf "${staging}"
        log "downloaded ${url}"
    else
        rm -f "${archive}.part"
        log "cached soloist binary is up to date"
    fi
elif [ -x "${soloist}" ]; then
    rm -f "${archive}.part"
    log "download not possible, using cached soloist binary"
else
    die "could not download ${url} and no cached binary in ${SOLOIST_BIN_DIR}"
fi
log "$("${soloist}" --version)"

# ---- 2. D-Bus session bus (PulseAudio probes it; without it PA logs warnings) ----
mkdir -p "${XDG_RUNTIME_DIR}"
chmod 0700 "${XDG_RUNTIME_DIR}"
rm -f "${bus_socket}" "${pa_socket}"
dbus-daemon --config-file="${DBUS_SESSION_CONF}" --address="${DBUS_SESSION_BUS_ADDRESS}" \
    --nofork --nopidfile --nosyslog &
pids+=($!)
wait_for 10 "D-Bus session bus" test -S "${bus_socket}"

# ---- 3. PulseAudio with a pipe sink writing into the snapserver FIFO --------
[ -p "${FIFO_PATH}" ] || die "${FIFO_PATH} is not a FIFO (created by the init-fifo init container)"
sed -e "s|@SOCKET@|${pa_socket}|g" \
    -e "s|@FIFO@|${FIFO_PATH}|g" \
    -e "s|@RATE@|${SAMPLE_RATE}|g" \
    "${PA_TEMPLATE}" > "${XDG_RUNTIME_DIR}/default.pa"
pa_args=(-n -F "${XDG_RUNTIME_DIR}/default.pa"
         --daemonize=no --system=no --use-pid-file=no
         --realtime=no --high-priority=no
         --exit-idle-time=-1 --disallow-exit --disallow-module-loading
         --log-target=stderr --log-level="${PA_LOG_LEVEL}")
[ -n "${PA_DL_SEARCH_PATH:-}" ] && pa_args+=(--dl-search-path="${PA_DL_SEARCH_PATH}")
pulseaudio "${pa_args[@]}" &
pids+=($!)
wait_for 20 "PulseAudio" pactl info

# ---- 4. Spotify Soloist ------------------------------------------------------
soloist_args=(-n "${SOLOIST_DEVICE_NAME}" -D "${SOLOIST_DATA_DIR}" -C "${SOLOIST_CACHE_DIR}"
              -z "${SOLOIST_CACHE_SIZE_MB}" -i "${SOLOIST_INITIAL_VOLUME}")
[ "${SOLOIST_VERBOSE}" = "true" ] && soloist_args+=(-v)
log "starting Spotify Connect device '${SOLOIST_DEVICE_NAME}' -> ${FIFO_PATH} (s16le ${SAMPLE_RATE} Hz stereo)"
# the API key is passed only as an argument and never logged
"${soloist}" "${soloist_args[@]}" -k "${SOLOIST_API_KEY}" &
pids+=($!)

# ---- supervise: if any process exits, stop the rest so the container restarts ----
set +e
wait -n "${pids[@]}"
rc=$?
log "a child process exited (rc=${rc}), stopping container"
stop_children
# soloist exit code 10 = build outdated; the container restart downloads the new build
exit "${rc}"
