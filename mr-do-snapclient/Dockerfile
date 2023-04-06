ARG ARCH=arm64

FROM alpine as snapclient
ARG SNAPCAST_VERSION=master
WORKDIR /root

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
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache  \
    -DBUILD_WITH_PULSE=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SERVER=OFF .. \
    && cmake --build build --parallel 3

FROM alpine as mr-do-snapclient
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

COPY --from=snapclient /root/snapcast/bin/snapclient /usr/local/bin

ENV DEVICE_NAME=mr-do-snapserver

ENTRYPOINT ["snapclient"]