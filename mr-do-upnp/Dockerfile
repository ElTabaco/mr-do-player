FROM alpine:latest as upnp

# Install necessary packages
RUN apk add --no-cache \
    minidlna \
    ffmpeg \
    socat

# Cleanup
RUN rm -rf \
    /etc/ssl \
    /var/cache/apk/* \
    /lib/apk/db/* 

# Configure MiniDLNA
COPY mr-do-upnp/minidlna.conf /etc/minidlna.conf

# Create a directory for media files
RUN mkdir -p /media/dlna

# Expose the necessary ports
EXPOSE 8200 12345

# Add entrypoint script
COPY mr-do-upnp/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV DEVICE_NAME=mr-do-upnp
# Run the entrypoint script
ENTRYPOINT ["/entrypoint.sh"]
