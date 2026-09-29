# syntax=docker/dockerfile:1

# ============================================================
# Stage 1: build snapserver
# ============================================================
FROM alpine:latest AS snapserver
ARG SNAPCAST_VERSION=develop

RUN apk add --no-cache \
        alsa-lib-dev \
        avahi-dev \
        bash \
        boost-dev \
        build-base \
        ccache \
        cmake \
        expat-dev \
        flac-dev \
        git \
        libvorbis-dev \
        opus-dev \
        soxr-dev \
        libstdc++ \
        openssl-dev

RUN git clone --recursive --depth 1 --branch ${SNAPCAST_VERSION} \
        https://github.com/snapcast/snapcast.git && \
    cd snapcast && \
    git rev-parse --short=7 HEAD > /snapcast-commit && \
    cmake -S . -B build \
        -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
        -DBUILD_WITH_PULSE=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_CLIENT=OFF && \
    cmake --build build --parallel "$(nproc)"

# ============================================================
# Stage 2: fetch snapweb UI
# ============================================================
FROM alpine:latest AS snapweb
ARG SNAPWEB_VERSION=v0.9.3

RUN apk add --no-cache wget unzip && \
    wget -q https://github.com/snapcast/snapweb/releases/download/${SNAPWEB_VERSION}/snapweb.zip && \
    mkdir -p /usr/share/snapserver/snapweb/ && \
    unzip -d /usr/share/snapserver/snapweb/ snapweb.zip

# ============================================================
# Stage 3: final runtime image
# ============================================================
FROM alpine:latest AS mr-do-snapserver
LABEL maintainer="riemerk"

RUN apk add --no-cache \
        libflac \
        alsa-lib \
        avahi-libs \
        musl \
        libexpat \
        libgcc \
        libogg \
        opus \
        soxr \
        openssl \
        libstdc++ \
        libvorbis

COPY --from=snapserver snapcast/bin/snapserver /usr/local/bin/
COPY --from=snapweb    /usr/share/snapserver/snapweb /usr/share/snapserver/snapweb
COPY --from=snapserver /snapcast-commit /usr/share/snapserver/snapcast-commit

ENV DEVICE_NAME=mr-do-snapserver

EXPOSE 1704/tcp 1705/tcp 1780/tcp

ENTRYPOINT ["snapserver"]
