# syntax=docker/dockerfile:1
#
# mr-do-soloist: Spotify Connect for snapserver.
#   Spotify Soloist -> PulseAudio (module-pipe-sink) -> FIFO -> snapserver pipe:// stream
#
# Two images from this file (build with --target):
#   mr-do-soloist        (default, last stage) distroless runtime: PulseAudio + busybox
#   mr-do-soloist-fetch  curlimages/curl + fetch-soloist.sh: downloads/updates the Soloist binary
#
# The Soloist binary is NOT in either image (Spotify forbids redistribution). The fetch
# container downloads it from https://soloist-builds.spotifycdn.com into the shared data
# volume. Soloist needs glibc >= 2.38: the runtime is distroless Debian 13 (glibc 2.41),
# not Alpine (musl).
#
# Size: PulseAudio and libsndfile are compiled without D-Bus, X11, systemd, ALSA and codecs
# (build-pulseaudio.sh). The runtime image gets only pulseaudio, pactl, pacat, the 3 modules
# the pipe sink setup loads and their libraries (~2.8 MB) plus a static busybox for the
# shell scripts, on top of gcr.io/distroless/cc (glibc, libgcc, libstdc++, CA certificates).
ARG DEBIAN_TAG=trixie-slim
ARG DISTROLESS_IMAGE=gcr.io/distroless/cc-debian13:nonroot
ARG CURL_IMAGE=curlimages/curl:8.22.0
ARG PULSEAUDIO_VERSION=17.0
ARG PULSEAUDIO_SHA256=053794d6671a3e397d849e478a80b82a63cb9d8ca296bd35b73317bb5ceb87b5
ARG LIBSNDFILE_VERSION=1.2.2
ARG LIBSNDFILE_SHA256=3799ca9924d3125038880367bf1468e53a1b7e3686a934f098b7e1d286cdb80e

# ============================================================
# Stage 1: build minimal PulseAudio + libsndfile, collect the runtime file set
# ============================================================
FROM debian:${DEBIAN_TAG} AS builder
ARG PULSEAUDIO_VERSION
ARG PULSEAUDIO_SHA256
ARG LIBSNDFILE_VERSION
ARG LIBSNDFILE_SHA256

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential ca-certificates cmake curl m4 meson ninja-build pkgconf xz-utils \
        libcap-dev libltdl-dev libspeexdsp-dev libatomic1 busybox-static && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src
# release tarballs, verified against pinned SHA-256 sums
RUN curl -fsSL -o pulseaudio.tar.xz \
        "https://www.freedesktop.org/software/pulseaudio/releases/pulseaudio-${PULSEAUDIO_VERSION}.tar.xz" && \
    echo "${PULSEAUDIO_SHA256}  pulseaudio.tar.xz" | sha256sum -c - && \
    curl -fsSL -o libsndfile.tar.xz \
        "https://github.com/libsndfile/libsndfile/releases/download/${LIBSNDFILE_VERSION}/libsndfile-${LIBSNDFILE_VERSION}.tar.xz" && \
    echo "${LIBSNDFILE_SHA256}  libsndfile.tar.xz" | sha256sum -c - && \
    mkdir pulseaudio libsndfile && \
    # the PulseAudio tarball contains ALSA mixer sample files with ':' in their names (not built)
    tar -xJf pulseaudio.tar.xz -C pulseaudio --strip-components=1 --exclude='*/mixer/samples/*' && \
    tar -xJf libsndfile.tar.xz -C libsndfile --strip-components=1

COPY mr-do-soloist/build-pulseaudio.sh /src/build-pulseaudio.sh
RUN sh /src/build-pulseaudio.sh /src/pulseaudio /src/libsndfile /out && \
    # static busybox: /bin/sh and the tools used by entrypoint.sh, healthcheck.sh, the pod's
    # startup probe (seq) and selftest.sh (head, ls)
    mkdir -p /out/usr/bin && cp /usr/bin/busybox /out/usr/bin/busybox && \
    for applet in sh cat chmod grep head kill ln ls mkdir rm sed seq sleep; do \
        ln -s busybox "/out/usr/bin/${applet}"; \
    done

# ============================================================
# Stage 2: fetch image (downloads / updates the Soloist binary)
# ============================================================
FROM ${CURL_IMAGE} AS mr-do-soloist-fetch
LABEL maintainer="riemerk" \
      org.opencontainers.image.source="https://github.com/ElTabaco/mr-do-player" \
      org.opencontainers.image.description="Downloads and updates the Spotify Soloist binary for mr-do-soloist"
COPY --chmod=0755 mr-do-soloist/fetch-soloist.sh /usr/local/bin/fetch-soloist.sh
ENV SOLOIST_DATA_DIR=/data
USER 1000:1000
ENTRYPOINT ["/usr/local/bin/fetch-soloist.sh"]

# ============================================================
# Stage 3: runtime image (default target)
# ============================================================
FROM ${DISTROLESS_IMAGE} AS mr-do-soloist
LABEL maintainer="riemerk" \
      org.opencontainers.image.source="https://github.com/ElTabaco/mr-do-player" \
      org.opencontainers.image.description="Spotify Soloist + PulseAudio pipe sink for snapserver"

# PulseAudio + libraries + libatomic (linked by the Soloist binary) + busybox.
# Libraries are in /usr/lib and /usr/lib/<multiarch>: default loader search path, no ld.so.cache.
COPY --from=builder /out/ /
COPY --chmod=0755 mr-do-soloist/entrypoint.sh  /usr/local/bin/entrypoint.sh
COPY --chmod=0755 mr-do-soloist/healthcheck.sh /usr/local/bin/healthcheck.sh
COPY mr-do-soloist/default.pa /etc/mr-do-soloist/default.pa

ENV SOLOIST_DEVICE_NAME=mrSpot \
    SOLOIST_DATA_DIR=/data \
    SOLOIST_CACHE_DIR=/cache \
    FIFO_PATH=/tmp/music/spotifyfifo \
    SAMPLE_RATE=48000 \
    HOME=/run/soloist/home \
    XDG_RUNTIME_DIR=/run/soloist/xdg \
    TMPDIR=/run/soloist/tmp \
    PULSE_SERVER=unix:/run/soloist/xdg/pulse-native \
    LD_BIND_NOW=1

# uid/gid 1000 (as the other mr-do-player containers); the pod sets it too
USER 1000:1000
VOLUME ["/data", "/cache", "/run/soloist", "/tmp/music"]
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
