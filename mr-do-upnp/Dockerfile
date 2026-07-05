# syntax=docker/dockerfile:1

FROM ubuntu:24.04

ENV UPNP_NAME="mr do Media Renderer" \
    UPNP_PORT=49494 \
    DEVICE_NAME=mr-do-upnp \
    DEBIAN_FRONTEND=noninteractive

# Install gmediarender + gstreamer plugins, then clean up in one layer
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gmediarender \
        gstreamer1.0-alsa \
        gstreamer1.0-plugins-base \
        gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-bad \
        gstreamer1.0-plugins-ugly && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

EXPOSE 49494/tcp 1900/udp

ENTRYPOINT exec gmediarender \
    --friendly-name "${UPNP_NAME}" \
    --port=${UPNP_PORT} \
    --gstout-audiosink=alsasink
