FROM alpine as snapclient
ARG SNAPCAST_VERSION=develop
ARG TARGETARCH
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
    soxr

RUN if [ "$TARGETARCH" = "arm" ]; then \
    echo "Executing commands for $TARGETARCH architecture"; \
    apk add --no-cache libstdc++ \
    #    apk add --no-cache lib32stdc++6 \
    # docker exec -u root -it /bin/bash <container_id> ; \
    else \
    echo "Executing commands for other $TARGETARCH architecture"; \
    fi

RUN rm -rf \
    /etc/ssl \
    /var/cache/apk/* \
    /lib/apk/db/* \
    /root/snapcast \
    /usr/bin/dummy

COPY --from=snapclient /root/snapcast/bin/snapclient /usr/local/bin

ENV DEVICE_NAME=mr-do-snaclient

ENTRYPOINT ["snapclient"]