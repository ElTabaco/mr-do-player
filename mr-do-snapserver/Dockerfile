# syntax=docker/dockerfile:1

# ============================================================
# Stage 1: build librespot (Spotify client)
# ============================================================
FROM alpine:latest AS librespot

RUN apk add --no-cache \
        curl \
        git \
        cargo \
        rust

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

# librespot-org/librespot 'dev' branch is the only maintained line
# (master/main no longer tracked upstream). Override via --build-arg LIBRESPOT_VERSION=dev
ARG LIBRESPOT_VERSION=dev
RUN git clone --depth 1 --branch ${LIBRESPOT_VERSION} \
        https://github.com/librespot-org/librespot.git && \
    cd librespot && \
    cargo build --release --no-default-features \
        --features "with-libmdns,rustls-tls-native-roots"

RUN cp librespot/target/release/librespot /usr/bin/librespot

# ============================================================
# Stage 2: build snapserver
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
        https://github.com/badaix/snapcast.git && \
    cd snapcast && \
    cmake -S . -B build \
        -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
        -DBUILD_WITH_PULSE=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_CLIENT=OFF && \
    cmake --build build --parallel "$(nproc)"

# ============================================================
# Stage 3: fetch snapweb UI
# ============================================================
FROM alpine:latest AS snapweb

RUN apk add --no-cache wget unzip && \
    wget -q https://github.com/badaix/snapweb/releases/download/v0.9.1/snapweb.zip && \
    mkdir -p /usr/share/snapserver/snapweb/ && \
    unzip -d /usr/share/snapserver/snapweb/ snapweb.zip

# ============================================================
# Stage 4: final runtime image
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
COPY --from=librespot  /usr/bin/librespot /usr/local/bin/

ENV DEVICE_NAME=mr-do-snapserver

EXPOSE 1704/tcp 1705/tcp 1780/tcp 42661/tcp

ENTRYPOINT ["snapserver"]
