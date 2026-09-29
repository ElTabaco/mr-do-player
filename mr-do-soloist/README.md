# mr-do-soloist

Spotify Connect for snapserver, using Spotify's official headless client
[Soloist](https://developer.spotify.com/documentation/soloist). Replaces librespot.

```
Spotify app --(Spotify Connect)--> Soloist --> PulseAudio module-pipe-sink --> /tmp/music/spotifyfifo --> snapserver (pipe:// stream "mrSpot")
```

Why not librespot: Spotify refuses the audio decryption key for newer accounts
(`error audio key 0 1`, [librespot#1649](https://github.com/librespot-org/librespot/issues/1649)),
so tracks stay at 0:00. Soloist is Spotify's own client and is not affected.

## Soloist API key

Soloist needs a developer API key. The key is bound to the Spotify **Premium** account that creates it;
listeners can then connect with any Spotify account (Free or Premium).

1. Log in at https://developer.spotify.com/dashboard with a Spotify Premium account.
2. Open https://developer.spotify.com/dashboard/soloist ("Spotify Soloist API Key").
3. Accept the terms if asked, then generate the API key and copy it. Never commit it.
4. Store it:
   - Kubernetes (on mr0, input is hidden and not stored in the shell history):
     ```console
     read -rsp "Soloist API key: " K; echo; kubectl -n mr-do-player create secret generic mr-do-soloist --from-literal=SOLOIST_API_KEY="$K"; unset K
     ```
   - docker compose: `SOLOIST_API_KEY=...` in `mr-do-player/docker/.env` (git-ignored).
5. In the Spotify app select the device **mrSpot** and play. Soloist stores the Spotify Connect
   login in `/data`; it survives restarts.

## Soloist binary: downloaded, not in the image

Spotify's terms do not allow redistributing the Soloist binary, so it is **not** part of this image.
The entrypoint downloads it from Spotify's CDN at every start, only when the CDN has a newer build
(`curl -z`, If-Modified-Since), and keeps it in `${SOLOIST_BIN_DIR}` (`/data/bin`):

| Architecture (`uname -m`) | URL |
|---|---|
| `x86_64` | https://soloist-builds.spotifycdn.com/soloist_release_x86_64.tar.gz |
| `aarch64` | https://soloist-builds.spotifycdn.com/soloist_release_arm64.tar.gz |
| `armv7l` | https://soloist-builds.spotifycdn.com/soloist_release_arm32.tar.gz |

Each Soloist build expires after ~90 days (`client expires in N days` in the log). An expired build
exits with code 10; the container restarts and downloads the current build. If the CDN is not
reachable at start, the cached binary is used.

## Image contents and size

Soloist plays through PulseAudio or PipeWire only (no ALSA/stdout/pipe backend). PulseAudio is
smaller than PipeWire (no session manager needed). The Dockerfile installs `pulseaudio` in a builder
stage and copies only the files used into a `debian:trixie-slim` runtime (Soloist needs glibc >= 2.38,
so no Alpine/musl):

- `pulseaudio`, `pactl`, `pacat`, `dbus-daemon` (+ `session.conf`)
- PulseAudio modules `module-pipe-sink`, `module-native-protocol-unix`, `libprotocol-native`
- the shared libraries these link (found with `ldd`), about 15 MB in total
- `curl` + `ca-certificates` (download; Soloist also needs the CA store)

Not included: ALSA plugins, ffmpeg codecs, X11, systemd, the Soloist binary.

## Processes (entrypoint.sh)

1. Download/update Soloist (see above), `soloist --version` is logged.
2. `dbus-daemon` session bus on `${DBUS_SESSION_BUS_ADDRESS}` (PulseAudio logs warnings without it).
3. `pulseaudio` with `default.pa`: native socket `${PULSE_SERVER}` (anonymous, container-local) and
   `module-pipe-sink` `snapfifo` writing `s16le ${SAMPLE_RATE} Hz stereo` into `${FIFO_PATH}`.
   Spotify's 44.1 kHz is resampled (`soxr`) to `SAMPLE_RATE`.
4. `soloist -n ${SOLOIST_DEVICE_NAME} -k <key> -D ${SOLOIST_DATA_DIR} -C ${SOLOIST_CACHE_DIR} -z ${SOLOIST_CACHE_SIZE_MB} -i ${SOLOIST_INITIAL_VOLUME}`.
   The API key is passed only as an argument and never logged.
5. If any of the three processes exits, the others are stopped (reverse order) and the container
   exits with that exit code, so Kubernetes/docker restarts it. SIGTERM stops everything cleanly (exit 0).

The FIFO must exist before start (created by the `init-fifo` init container / compose service).
PulseAudio holds it open for writing the whole time and writes silence when nothing plays.

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `SOLOIST_API_KEY` | – (required) | Soloist developer API key. Kubernetes: Secret `mr-do-soloist`, key `SOLOIST_API_KEY`. |
| `SOLOIST_DEVICE_NAME` | `mrSpot` | Spotify Connect device name shown in the Spotify apps. |
| `SOLOIST_DATA_DIR` | `/data` | Persistent data: stored login, device id, Soloist binary. |
| `SOLOIST_BIN_DIR` | `${SOLOIST_DATA_DIR}/bin` | Where the downloaded Soloist binary and archive are kept. |
| `SOLOIST_CACHE_DIR` | `/cache` | Soloist audio cache (can be temporary). |
| `SOLOIST_CACHE_SIZE_MB` | `300` | Max cache size in MB (Soloist minimum 100, `0` = unlimited). |
| `SOLOIST_INITIAL_VOLUME` | `100` | Initial Soloist volume 0–100 (Soloist default would be 40). Volume is controlled in snapcast. |
| `SOLOIST_DOWNLOAD_BASE` | `https://soloist-builds.spotifycdn.com` | Download base URL. |
| `SOLOIST_VERBOSE` | `false` | `true` = Soloist `-v` (all logs). |
| `FIFO_PATH` | `/tmp/music/spotifyfifo` | Named pipe read by snapserver. |
| `SAMPLE_RATE` | `48000` | Sample rate written to the FIFO (s16le, 2 channels). Must match snapserver's `sampleformat`. |
| `PA_LOG_LEVEL` | `notice` | PulseAudio log level (`error`, `warn`, `notice`, `info`, `debug`). |
| `PA_TEMPLATE` | `/etc/mr-do-soloist/default.pa` | PulseAudio startup script template (`@SOCKET@`, `@FIFO@`, `@RATE@`). |
| `PA_DL_SEARCH_PATH` | – | Optional PulseAudio module directory override (local testing only). |
| `DBUS_SESSION_CONF` | `/usr/share/dbus-1/session.conf` | D-Bus session bus config. |
| `HOME` | `/run/soloist/home` | Home directory (writable run volume). |
| `TMPDIR` | `/run/soloist/tmp` | Temporary files (the root filesystem is read-only). |
| `XDG_RUNTIME_DIR` | `/run/soloist/xdg` | PulseAudio/D-Bus runtime directory (mode 0700). |
| `PULSE_SERVER` | `unix:/run/soloist/xdg/pulse-native` | PulseAudio native socket (Soloist, `pactl`, `pacat`). |
| `DBUS_SESSION_BUS_ADDRESS` | `unix:path=/run/soloist/xdg/bus` | D-Bus session bus socket. |
| `LD_BIND_NOW` | `1` | Prevents PulseAudio's self re-exec (would log `Couldn't canonicalize binary path`). |
| `TZ` | – | Time zone for log timestamps, e.g. `Europe/Berlin`. |

## Volumes / paths

| Path | Type | Content |
|---|---|---|
| `/data` | persistent (Kubernetes: NFS PVC `mr-do-player-pvc-data`, subPath `soloist` = `/srv/nfs4/homes/mr/media/soloist`) | `bin/soloist`, `bin/soloist_release_<arch>.tar.gz`, `bin/CHANGELOG.md`, `.device_id`, stored Spotify login, `crashpad/` |
| `/cache` | temporary (emptyDir 512 Mi) | Soloist audio cache (`SOLOIST_CACHE_SIZE_MB`) |
| `/run/soloist` | temporary, memory (emptyDir 16 Mi) | `home/`, `tmp/`, `xdg/` (`bus`, `pulse-native`, rendered `default.pa`) |
| `/tmp/music` | shared with snapserver (emptyDir) | `spotifyfifo` (named pipe, created by `init-fifo`) |
| `/etc/mr-do-soloist/default.pa` | in image | PulseAudio startup script template |
| `/usr/local/bin/entrypoint.sh` | in image | Entrypoint |
| `/usr/local/bin/healthcheck.sh` | in image | Probe script |

## User, security, network

| Item | Value |
|---|---|
| User / group | `1000:1000` (`soloist`, home `/run/soloist/home`) |
| Root filesystem | read-only (all writes go to the volumes above) |
| Capabilities | none (`drop: ALL`), no privilege escalation |
| Network | host network (Kubernetes `hostNetwork: true`): Spotify Connect uses mDNS multicast (5353/UDP) and a ZeroConf HTTP port that Soloist picks at start. No fixed port to expose. |
| Outbound | HTTPS to `soloist-builds.spotifycdn.com` (download) and Spotify's servers (playback) |

## Health check

`healthcheck.sh`: `pactl list short sinks` must list `snapfifo` (PulseAudio runs and holds the FIFO)
and `soloist ctl status -D ${SOLOIST_DATA_DIR}` must report `running`. Used as the Kubernetes
startup/liveness probe and the compose `healthcheck`. In Kubernetes the container is a native
sidecar (`initContainers` + `restartPolicy: Always`), so snapserver starts only after the
startup probe passed and never reads EOF from the Spotify FIFO.

## Image tags

| Tag | Meaning |
|---|---|
| `latest` | most recent build |
| `<pulseaudio version>-<tree>` | unique per content, e.g. `17.0-a1b2c3d`: PulseAudio version from `pulseaudio --version`, `<tree>` = git tree hash of `mr-do-soloist/` (`git rev-parse --short=7 HEAD:mr-do-soloist`) |

The tree hash only changes when a file in `mr-do-soloist/` changes and is the same on the branch,
the PR merge ref and `main`. The deployment uses `imagePullPolicy: IfNotPresent` and must reference
the unique tag.

## Build arguments

| Build arg | Default | Description |
|---|---|---|
| `DEBIAN_TAG` | `trixie-slim` | Debian base image tag for builder and runtime (glibc >= 2.38 required by Soloist) |

Build context is the **repository root** (`docker build -f mr-do-soloist/Dockerfile .`).
Platforms built by CI: `linux/amd64`, `linux/arm64`.

## Build and test

```console
./mr-do-soloist/build.sh          # build, tag <pa>-<tree>, run selftest.sh
bash mr-do-soloist/selftest.sh riemerk/mr-do-soloist:latest
```

`selftest.sh` (also run by the `Docker Image CI soloist` workflow before pushing) starts the image
with a dummy key, read-only root and user 1000, and checks:
the Soloist download and start, `healthcheck.sh`, 2 s of 44.1 kHz audio played with `pacat`
arriving resampled in the FIFO, a clean stop (exit 0) and **no** warning/error line in the log.
Playback of real Spotify audio needs a real key and account and is not part of the self-test.

## Expected log

```
[mr-do-soloist] cached soloist binary is up to date
[mr-do-soloist] soloist 1.3.8.92 build ... (linux/x86_64)
[mr-do-soloist] starting Spotify Connect device 'mrSpot' -> /tmp/music/spotifyfifo (s16le 48000 Hz stereo)
<date>: client expires in 89 days
<date>: ready, device_name=mrSpot device_id=...
<date>: waiting for login — connect to "mrSpot" from your Spotify app
<date>: running
```

## Credits

- [Spotify Soloist](https://developer.spotify.com/documentation/soloist) – Spotify
- [PulseAudio](https://www.freedesktop.org/wiki/Software/PulseAudio/)
