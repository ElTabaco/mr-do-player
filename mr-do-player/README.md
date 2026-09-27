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
| `[server] mdns_enabled` | `false` | No avahi-daemon in the container or on the node. Without this snapserver logs `[Error] (Avahi) Failed to create client: Daemon not running`. Spotify Connect discovery uses librespot's built-in libmdns and is not affected. |
| startup/liveness probe | `tcpSocket` port `1780` (HTTP) | A bare TCP connect/close on the control port `1705` makes snapserver log `[Error] (ControlSessionTCP) Error while reading from control socket: End of file` every probe. |
| readiness probe | `tcpSocket` port `1780` | unchanged |

Expected log line at startup: `[Error] (AsioStream) Error reading message in stream 'upnp': End of file`,
logged once. The UPnP FIFO (`/tmp/music/upnpfifo`) has no writer until gmediarender starts playing,
so snapserver reads EOF once and then waits for data. This is upstream snapserver behaviour, not a fault.
   
### Credits:

[Snapcast](https://github.com/badaix/snapcast) from badaix
