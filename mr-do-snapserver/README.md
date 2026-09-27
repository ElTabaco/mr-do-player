# mr-do-player

[![Build Images](https://github.com/riemerk/mr-do-snapserver/actions/workflows/actions.yml/badge.svg?branch=master)](https://github.com/riemerk/mr-do-snapserver/actions/workflows/actions.yml)


Run a [Snapcast](https://github.com/snapcast/snapcast) server with [Spotify support](https://github.com/librespot-org/librespot) as a Docker container.

Free to everyone bring your changes with a branch to all like to improve.

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
### Build arguments

| Build arg | Default | Source |
|---|---|---|
| `SNAPCAST_VERSION` | `develop` | branch/tag of https://github.com/snapcast/snapcast (badaix releases from `develop`) |
| `LIBRESPOT_VERSION` | `dev` | branch/tag of https://github.com/librespot-org/librespot (`dev` is the maintained line) |
| `SNAPWEB_VERSION` | `v0.9.3` | release tag of https://github.com/snapcast/snapweb (`snapweb.zip` asset) |

librespot is built with `--no-default-features --features "with-libmdns,rustls-tls-native-roots"`.

### Image tags

| Tag | Meaning |
|---|---|
| `latest` | most recent build |
| `<snapserver>-librespot<version>-<commit>` | unique per build, e.g. `0.35.0-librespot0.8.0-939dc5e` (from `snapserver -v` and `librespot --version`) |

The Kubernetes deployment uses `imagePullPolicy: IfNotPresent`, so it must reference the
unique tag; reusing a tag leaves the node on its cached image. `build.sh`, `push.sh` and the
`Docker Image CI master` workflow all produce the same tag scheme.

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

## Main credits: 
[Snapcast](https://github.com/snapcast/snapcast) from badaix

### Credits
* [DockerSnapclient](https://github.com/Saiyato/snapclient_docker)
* [DockerSnapcast](https://github.com/Saiyato/snapserver_docker)
* [librespot](https://github.com/librespot-org/librespot)
