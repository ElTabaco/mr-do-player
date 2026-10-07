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
| `[server] mdns_enabled` | `false` | No avahi-daemon in the container or on the node. Without this snapserver logs `[Error] (Avahi) Failed to create client: Daemon not running`. |
| startup/liveness probe | `tcpSocket` port `1780` (HTTP) | A bare TCP connect/close on the control port `1705` makes snapserver log `[Error] (ControlSessionTCP) Error while reading from control socket: End of file` every probe. |
| readiness probe | `tcpSocket` port `1780` | unchanged |
| UPnP stream `upnp` | `pipe:///tmp/music/upnpfifo?name=upnp&sampleformat=44100:16:2` | Written by gmediarender through the ALSA `rate` + `file` plugins (`mr-do-asound-cfgmap`, 44100 Hz S16_LE). Files at other rates are resampled by GStreamer `audioresample quality=10` inside mr-do-upnp-c (`SAMPLE_RATE=44100`, `RESAMPLE_QUALITY=10`); measured 79 dB SNR at 15 kHz for 48 kHz files, ALSA's linear converter gave 13 dB. |
| `sampleformat` | `44100:16:2` | Most music files are 44.1 kHz: ALSA (UPnP, 44.1 kHz files) passes them through bit-exact. Files with other rates (e.g. 48/96 kHz) are resampled by GStreamer `audioresample` (windowed sinc) in mr-do-upnp-c. Clients resample (soxr) only if their DAC does not support 44.1 kHz. With 48000 every CD-quality file was resampled. `SAMPLE_RATE` of mr-do-upnp and `rate` in `asound.conf` must match. |
| `codec` | `flac` | lossless transport |
| `buffer` | `1500` ms | end-to-end latency; default 1000. More headroom against Wi-Fi dropouts on the clients (Pi Zero/armv6l). |

## Kubernetes: pod layout (`kubernetes/deployment.yml`)

| Container | Kind | Image | Purpose |
|---|---|---|---|
| `init-fifo` | init container | `busybox:1.36` | creates `/tmp/music/upnpfifo` (mode 0666) |
| `mr-do-upnp` | container | `riemerk/mr-do-upnp-c:2acefbd` | gmediarender UPnP renderer `mrCast` → GStreamer resampler (44.1 kHz) → ALSA file plugin → `upnpfifo` |
| `mr-do-snapserver` | container | `riemerk/mr-do-snapserver:<snapserver>-<snapcast commit>` | reads `upnpfifo`, serves snapclients and snapweb |

docker compose (`docker/docker-compose.yml`): services `init-fifo` → `mr-do-upnp` and
`mr-do-snapserver`, all with host networking. Snapserver settings are kept in
`docker/config/snapserver/`.

Expected log line at startup: `[Error] (AsioStream) Error reading message in stream 'upnp': End of file`,
logged once. The UPnP FIFO (`/tmp/music/upnpfifo`) has no writer until gmediarender starts playing,
so snapserver reads EOF once and then waits for data. This is upstream snapserver behaviour, not a fault.
   
### Credits:

[Snapcast](https://github.com/badaix/snapcast) from badaix
