#!/bin/sh
# Startup/liveness check: PulseAudio answers (pipe sink holds the FIFO open)
# and the Soloist daemon is running.
set -eu
SOLOIST_DATA_DIR="${SOLOIST_DATA_DIR:-/data}"
SOLOIST_BIN_DIR="${SOLOIST_BIN_DIR:-${SOLOIST_DATA_DIR}/bin}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/soloist/xdg}"
export PULSE_SERVER="${PULSE_SERVER:-unix:${XDG_RUNTIME_DIR}/pulse-native}"
soloist="${SOLOIST_BIN_DIR}/soloist"
# same build as the running daemon (hard link made by entrypoint.sh), if available
[ -x "${soloist}.running" ] && soloist="${soloist}.running"
pactl list short sinks | grep -q snapfifo
"${soloist}" ctl status -D "${SOLOIST_DATA_DIR}" | grep -q "running"
