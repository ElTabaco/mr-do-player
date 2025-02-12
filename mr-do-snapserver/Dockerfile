FROM alpine AS librespot


RUN apk add --no-cache -X \
    http://dl-cdn.alpinelinux.org/alpine/edge/testing librespot

#WORKDIR /librespot

#RUN apk -U add \
#    cargo \
#    portaudio-dev \
#    protobuf-dev \
#    cmake
#RUN cargo install --force --locked bindgen-cli
#RUN cargo install librespot

#RUN cp -r /root/.cargo/bin/librespot /usr/local/bin

# -----------------------------------------------------------------
#RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

#RUN git clone https://github.com/librespot-org/librespot.git && \
#    cd librespot && \
#    cargo build --release --no-default-features

# ****** ****** ****** ****** ****** ****** ****** ****** 

FROM alpine as snapserver
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
    soxr-dev \
    libstdc++ \
    libressl-dev

RUN git clone --recursive --depth 1 --branch $SNAPCAST_VERSION https://github.com/badaix/snapcast.git \
    && cd snapcast \
    && cmake -S . -B build \
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
    -DBUILD_WITH_PULSE=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_CLIENT=OFF \
    &&  cmake --build build --parallel 3

FROM node:alpine as snapweb
ARG SNAPCAST_VERSION=master

#RUN apk -U add \
#    build-base \
#    git \
#    libflac \
#    npm \
#    && npm install -g typescript

#RUN git clone --recursive --depth 1 --branch master https://github.com/badaix/snapweb.git \
#    && make -C snapweb

RUN wget https://github.com/badaix/snapweb/releases/download/v0.8.0/snapweb.zip \
    && mkdir -p /usr/share/snapserver/snapweb/ \
    && unzip -d /usr/share/snapserver/snapweb/ snapweb.zip 

# Final stage
FROM alpine as mr-do-snapserver
LABEL maintainer="riemerk"

RUN apk add --no-cache \
    libflac \
    alsa-lib \
    avahi-libs \
    musl \
    libcrypto3 \
    libexpat \
    libgcc \
    libogg \
#    libvorbis \
    opus \
    soxr \
    libssl3 \
    libstdc++ \
    libvorbis

RUN apk del --no-cache \
    unzip \
    which \
    wget

RUN rm -rf \
#    /etc/ssl \
    /var/cache/apk/* \
#    /lib/apk/db/* \
    /etc/apk/repositories \
    /usr/bin/dummy

COPY --from=snapserver snapcast/bin/snapserver /usr/local/bin/
# COPY --from=snapserver server/etc/snapserver.conf /etc/
COPY --from=snapweb /usr/share/snapserver/snapweb /usr/share/snapserver/snapweb
#COPY --from=librespot /root/.cargo/bin/librespot /usr/local/bin/
COPY --from=librespot /usr/bin/librespot /usr/local/bin/

ENV DEVICE_NAME=mr-do-snapserver
EXPOSE 1704/tcp 1705/tcp 1780/tcp 42661/tcp

ENTRYPOINT ["snapserver"]
