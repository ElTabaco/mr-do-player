# mr-do-player

[![Build Images](https://github.com/riemerk/mr-do-snapserver/actions/workflows/actions.yml/badge.svg?branch=master)](https://github.com/riemerk/mr-do-snapserver/actions/workflows/actions.yml)


Run a [Snapcast](https://github.com/snapcast/snapcast) server as a Docker container.
Spotify Connect is provided by the separate [mr-do-soloist](../mr-do-soloist/README.md) container
(Spotify Soloist -> PulseAudio pipe sink -> FIFO), read by snapserver as a `pipe://` stream.

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
| `SNAPWEB_VERSION` | `v0.9.3` | release tag of https://github.com/snapcast/snapweb (`snapweb.zip` asset) |

The cloned snapcast commit is stored in the image as `/usr/share/snapserver/snapcast-commit`.

### Image tags

| Tag | Meaning |
|---|---|
| `latest` | most recent build |
| `<snapserver>-<snapcast commit>` | unique per build, e.g. `0.35.0-4fed179` (from `snapserver -v` and `/usr/share/snapserver/snapcast-commit`) |

The Kubernetes deployment uses `imagePullPolicy: IfNotPresent`, so it must reference the
unique tag; reusing a tag leaves the node on its cached image. `build.sh`, `push.sh` and the
`Docker Image CI master` workflow all produce the same tag scheme.

### Build manual:

```console
docker build -t riemer/mr-do-snapserver --build-arg ARCH=arm64 .
```

## Configuration:
* See docker compose file

| Item | Value |
|---|---|
| Ports | `1704/tcp` stream, `1705/tcp` control (JSON-RPC), `1780/tcp` HTTP + snapweb UI |
| Config file | `/etc/snapserver.conf` (example: `etc/snapserver.conf`) |
| Persistent state | `$HOME/.config/snapserver/server.json` (Kubernetes: `HOME=/home/snapserver`, NFS subPath `snapserver`) |
| snapweb | `/usr/share/snapserver/snapweb` (`[http] doc_root`) |
| `DEVICE_NAME` env | `mr-do-snapserver` |
| Spotify | `pipe:///tmp/music/spotifyfifo?name=mrSpot&sampleformat=48000:16:2&mode=read&idle_threshold=2000` (written by mr-do-soloist) |

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
* [Spotify Soloist](https://developer.spotify.com/documentation/soloist) (mr-do-soloist)
