# mr-do-player

[![Build Images](https://github.com/riemerk/mr-do-snapserver/actions/workflows/actions.yml/badge.svg?branch=master)](https://github.com/riemerk/mr-do-snapserver/actions/workflows/actions.yml)


Run a [Snapcast](https://github.com/badaix/snapcast) server with [Spotify support](https://github.com/librespot-org/librespot) as a Docker container.

Free for everyone to bring your modifikations with a branch to all who like to use and improve.

_Note: You need a Spotify premium account._

## Building the images

* Example how to build your image. Use the `build.sh` in order to just build the image locally.

### Build:

* Clone repository
* Enter folder
* Modify build.sh if you have extra whishess
```console
./build.sh
```
### Build manual:

```console
docker build -t riemer/mr-do-snapserver --build-arg ARCH=arm64 .
```

## Configuration:
* See docker compose file

## Run:
```console
docker-compose up -d
```

# Images:

### ARM64

[![docker image size](https://img.shields.io/docker/image-size/riemerk/mr-do-snapserver/latest?style=flat-square)](https://hub.docker.com/r/riemerk/mr-do-snapserver)
[![docker pulls](https://img.shields.io/docker/pulls/riemerk/mr-do-snapserver)](https://hub.docker.com/r/riemerk/mr-do-snapserver)
   
### Notes:

All reused code from main creators is linked direkt in Doker file.

Main credits: 
[Snapcast](https://github.com/badaix/snapcast) from badaix
