# syntax=docker/dockerfile:1

# ============================================================
# Stage 1: build snapclient
# ============================================================
FROM alpine:latest AS snapclient
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
        openssl-dev

RUN git clone --recursive --depth 1 --branch ${SNAPCAST_VERSION} \
        https://github.com/badaix/snapcast.git && \
    cd snapcast && \
    cmake -S . -B build \
        -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
        -DBUILD_WITH_PULSE=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SERVER=OFF && \
    cmake --build build --parallel "$(nproc)"

# ============================================================
# Stage 2: final runtime image
# ============================================================
FROM alpine:latest AS mr-do-snapclient
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

COPY --from=snapclient /root/snapcast/bin/snapclient /usr/local/bin/

ENV DEVICE_NAME=mr-do-snapclient

ENTRYPOINT ["snapclient"]
