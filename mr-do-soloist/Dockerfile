# syntax=docker/dockerfile:1
#
# mr-do-soloist: Spotify Connect for snapserver.
#   Spotify Soloist -> PulseAudio (module-pipe-sink) -> FIFO -> snapserver pipe:// stream
#
# The Soloist binary is NOT in this image (Spotify forbids redistribution). The entrypoint
# downloads it from https://soloist-builds.spotifycdn.com at start and caches it in the
# data volume. Soloist needs glibc >= 2.38 -> Debian trixie (2.41), not Alpine (musl).
#
# Size: the Debian pulseaudio package pulls in ALSA plugins, ffmpeg codecs, etc. The builder
# stage installs it, and only the files actually used (pulseaudio, pactl, pacat, dbus-daemon,
# 2 PulseAudio modules + libprotocol-native and the libraries they link) are copied into the
# runtime image.
ARG DEBIAN_TAG=trixie-slim

# ============================================================
# Stage 1: collect the minimal PulseAudio + D-Bus file set
# ============================================================
FROM debian:${DEBIAN_TAG} AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        pulseaudio pulseaudio-utils dbus-daemon dbus-session-bus-common && \
    rm -rf /var/lib/apt/lists/*

RUN set -eu; \
    moddir="$(echo /usr/lib/pulse-*/modules)"; \
    test -d "${moddir}"; \
    bins="/usr/bin/pulseaudio /usr/bin/pactl /usr/bin/pacat /usr/bin/dbus-daemon \
          ${moddir}/module-pipe-sink.so ${moddir}/module-native-protocol-unix.so \
          ${moddir}/libprotocol-native.so"; \
    mkdir -p /out; \
    # copy <file> to /out under its canonical directory (Debian is merged-/usr: /lib -> usr/lib;
    # a real /out/lib directory would replace the /lib symlink in the runtime image)
    put() { d="$(readlink -f "$(dirname "$1")")"; mkdir -p "/out${d}"; cp -L "$1" "/out${d}/$(basename "$1")"; }; \
    for f in ${bins} /usr/share/dbus-1/session.conf; do put "${f}"; done; \
    if ldd ${bins} | grep "not found"; then exit 1; fi; \
    # glibc is already in the runtime base image (same Debian release)
    ldd ${bins} | awk '/=> \//{print $3}' | sort -u \
      | grep -v -E '/(libc|libm|libdl|libpthread|librt|libresolv|ld-linux[^/]*)\.so' \
      | while read -r lib; do put "${lib}"; done; \
    test ! -e /out/lib && test ! -e /out/bin; \
    du -sh /out

# ============================================================
# Stage 2: runtime image
# ============================================================
FROM debian:${DEBIAN_TAG} AS mr-do-soloist
LABEL maintainer="riemerk" \
      org.opencontainers.image.source="https://github.com/ElTabaco/mr-do-player" \
      org.opencontainers.image.description="Spotify Soloist + PulseAudio pipe sink for snapserver"

# curl + CA certificates: Soloist download at start; Soloist itself also needs the CA store
# libatomic1: linked by the Soloist binary (readelf NEEDED: libc, libm, libatomic, ld-linux).
#   Soloist also dlopen()s libpulse.so.0 (copied below) and, only for local files, ffmpeg
#   (libavcodec/libavformat) - not installed, Spotify streams are decoded by Soloist itself.
# user/group 1000: PulseAudio, D-Bus and Soloist look up the running uid in /etc/passwd
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl libatomic1 && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd -g 1000 soloist && \
    useradd -u 1000 -g 1000 -d /run/soloist/home -M -s /usr/sbin/nologin soloist && \
    # static machine id: libdbus/PulseAudio read it, the read-only root cannot create it at runtime
    tr -d '-' < /proc/sys/kernel/random/uuid > /etc/machine-id

COPY --from=builder /out/ /
RUN ldconfig && pulseaudio --version && pactl --version && dbus-daemon --version | head -1

COPY mr-do-soloist/entrypoint.sh  /usr/local/bin/entrypoint.sh
COPY mr-do-soloist/healthcheck.sh /usr/local/bin/healthcheck.sh
COPY mr-do-soloist/default.pa     /etc/mr-do-soloist/default.pa
RUN chmod 0755 /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

ENV SOLOIST_DEVICE_NAME=mrSpot \
    SOLOIST_DATA_DIR=/data \
    SOLOIST_CACHE_DIR=/cache \
    FIFO_PATH=/tmp/music/spotifyfifo \
    SAMPLE_RATE=48000 \
    HOME=/run/soloist/home \
    XDG_RUNTIME_DIR=/run/soloist/xdg \
    TMPDIR=/run/soloist/tmp \
    PULSE_SERVER=unix:/run/soloist/xdg/pulse-native \
    DBUS_SESSION_BUS_ADDRESS=unix:path=/run/soloist/xdg/bus \
    LD_BIND_NOW=1

USER 1000:1000
VOLUME ["/data", "/cache", "/run/soloist", "/tmp/music"]
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
