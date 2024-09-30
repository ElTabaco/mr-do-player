FROM ubuntu

# Install necessary packages
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    gmediarender \
 #   alsa-utils \
 #   avahi-daemon \
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
EXPOSE 49494

ENV DEVICE_NAME=mr-do-upnp
# Run the entrypoint script
#ENTRYPOINT ["gmediarender", "--port=49494", "-f", "AlpineUPnPRenderer", "--gstout-audiosink=alsasink"]

ENTRYPOINT exec gmediarender --friendly-name "mr Media Renderer" --port=49494 --gstout-audiosink=alsasink

#tcpclientsink host=host.docker.internal
#gmediarender --friendly-name "Docker Media Renderer" --port=49494 --gstout-audiosink="tcpclientsink host=127.0.0.1 port=3000"