ARG TARGETARCH
ARG TARGETPLATFORM

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
    soxr-dev \
    libssl-dev

RUN git clone --recursive --depth 1 --branch $SNAPCAST_VERSION https://github.com/badaix/snapcast.git \
    && cd snapcast \
    && cmake -S . -B build \
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache  \
    -DBUILD_WITH_PULSE=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SERVER=OFF .. \
    && cmake --build build --parallel 3

#--- mr-do-snapclient ------------------------
FROM alpine as mr-do-snapclient
LABEL maintainer="riemerk"

RUN apk add --no-cache \
    flac \
    alsa-lib \
    avahi-libs \
    libgcc \
    libogg \
    libvorbis \
    opus \
    soxr \
    libstdc++ \
    libvorbis

RUN apk del --no-cache \
    wget

RUN rm -rf \
    /etc/ssl \
    /var/cache/apk/* \
    /lib/apk/db/* \
    /etc/apk/repositories \
    /usr/bin/dummy

COPY --from=snapclient /root/snapcast/bin/snapclient /usr/local/bin

ENV DEVICE_NAME=mr-do-snaclient

ENTRYPOINT ["snapclient"]
