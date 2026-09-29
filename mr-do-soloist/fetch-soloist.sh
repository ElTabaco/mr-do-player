#!/bin/sh
# mr-do-soloist-fetch: download / update the Spotify Soloist binary.
#
# Image riemerk/mr-do-soloist:<tag>-fetch (based on curlimages/curl). The Soloist binary is
# NOT part of any image (Spotify forbids redistribution); it is downloaded from Spotify's
# CDN into ${SOLOIST_BIN_DIR} on the persistent data volume, which the mr-do-soloist
# container reads. A download happens only when the CDN has a newer build (HTTP
# If-Modified-Since against the cached archive).
#
# Kubernetes runs this as a native sidecar started before mr-do-soloist: it checks once,
# writes ${SOLOIST_FETCH_READY_FILE} (its startupProbe), then re-checks every
# ${SOLOIST_UPDATE_INTERVAL} seconds. Soloist builds expire (~90 days, exit code 10); a
# restart of the mr-do-soloist container then runs the newer binary downloaded here.
# SOLOIST_UPDATE_INTERVAL=0 checks once and exits (plain init container / one-shot use).
#
# The binary needs glibc and cannot run in this (Alpine/musl) image: the archive is only
# checked for integrity here; the mr-do-soloist entrypoint runs `soloist --version` at start.
# All settings are documented in mr-do-soloist/README.md.
set -eu

log() { echo "[mr-do-soloist-fetch] $*"; }
die() { echo "[mr-do-soloist-fetch] ERROR: $*" >&2; exit 1; }

SOLOIST_DATA_DIR="${SOLOIST_DATA_DIR:-/data}"
SOLOIST_BIN_DIR="${SOLOIST_BIN_DIR:-${SOLOIST_DATA_DIR}/bin}"
SOLOIST_DOWNLOAD_BASE="${SOLOIST_DOWNLOAD_BASE:-https://soloist-builds.spotifycdn.com}"
SOLOIST_UPDATE_INTERVAL="${SOLOIST_UPDATE_INTERVAL:-86400}"
SOLOIST_FETCH_READY_FILE="${SOLOIST_FETCH_READY_FILE:-/tmp/soloist-fetch.ready}"

case "${SOLOIST_UPDATE_INTERVAL}" in
    ''|*[!0-9]*) die "SOLOIST_UPDATE_INTERVAL must be a number of seconds (0 = check once and exit)" ;;
esac
case "$(uname -m)" in
    x86_64)  arch=x86_64 ;;
    aarch64) arch=arm64 ;;
    armv7l)  arch=arm32 ;;
    *) die "unsupported architecture $(uname -m)" ;;
esac

url="${SOLOIST_DOWNLOAD_BASE}/soloist_release_${arch}.tar.gz"
archive="${SOLOIST_BIN_DIR}/soloist_release_${arch}.tar.gz"
soloist="${SOLOIST_BIN_DIR}/soloist"
part="${archive}.part"
staging="${SOLOIST_BIN_DIR}/.staging"

# fetch: 0 = binary ready (downloaded or cached copy up to date), 1 = download failed
fetch() {
    # conditional download only when a complete cached copy exists
    set --
    if [ -s "${archive}" ] && [ -f "${soloist}" ]; then set -- -z "${archive}"; fi
    rm -rf "${part}" "${staging}"
    # -q: ignore any ~/.curlrc
    if ! curl -q --fail --silent --show-error --location --retry 3 --connect-timeout 10 \
            --max-time 300 --remote-time "$@" -o "${part}" "${url}"; then
        rm -f "${part}"
        return 1
    fi
    if [ ! -s "${part}" ]; then
        rm -f "${part}"
        log "soloist binary is up to date ($(sha256sum "${soloist}" | cut -c1-12))"
        return 0
    fi
    mkdir -p "${staging}"
    if ! tar -xzf "${part}" -C "${staging}" || [ ! -s "${staging}/soloist" ]; then
        rm -rf "${part}" "${staging}"
        log "downloaded archive ${url} is corrupt or contains no soloist binary"
        return 1
    fi
    chmod 0755 "${staging}/soloist"
    # rename is atomic: a running soloist keeps its old inode, the next start runs the new one
    mv -f "${staging}/soloist" "${soloist}"
    if [ -f "${staging}/CHANGELOG.md" ]; then mv -f "${staging}/CHANGELOG.md" "${SOLOIST_BIN_DIR}/CHANGELOG.md"; fi
    mv -f "${part}" "${archive}"
    rm -rf "${staging}"
    log "downloaded ${url} ($(sha256sum "${soloist}" | cut -c1-12))"
}

trap 'log "stopping"; exit 0' TERM INT

mkdir -p "${SOLOIST_BIN_DIR}"
rm -f "${SOLOIST_FETCH_READY_FILE}"
if ! fetch; then
    [ -f "${soloist}" ] || die "could not download ${url} and no cached binary in ${SOLOIST_BIN_DIR}"
    log "download not possible, using cached soloist binary"
fi
touch "${SOLOIST_FETCH_READY_FILE}"
[ "${SOLOIST_UPDATE_INTERVAL}" -gt 0 ] || exit 0

log "checking for a newer build every ${SOLOIST_UPDATE_INTERVAL}s"
while :; do
    # `sleep & wait` keeps the TERM trap responsive
    sleep "${SOLOIST_UPDATE_INTERVAL}" &
    wait $!
    fetch || log "download not possible, keeping the cached soloist binary"
done
