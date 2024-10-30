FROM ubuntu
ENV UPNP_NAME="mr do Media Renderer"
ENV UPNP_PORT=49494
ENV DEVICE_NAME=mr-do-upnp

# Install necessary packages
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    gmediarender \
 #   gstreamer1.0-tools \
    gstreamer1.0-alsa \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly

    # Cleanup
    RUN apt-get clean && \
    apt-get -y -f autoremove --purge && \
    rm -rf /var/lib/apt/lists

# Expose the necessary ports
EXPOSE 49494/tcp 1900/udp

# Run the entrypoint script
ENTRYPOINT exec gmediarender --friendly-name "${UPNP_NAME}" --port=${UPNP_PORT} --gstout-audiosink=alsasink