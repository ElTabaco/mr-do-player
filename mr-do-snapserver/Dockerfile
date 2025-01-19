FROM node:alpine as snapweb
ARG SNAPCAST_VERSION=master

RUN wget https://github.com/badaix/snapweb/releases/download/v0.8.0/snapweb.zip \
    && mkdir -p /usr/share/snapserver/snapweb/ \
    && unzip -d /usr/share/snapserver/snapweb/ snapweb.zip 

# Final stage
FROM alpine as mr-do-snapserver
LABEL maintainer="riemerk"

RUN apk add --no-cache \
    snapcast-server

RUN apk add --no-cache -X \
    http://dl-cdn.alpinelinux.org/alpine/edge/testing librespot

RUN apk del --no-cache \
    unzip \
    which \
    wget


COPY --from=snapweb /usr/share/snapserver/snapweb /usr/share/snapserver/snapweb

ENV DEVICE_NAME=mr-do-snapserver
EXPOSE 1704/tcp 1705/tcp 1780/tcp 42661

ENTRYPOINT ["snapserver"]


