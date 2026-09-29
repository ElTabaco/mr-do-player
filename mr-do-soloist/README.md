# mr-do-soloist

Spotify Connect for snapserver, using Spotify's official headless client
[Soloist](https://developer.spotify.com/documentation/soloist). Replaces librespot.

```
Spotify app --(Spotify Connect)--> Soloist --> PulseAudio module-pipe-sink --> /tmp/music/spotifyfifo --> snapserver (pipe:// stream "mrSpot")
```

Why not librespot: Spotify refuses the audio decryption key for newer accounts
(`error audio key 0 1`, [librespot#1649](https://github.com/librespot-org/librespot/issues/1649)),
so tracks stay at 0:00. Soloist is Spotify's own client and is not affected. The Soloist API key
cannot be used by librespot (it is only sent by Soloist during pairing; the key refusal is
server-side and depends on the account, not on the login method).

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
   login in `/data` (`/data/cache/dbrts`); it survives restarts.

### Login fails: `login failed: make sure --api-key is valid`

The phone finds the device, but Spotify rejects the login. With `SOLOIST_VERBOSE=true` the log shows
`Access denied from backend` / `Auth code grant failed, error: session_access_denied`.
Seen with a key generated on an account that had **no app** in the developer dashboard. Fix:

1. https://developer.spotify.com/dashboard → **Create app** (any name, Redirect URI
   `http://127.0.0.1:8888/callback`, tick *Web API*, accept the terms, save).
2. https://developer.spotify.com/dashboard/soloist → generate a **new** key (the old one becomes invalid).
3. Replace the Secret and restart the pod:
   ```console
   read -rsp "Soloist API key: " K; echo; kubectl -n mr-do-player create secret generic mr-do-soloist --from-literal=SOLOIST_API_KEY="$K" --dry-run=client -o yaml | kubectl apply -f -; unset K
   kubectl -n mr-do-player rollout restart deploy/mr-do-player
   ```
4. Select **mrSpot** in the Spotify app again. The log then shows `logged in as <user>` and `became active device`.

Follow-up retries in the same attempt log `session_auth_info_not_found`; that is only a consequence
of the first refusal.

## Two images

Both are built from `mr-do-soloist/Dockerfile` (`--target`) and pushed to the same repository:

| Image | Target | Base | Content | Size (amd64, compressed) |
|---|---|---|---|---|
| `riemerk/mr-do-soloist:<tag>` | `mr-do-soloist` (default) | `gcr.io/distroless/cc-debian13:nonroot` | PulseAudio (compiled, minimal), busybox, `entrypoint.sh`, `healthcheck.sh`, `default.pa` | ~13 MB |
| `riemerk/mr-do-soloist:<tag>-fetch` | `mr-do-soloist-fetch` | `curlimages/curl:8.22.0` (Alpine) | `fetch-soloist.sh` | ~11 MB |

The runtime image has no curl and no package manager; downloading is done only by the fetch image.
Before this split the single `debian:trixie-slim` image was 43.7 MB.

## Soloist binary: downloaded, not in the image

Spotify's terms do not allow redistributing the Soloist binary, so it is **not** part of any image.
`fetch-soloist.sh` (fetch image) downloads it from Spotify's CDN into `${SOLOIST_BIN_DIR}` (`/data/bin`),
only when the CDN has a newer build (`curl -z`, If-Modified-Since against the cached archive):

| Architecture (`uname -m`) | URL |
|---|---|
| `x86_64` | https://soloist-builds.spotifycdn.com/soloist_release_x86_64.tar.gz |
| `aarch64` | https://soloist-builds.spotifycdn.com/soloist_release_arm64.tar.gz |
| `armv7l` | https://soloist-builds.spotifycdn.com/soloist_release_arm32.tar.gz |

`fetch-soloist.sh`:

1. Checks once, then touches `${SOLOIST_FETCH_READY_FILE}` (its startup probe / compose healthcheck).
   No network and no cached binary: exits with an error. No network but a cached binary: uses it.
2. With `SOLOIST_UPDATE_INTERVAL` > 0 (default 86400 s = 1 day) it keeps running and checks again
   after every interval. `SOLOIST_UPDATE_INTERVAL=0`: check once and exit.
3. A new build is unpacked into `bin/.staging`, checked (`tar` integrity, non-empty `soloist`) and
   renamed over `bin/soloist` (atomic). The binary needs glibc and is not run in the Alpine fetch
   image; `entrypoint.sh` runs `soloist --version` at start and fails if it does not run.

Each Soloist build expires after ~90 days (`client expires in N days` in the log). An expired build
exits with code 10; Kubernetes/docker restarts the mr-do-soloist container, which then runs the newest
build the fetch container downloaded.

## Image contents and size (runtime image)

Soloist plays through PulseAudio or PipeWire only (no ALSA/stdout/pipe backend). PulseAudio is
smaller than PipeWire (no session manager needed). Soloist needs glibc >= 2.38, so no Alpine/musl:
the base is `gcr.io/distroless/cc-debian13` (glibc 2.41, libgcc, libstdc++, CA certificates, no shell).

The builder stage (`debian:trixie-slim`) compiles, with `build-pulseaudio.sh`:

- **libsndfile 1.2.2** without codecs (`ENABLE_EXTERNAL_LIBS=OFF`, `ENABLE_MPEG=OFF`): Debian's package
  pulls in FLAC, Vorbis, Opus, mpg123 and LAME; the pipe sink needs none of them.
- **PulseAudio 17.0** without D-Bus, X11, systemd, udev, ALSA, ORC, soxr, GLib, OpenSSL, Bluetooth,
  JACK, GStreamer, IPv6 (`-Ddbus=disabled -Dx11=disabled ...`, full list in the script).
  Resampler: speexdsp (PulseAudio default `speex-float-1`). libcap is linked: PulseAudio drops
  capabilities at start and logs a warning without it.

Only these files go into the runtime image (~2.8 MB):

| Path | From |
|---|---|
| `/usr/bin/pulseaudio`, `/usr/bin/pactl`, `/usr/bin/pacat` | PulseAudio build |
| `/usr/lib/pulseaudio/modules/module-pipe-sink.so`, `module-native-protocol-unix.so`, `libprotocol-native.so` | PulseAudio build |
| `/usr/lib/libpulse.so.0`, `/usr/lib/pulseaudio/libpulsecommon-17.0.so`, `libpulsecore-17.0.so` | PulseAudio build (`libpulse.so.0` is also loaded by Soloist at runtime) |
| `/usr/lib/libsndfile.so.1` | libsndfile build |
| `/usr/lib/<multiarch>/libltdl.so.7`, `libspeexdsp.so.1`, `libcap.so.2` | Debian (linked by PulseAudio) |
| `/usr/lib/<multiarch>/libatomic.so.1` | Debian (linked by the Soloist binary; not in distroless/cc) |
| `/usr/bin/busybox` + applets `sh cat chmod grep head kill ln ls mkdir rm sed seq sleep` | Debian `busybox-static` (the scripts, probes and `selftest.sh`) |

The libraries are in `/usr/lib` and `/usr/lib/<multiarch>`, the dynamic loader's default search path,
so no `ld.so.cache` is needed. Not included: D-Bus, ALSA plugins, codecs, ffmpeg, X11, systemd, curl,
the Soloist binary. Soloist loads ffmpeg (`libavcodec`/`libavformat`) only if present, for playing local
files; Spotify streams do not need it.

## Processes (entrypoint.sh, busybox sh)

1. `bin/soloist` must exist (downloaded by the fetch container). It is hard-linked to
   `bin/soloist.running` and started from there: when the fetch container replaces `bin/soloist`, the
   running daemon and `healthcheck.sh` (`soloist ctl`) keep using the same build; the next container
   start links the new one. `soloist --version` is logged.
2. `pulseaudio` with `default.pa`: native socket `${PULSE_SERVER}` (anonymous, container-local) and
   `module-pipe-sink` `snapfifo` writing `s16le ${SAMPLE_RATE} Hz stereo` into `${FIFO_PATH}`.
   Spotify's 44.1 kHz is resampled (speexdsp) to `SAMPLE_RATE`.
3. `soloist -n ${SOLOIST_DEVICE_NAME} -k <key> -D ${SOLOIST_DATA_DIR} -C ${SOLOIST_CACHE_DIR} -z ${SOLOIST_CACHE_SIZE_MB} -i ${SOLOIST_INITIAL_VOLUME}`.
   The API key is passed only as an argument and never logged.
4. If one of the two processes exits, the other is stopped and the container exits with that exit
   code (`<name> exited (rc=N), stopping container`), so Kubernetes/docker restarts it.
   SIGTERM stops Soloist, then PulseAudio (exit 0).

The FIFO must exist before start (created by the `init-fifo` init container / compose service).
PulseAudio holds it open for writing the whole time and writes silence when nothing plays.

## Environment variables

Runtime image (`entrypoint.sh`, `healthcheck.sh`):

| Variable | Default | Description |
|---|---|---|
| `SOLOIST_API_KEY` | – (required) | Soloist developer API key. Kubernetes: Secret `mr-do-soloist`, key `SOLOIST_API_KEY`. |
| `SOLOIST_DEVICE_NAME` | `mrSpot` | Spotify Connect device name shown in the Spotify apps. |
| `SOLOIST_DATA_DIR` | `/data` | Persistent data: stored login, device id, Soloist binary. |
| `SOLOIST_BIN_DIR` | `${SOLOIST_DATA_DIR}/bin` | Where the Soloist binary is read from (written by the fetch image). |
| `SOLOIST_CACHE_DIR` | `/cache` | Soloist audio cache (can be temporary). |
| `SOLOIST_CACHE_SIZE_MB` | `300` | Max cache size in MB (Soloist minimum 100, `0` = unlimited). |
| `SOLOIST_INITIAL_VOLUME` | `100` | Initial Soloist volume 0–100 (Soloist default would be 40). Volume is controlled in snapcast. |
| `SOLOIST_VERBOSE` | `false` | `true` = Soloist `-v` (all logs). |
| `FIFO_PATH` | `/tmp/music/spotifyfifo` | Named pipe read by snapserver. |
| `SAMPLE_RATE` | `48000` | Sample rate written to the FIFO (s16le, 2 channels). Must match snapserver's `sampleformat`. |
| `PA_LOG_LEVEL` | `notice` | PulseAudio log level (`error`, `warn`, `notice`, `info`, `debug`). |
| `PA_TEMPLATE` | `/etc/mr-do-soloist/default.pa` | PulseAudio startup script template (`@SOCKET@`, `@FIFO@`, `@RATE@`). |
| `PA_DL_SEARCH_PATH` | – | Optional PulseAudio module directory override (local testing only). |
| `HOME` | `/run/soloist/home` | Home directory (writable run volume). |
| `TMPDIR` | `/run/soloist/tmp` | Temporary files (the root filesystem is read-only). |
| `XDG_RUNTIME_DIR` | `/run/soloist/xdg` | PulseAudio runtime directory (mode 0700). |
| `PULSE_SERVER` | `unix:/run/soloist/xdg/pulse-native` | PulseAudio native socket (Soloist, `pactl`, `pacat`). |
| `LD_BIND_NOW` | `1` | Prevents PulseAudio's self re-exec (would log `Couldn't canonicalize binary path`). |
| `TZ` | – | Time zone for log timestamps, e.g. `Europe/Berlin`. |

Fetch image (`fetch-soloist.sh`):

| Variable | Default | Description |
|---|---|---|
| `SOLOIST_DATA_DIR` | `/data` | Same volume as the runtime image's `/data`. |
| `SOLOIST_BIN_DIR` | `${SOLOIST_DATA_DIR}/bin` | Download target. |
| `SOLOIST_DOWNLOAD_BASE` | `https://soloist-builds.spotifycdn.com` | Download base URL. |
| `SOLOIST_UPDATE_INTERVAL` | `86400` | Seconds between update checks; `0` = check once and exit. |
| `SOLOIST_FETCH_READY_FILE` | `/tmp/soloist-fetch.ready` | Written after the first check (startup probe / healthcheck). |
| `TZ` | – | Time zone. |

## Volumes / paths

| Path | Container | Type | Content |
|---|---|---|---|
| `/data` | both | persistent (Kubernetes: NFS PVC `mr-do-player-pvc-data`, subPath `soloist` = `/srv/nfs4/homes/mr/media/soloist`) | `bin/soloist`, `bin/soloist.running` (hard link), `bin/soloist_release_<arch>.tar.gz` (kept for If-Modified-Since), `bin/CHANGELOG.md`, `.device_id`, stored Spotify login, `crashpad/` |
| `/cache` | runtime | temporary (emptyDir 512 Mi) | Soloist audio cache (`SOLOIST_CACHE_SIZE_MB`) |
| `/run/soloist` | runtime | temporary, memory (emptyDir 16 Mi) | `home/`, `tmp/`, `xdg/` (`pulse-native`, rendered `default.pa`) |
| `/tmp/music` | runtime | shared with snapserver (emptyDir) | `spotifyfifo` (named pipe, created by `init-fifo`) |
| `/tmp` | fetch | temporary, memory (emptyDir 1 Mi) | `soloist-fetch.ready` |
| `/etc/mr-do-soloist/default.pa` | runtime | in image | PulseAudio startup script template |
| `/usr/local/bin/entrypoint.sh`, `/usr/local/bin/healthcheck.sh` | runtime | in image | Entrypoint, probe script |
| `/usr/local/bin/fetch-soloist.sh` | fetch | in image | Entrypoint |

## User, security, network

| Item | Value |
|---|---|
| User / group | `1000:1000` in both images (`USER 1000:1000`; the pod sets it too). No `/etc/passwd` entry needed. |
| Root filesystem | read-only (all writes go to the volumes above) |
| Capabilities | none (`drop: ALL`), no privilege escalation |
| Network | host network (Kubernetes `hostNetwork: true`): Spotify Connect uses mDNS multicast (5353/UDP) and a ZeroConf HTTP port that Soloist picks at start. No fixed port to expose. |
| Outbound | fetch: HTTPS to `soloist-builds.spotifycdn.com`. Runtime: HTTPS to Spotify's servers (playback). |

## Health checks

- Runtime: `healthcheck.sh`: `pactl list short sinks` must list `snapfifo` (PulseAudio runs and holds
  the FIFO) and `soloist ctl status -D ${SOLOIST_DATA_DIR}` must report `running`. Used as the Kubernetes
  startup/liveness probe and the compose `healthcheck`. In Kubernetes the container is a native
  sidecar (`initContainers` + `restartPolicy: Always`), so snapserver starts only after the
  startup probe passed and never reads EOF from the Spotify FIFO. The startup probe retries it
  every 0.5 s inside one probe run, so no `Unhealthy` Warning event appears while it starts.
- Fetch: `test -f /tmp/soloist-fetch.ready` (startup probe / compose healthcheck): the first check is done.

## Image tags

| Tag | Meaning |
|---|---|
| `latest`, `latest-fetch` | most recent build |
| `<pulseaudio version>-<tree>`, `<pulseaudio version>-<tree>-fetch` | unique per content, e.g. `17.0-a1b2c3d`: PulseAudio version from `pulseaudio --version`, `<tree>` = git tree hash of `mr-do-soloist/` (`git rev-parse --short=7 HEAD:mr-do-soloist`) |

The tree hash only changes when a file in `mr-do-soloist/` changes and is the same on the branch,
the PR merge ref and `main`. The deployment uses `imagePullPolicy: IfNotPresent` and must reference
the unique tags (both images with the same `<tree>`).

## Build arguments

| Build arg | Default | Description |
|---|---|---|
| `DEBIAN_TAG` | `trixie-slim` | Builder stage base (must match the distroless Debian release: 13 = trixie) |
| `DISTROLESS_IMAGE` | `gcr.io/distroless/cc-debian13:nonroot` | Runtime base (glibc >= 2.38 required by Soloist) |
| `CURL_IMAGE` | `curlimages/curl:8.22.0` | Fetch image base |
| `PULSEAUDIO_VERSION` | `17.0` | PulseAudio release (https://www.freedesktop.org/software/pulseaudio/releases/) |
| `PULSEAUDIO_SHA256` | `053794d6…ceb87b5` | SHA-256 of `pulseaudio-<version>.tar.xz` (verified) |
| `LIBSNDFILE_VERSION` | `1.2.2` | libsndfile release (https://github.com/libsndfile/libsndfile/releases) |
| `LIBSNDFILE_SHA256` | `3799ca99…6cdb80e` | SHA-256 of `libsndfile-<version>.tar.xz` (verified) |

Build context is the **repository root** (`docker build -f mr-do-soloist/Dockerfile --target <target> .`).
Platforms built by CI: `linux/amd64`, `linux/arm64`. The CI caches the builder stage (GitHub Actions cache,
scope `soloist`).

## Build and test

```console
./mr-do-soloist/build.sh          # build both images, tag <pa>-<tree>[-fetch], run selftest.sh
bash mr-do-soloist/selftest.sh riemerk/mr-do-soloist:latest riemerk/mr-do-soloist:latest-fetch
```

`selftest.sh` (also run by the `Docker Image CI soloist` workflow before pushing), with a dummy key,
read-only root and user 1000:

1. fetch image: downloads the Soloist binary; a second run reports it up to date
2. all libraries of the downloaded binary resolve in the distroless image (dynamic loader `--list`), `libpulse.so.0` present
3. runtime image: `healthcheck.sh` passes
4. 2 s of 44.1 kHz audio played with `pacat` arrive resampled in the FIFO
5. clean stop (exit 0)
6. **no** warning/error line in any container log

Playback of real Spotify audio needs a real key and account and is not part of the self-test.

## Expected logs

```
[mr-do-soloist-fetch] soloist binary is up to date (d4e0266380d1)
[mr-do-soloist-fetch] checking for a newer build every 86400s
```

```
[mr-do-soloist] soloist 1.3.8.93 build ... (linux/x86_64)
[mr-do-soloist] starting Spotify Connect device 'mrSpot' -> /tmp/music/spotifyfifo (s16le 48000 Hz stereo)
<date>: client expires in 89 days
<date>: ready, device_name=mrSpot device_id=...
<date>: waiting for login — connect to "mrSpot" from your Spotify app
<date>: running
```

## Credits

- [Spotify Soloist](https://developer.spotify.com/documentation/soloist) – Spotify
- [PulseAudio](https://www.freedesktop.org/wiki/Software/PulseAudio/), [libsndfile](https://libsndfile.github.io/libsndfile/)
- [distroless](https://github.com/GoogleContainerTools/distroless), [curl-docker](https://github.com/curl/curl-container), [BusyBox](https://busybox.net/)
