# red-do-player

Run a [Snapcast](https://github.com/badaix/snapcast) server with [Spotify support](https://github.com/librespot-org/librespot) as a Docker container.

Free for everyone to bring your modifikations with a branch to all who like to use and improve.

_Note: You need a Spotify premium account._

## Building the images

* The following lines will build _and push_ your image. Use the `build` make target in order to just build the image locally.
Build:
    Clon repo
    gon in folder
    modify build.sh if you have extra wishess
 ```   
    ./build.sh
```

Build maual:
```
    docker build -t riemer/mr-do-player --build-arg ARCH=arm64 .
```

Then, on your PC:
```
    make manifest IMAGE_NAME=my/image
```

Run:
    See docker compose file
Notes:
    All code all i reuse is liked direkt to the main creator in Doker file
    main credits: https://github.com/badaix/snapcast