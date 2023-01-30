ARG ALPINE_BASE="3.17"
ARG ARCH=arm64

FROM alpine:${ALPINE_BASE} AS librespot
# source: https://github.com/librespot-org/librespot

WORKDIR /librespot

RUN apk -U add \
    cargo portaudio-dev protobuf-dev

RUN cargo install librespot

RUN cp -r /root/.cargo/bin/librespot /usr/local/bin

#RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

#RUN git clone https://github.com/librespot-org/librespot.git && \
#    cd librespot && \
#    cargo build --release --no-default-features


# ****** ****** ****** ****** ****** ****** ****** ****** 
# source: https://github.com/Saiyato/snapclient_docker
# source: https://github.com/Saiyato/snapserver_docker

FROM alpine:${ALPINE_BASE} as snapserver
# main credits: https://github.com/badaix/snapcast
ARG SNAPCAST_VERSION=master

RUN apk -U add \
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
    soxr-dev


RUN git clone --recursive --depth 1 --branch $SNAPCAST_VERSION https://github.com/badaix/snapcast.git \
    && cd snapcast \
    && cmake -S . -B build \
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
    -DBUILD_WITH_PULSE=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_CLIENT=OFF \
    &&  cmake --build build --parallel 3

FROM node:alpine as snapweb

RUN apk -U add build-base git \
    && npm install -g typescript \
    && git clone https://github.com/badaix/snapweb \
    && make -C snapweb

# Final stage
FROM alpine:${ALPINE_BASE} AS mr-do-snapserver
LABEL maintainer="riemerk"

RUN apk add --no-cache \
    alsa-lib \
    avahi-libs \
    expat \
    flac \
    libvorbis \
    opus \
    soxr \
    && rm -rf /etc/ssl /var/cache/apk/* /lib/apk/db/* /root/snapcast /usr/bin/dummy

COPY --from=snapserver snapcast/bin/snapserver /usr/local/bin/
COPY --from=snapweb snapweb/dist/ /usr/share/snapserver/snapweb
COPY --from=librespot /root/.cargo/bin/librespot /usr/local/bin/

ENV DEVICE_NAME=mr-do-snapserver
EXPOSE 1704/tcp 1705/tcp 1780/tcp

ENTRYPOINT ["snapserver"]



