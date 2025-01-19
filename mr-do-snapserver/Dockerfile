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
    snapcast-server

RUN apk add --no-cache -X \
    http://dl-cdn.alpinelinux.org/alpine/edge/testing librespot

RUN rm -rf \
    /etc/ssl \
    /var/cache/apk/* \
    /lib/apk/db/* \
    /etc/apk/repositories \
    /usr/bin/dummy

COPY --from=snapweb /usr/share/snapserver/snapweb /usr/share/snapserver/snapweb

ENV DEVICE_NAME=mr-do-snapserver
EXPOSE 1704/tcp 1705/tcp 1780/tcp 42661

ENTRYPOINT ["snapserver"]


