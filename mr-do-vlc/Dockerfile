FROM ubuntu:22.10 AS vlcstreamer

ARG ARCH=arm64
ARG DEBIAN_FRONTEND=noninteractive

ARG VLC_UID="1000"
ARG VLC_GID="1000"

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="riemerk"

ENV DEVICE_NAME=mr-do-vlc

RUN groupadd -g "${VLC_GID}" vlc && \
  useradd -m -d /data -s /bin/sh -u "${VLC_UID}" -g "${VLC_GID}" vlc

RUN echo "**** install runtime ****"  \
  && apt-get update && apt-get upgrade -y && apt-get install --no-install-recommends -y -f \
  alsa-base \
  pulseaudio \
  vlc  \
  && echo "**** clean up ****" \
  && rm -rf \
  /var/lib/apt/lists/* \
  /var/tmp/* \
  && apt-get clean && apt-get -y autoremove --purge && rm -fR /var/lib/apt/lists

USER "vlc"

CMD cvlc -I http --http-password=. --no-video --sout-transcode-samplerate=48000 --one-instance file: /etc/playlist/Streaming.xspf --aout afile --audiofile-file /tmp/music/vlcfifo 
#CMD cvlc --no-video --aout afile --audiofile-file /tmp/music/vlcfifo 

