# mr-do-player

Plays audi stream to fifo file. Can used direkt with [Snapcast](https://github.com/badaix/snapcast).

## TODO:

* replace upnp player with minimal upnp player in c++ 
* Dependency to soundcard shall removed and something like tcp stream shall be used
* Direkt tcp stream from [Snapcast](https://github.com/badaix/snapcast) shall be used

## Run:

See docker compose file

## Kubernetes: snapserver settings

| Setting | Value | Why |
|---|---|---|
| `[server] mdns_enabled` | `false` | No avahi-daemon in the container or on the node. Without this snapserver logs `[Error] (Avahi) Failed to create client: Daemon not running`. Spotify Connect discovery is done by Soloist (mr-do-soloist) and is not affected. |
| startup/liveness probe | `tcpSocket` port `1780` (HTTP) | A bare TCP connect/close on the control port `1705` makes snapserver log `[Error] (ControlSessionTCP) Error while reading from control socket: End of file` every probe. |
| readiness probe | `tcpSocket` port `1780` | unchanged |

| Spotify stream `mrSpot` | `pipe:///tmp/music/spotifyfifo?name=mrSpot&sampleformat=44100:16:2&mode=read&idle_threshold=2000` | Written by the `mr-do-soloist` sidecar (PulseAudio pipe sink, s16le 44.1 kHz stereo). `idle_threshold=2000`: PulseAudio writes silence when nothing plays; after 2 s the stream is idle and `mrMusic` falls back to `upnp`. |
| Meta stream `mrMusic` | `meta:///mrSpot/upnp` | Plays Spotify when active, otherwise UPnP. |
| UPnP stream `upnp` | `pipe:///tmp/music/upnpfifo?name=upnp&sampleformat=44100:16:2` | Written by gmediarender through the ALSA `rate` + `file` plugins (`mr-do-asound-cfgmap`, 44100 Hz S16_LE). Files at other rates are resampled by GStreamer `audioresample quality=10` inside mr-do-upnp-c (`SAMPLE_RATE=44100`, `RESAMPLE_QUALITY=10`); measured 79 dB SNR at 15 kHz for 48 kHz files, ALSA's linear converter gave 13 dB. |
| `sampleformat` | `44100:16:2` | Spotify and most music files are 44.1 kHz: PulseAudio (Spotify) and ALSA (UPnP, 44.1 kHz files) pass them through bit-exact. Files with other rates (e.g. 48/96 kHz) are resampled by GStreamer `audioresample` (windowed sinc) in mr-do-upnp-c. Clients resample (soxr) only if their DAC does not support 44.1 kHz. With 48000 every Spotify track and every CD-quality file was resampled. `SAMPLE_RATE` of mr-do-soloist and `rate` in `asound.conf` must match. |
| `codec` | `flac` | lossless transport |
| `buffer` | `1500` ms | end-to-end latency; default 1000. More headroom against Wi-Fi dropouts on the clients (Pi Zero/armv6l). |

## Kubernetes: pod layout (`kubernetes/deployment.yml`)

| Container | Kind | Image | Purpose |
|---|---|---|---|
| `init-fifo` | init container | `busybox:1.36` | creates `/tmp/music/upnpfifo` and `/tmp/music/spotifyfifo` (mode 0666) |
| `mr-do-soloist-fetch` | native sidecar (`initContainers`, `restartPolicy: Always`) | `riemerk/mr-do-soloist:<pa>-<tree>-fetch` | downloads the Soloist binary into `/data/bin` (NFS) before `mr-do-soloist` starts, then checks for a newer build once a day |
| `mr-do-soloist` | native sidecar (`initContainers`, `restartPolicy: Always`) | `riemerk/mr-do-soloist:<pa>-<tree>` | Spotify Connect device `mrSpot` → PulseAudio pipe sink → `spotifyfifo`. Starts before the main containers (startup probe), see [mr-do-soloist](../mr-do-soloist/README.md) |
| `mr-do-upnp` | container | `riemerk/mr-do-upnp-c:2acefbd` | gmediarender UPnP renderer `mrCast` → GStreamer resampler (44.1 kHz) → ALSA file plugin → `upnpfifo` |
| `mr-do-snapserver` | container | `riemerk/mr-do-snapserver:<snapserver>-<snapcast commit>` | reads both FIFOs, serves snapclients and snapweb |

| mr-do-soloist setting | Value |
|---|---|
| Secret | `mr-do-soloist`, key `SOLOIST_API_KEY` (namespace `mr-do-player`, created manually, never in git; how to: [mr-do-soloist README](../mr-do-soloist/README.md#soloist-api-key)) |
| `SOLOIST_DEVICE_NAME` | `mrSpot` |
| `SOLOIST_CACHE_SIZE_MB` / `SOLOIST_INITIAL_VOLUME` / `SAMPLE_RATE` | `300` / `100` / `44100` (= snapserver `sampleformat`; Spotify's native rate, no resampling) |
| `/data` | PVC `mr-do-player-pvc-data`, subPath `soloist` (NFS `mr0.local:/srv/nfs4/homes/mr/media/soloist`): Soloist binary + stored login; shared with `mr-do-soloist-fetch` |
| `/cache` | emptyDir, `sizeLimit: 512Mi` |
| `/run/soloist` | emptyDir `medium: Memory`, `sizeLimit: 16Mi` |
| Probes | startup: `healthcheck.sh` retried every 0.5 s inside the probe for up to 8 s (`periodSeconds: 10`, `timeoutSeconds: 9`, `failureThreshold: 36` = 6 min). Waiting inside the probe avoids an `Unhealthy` Warning event while PulseAudio and Soloist start; the short period keeps pod start fast (the first probe waits one period). Liveness: `healthcheck.sh` every 30 s |
| Resources | requests `50m` / `96Mi`, limits `1000m` / `512Mi` |
| Security | uid/gid `1000`, read-only root, `drop: ALL`, no privilege escalation |
| Network | `hostNetwork: true` (mDNS 5353/UDP + Soloist's ZeroConf HTTP port); no Service port |

| mr-do-soloist-fetch setting | Value |
|---|---|
| `SOLOIST_UPDATE_INTERVAL` | `86400` (check the CDN once a day; download only when newer) |
| `/data` | same PVC/subPath as `mr-do-soloist` |
| `/tmp` | emptyDir `medium: Memory`, `sizeLimit: 1Mi` (ready file) |
| Probes | startup: `test -f /tmp/soloist-fetch.ready` every 2 s, `failureThreshold: 180` (6 min; the first download is ~13 MB) |
| Resources | requests `5m` / `16Mi`, limits `500m` / `64Mi` |
| Security | uid/gid `1000`, read-only root, `drop: ALL`, no privilege escalation |
| Outbound | HTTPS `soloist-builds.spotifycdn.com` |

docker compose (`docker/docker-compose.yml`): set `SOLOIST_API_KEY` in `docker/.env`; the Soloist
data is kept in `docker/config/soloist/`. Services `mr-do-soloist-fetch` (image `riemerk/mr-do-soloist:latest-fetch`,
healthy after the first check) → `mr-do-soloist` → `mr-do-snapserver`.

Expected log line at startup: `[Error] (AsioStream) Error reading message in stream 'upnp': End of file`,
logged once. The UPnP FIFO (`/tmp/music/upnpfifo`) has no writer until gmediarender starts playing,
so snapserver reads EOF once and then waits for data. This is upstream snapserver behaviour, not a fault.
   
### Credits:

[Snapcast](https://github.com/badaix/snapcast) from badaix
