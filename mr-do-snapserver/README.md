# red-do-player

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
docker build -t riemer/mr-do-player --build-arg ARCH=arm64 .
```

## Run:

See docker compose file

# Images:

###### ARM64

[![docker image size](https://img.shields.io/docker/image-size/riemerk/mr-do-snapserver/latest?style=flat-square)](https://hub.docker.com/r/riemerk/mr-do-snapserver)
[![docker pulls](https://img.shields.io/docker/pulls/riemerk/mr-do-snapserver)](https://hub.docker.com/r/riemerk/mr-do-snapserver)
    
### Notes:

All code all i reuse is liked direkt to the main creator in Doker file.

Main credits: 
[Snapcast from badaiy](https://github.com/badaix/snapcast)