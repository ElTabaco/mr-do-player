# mr-do-player

# Images:

## Snapserver

[![CI](https://github.com/ElTabaco/mr-do-player/actions/workflows/docker-image-master.yml/badge.svg)](https://hub.docker.com/r/riemerk/mr-do-snapserver)
[![docker image size](https://img.shields.io/docker/v/riemerk/mr-do-snapserver/latest?arch=arm64)](https://hub.docker.com/r/riemerk/mr-do-snapserver)

### ARM64

[![docker image size](https://img.shields.io/docker/image-size/riemerk/mr-do-snapserver/latest?arch=arm64)](https://hub.docker.com/r/riemerk/mr-do-snapserver)

### AMD64

[![docker image size](https://img.shields.io/docker/image-size/riemerk/mr-do-snapserver/latest?arch=amd64)](https://hub.docker.com/r/riemerk/mr-do-snapserver)

### Docker pulls

[![docker pulls](https://img.shields.io/docker/pulls/riemerk/mr-do-snapserver)](https://hub.docker.com/r/riemerk/mr-do-snapserver)

## Soloist (Spotify Connect)

Spotify's official headless client [Soloist](https://developer.spotify.com/documentation/soloist) with a
PulseAudio pipe sink into snapserver. Replaces librespot. See [mr-do-soloist](mr-do-soloist/README.md).
Two images: `riemerk/mr-do-soloist:<tag>` (distroless runtime with a minimal PulseAudio build) and
`riemerk/mr-do-soloist:<tag>-fetch` (downloads the Soloist binary, which is not in any image).

[![CI](https://github.com/ElTabaco/mr-do-player/actions/workflows/docker-image-soloist.yml/badge.svg)](https://hub.docker.com/r/riemerk/mr-do-soloist)
[![docker image size](https://img.shields.io/docker/image-size/riemerk/mr-do-soloist/latest?arch=amd64)](https://hub.docker.com/r/riemerk/mr-do-soloist)

## Snapclient

[![CI](https://github.com/ElTabaco/mr-do-player/actions/workflows/docker-image-client.yml/badge.svg)](https://hub.docker.com/r/riemerk/mr-do-snapclient)
[![docker image size](https://img.shields.io/docker/v/riemerk/mr-do-snapclient/latest?arch=arm64)](https://hub.docker.com/r/riemerk/mr-do-snapclient)

### ARM64

[![docker image size](https://img.shields.io/docker/image-size/riemerk/mr-do-snapclient/latest?arch=arm64)](https://hub.docker.com/r/riemerk/mr-do-snapclient)

### ARM32

[![docker image size](https://img.shields.io/docker/image-size/riemerk/mr-do-snapclient/latest?arch=arm)](https://hub.docker.com/r/riemerk/mr-do-snapclient)

### AMD64

[![docker image size](https://img.shields.io/docker/image-size/riemerk/mr-do-snapclient/latest?arch=amd64)](https://hub.docker.com/r/riemerk/mr-do-snapclient)

### Docker pulls

[![docker pulls](https://img.shields.io/docker/pulls/riemerk/mr-do-snapclient)](https://hub.docker.com/r/riemerk/mr-do-snapclient)

## UPnP / DLNA (mr-do-upnp-c)

> Moved to its own repo: [ElTabaco/mr-do-upnp-c](https://github.com/ElTabaco/mr-do-upnp-c)

[![CI](https://github.com/ElTabaco/mr-do-upnp-c/actions/workflows/docker-image-upnp-c.yml/badge.svg)](https://hub.docker.com/r/riemerk/mr-do-upnp-c)
[![docker image size](https://img.shields.io/docker/v/riemerk/mr-do-upnp-c/latest?arch=amd64)](https://hub.docker.com/r/riemerk/mr-do-upnp-c)

[![docker pulls](https://img.shields.io/docker/pulls/riemerk/mr-do-upnp-c)](https://hub.docker.com/r/riemerk/mr-do-upnp-c)

## Main credits: 
[Snapcast](https://github.com/badaix/snapcast) from badaix, [Spotify Soloist](https://developer.spotify.com/documentation/soloist)
