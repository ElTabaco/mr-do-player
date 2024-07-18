#!/bin/sh

# Start the MiniDLNA server
minidlnad -f /etc/minidlna.conf

# Use ffmpeg to stream audio over TCP
#ffmpeg -re -i /media/dlna/sample.mp3 -f mp3 - | socat - TCP-LISTEN:12345,fork
