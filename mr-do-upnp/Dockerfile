FROM alpine:latest

# Install necessary packages
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends\
    gmediarender


# Cleanup
RUN apt-get clean && \
    apt-get -y -f autoremove --purge && \
    rm -rf /var/lib/apt/lists

# Expose the necessary ports
EXPOSE 8200 12345

ENV DEVICE_NAME=mr-do-upnp
# Run the entrypoint script
ENTRYPOINT ["gmediarender", "-f", "AlpineUPnPRenderer", "--gstout-audio-sink=alsasink"]
