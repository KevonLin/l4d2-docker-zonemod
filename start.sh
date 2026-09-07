#!/bin/bash
set -euo pipefail

# start.sh — starts the L4D2 dedicated server as a supervised daemon.
#
# Installed at /usr/local/bin/start.sh inside the image; invoked by
# entrypoint.sh, stop.sh and restart.sh. The server is started in its own
# session / process group (setsid) so stop.sh can terminate the whole process
# tree and so it keeps running after the calling shell exits (docker exec,
# ssh ...).
#
# State lives in ${HOME}/.l4d2/ (inside the persisted volume):
#   srcds.pid     PID of the running server
#   srcds.log     console output (streamed to `docker logs` by entrypoint.sh)
#   srcds.request control file used by stop.sh/restart.sh ("stop" | "restart")

: "${HOME:=/home/louis}"
: "${INSTALL_DIR:=l4d2}"
: "${GAME_NAME:=left4dead2}"

: "${DEFAULT_MAP:=c2m1_highway}"
: "${PORT:=27015}"
: "${IP:=0.0.0.0}"
: "${CLOCK_CORRECTION_MSECS:=20}"
: "${TIMEOUT:=10}"
: "${TICKRATE:=100}"
: "${EXEC_CFG:=server.cfg}"

GAME_ROOT="${HOME}/${INSTALL_DIR}"
RUNTIME_DIR="${HOME}/.l4d2"
PID_FILE="${RUNTIME_DIR}/srcds.pid"
LOG_FILE="${RUNTIME_DIR}/srcds.log"

mkdir -p "${RUNTIME_DIR}"

# A PID is only "ours" if it is alive AND actually runs srcds. After a
# container recreation the PID file can point at an unrelated process, so the
# cmdline check is mandatory.
is_srcds_pid() {
    local pid="$1"
    [ -r "/proc/${pid}/cmdline" ] || return 1
    grep -aq 'srcds' "/proc/${pid}/cmdline" 2>/dev/null
}

if [ -f "${PID_FILE}" ]; then
    OLD_PID=$(cat "${PID_FILE}")
    if [ -n "${OLD_PID}" ] && is_srcds_pid "${OLD_PID}" && kill -0 "${OLD_PID}" 2>/dev/null; then
        echo ">>> srcds is already running (PID ${OLD_PID}). Use stop.sh / restart.sh."
        exit 0
    fi
    echo ">>> Removing stale PID file (${OLD_PID:-none})."
    rm -f "${PID_FILE}"
fi

cd "${GAME_ROOT}" || {
    echo "ERROR: ${GAME_ROOT} does not exist. Check HOME/INSTALL_DIR." >&2
    exit 50
}

STARTUP=(./srcds_run)
if [ $# -gt 0 ]; then
    # Explicit arguments passed to the container win over the defaults.
    STARTUP+=("$@")
else
    STARTUP+=("-game ${GAME_NAME}")
    STARTUP+=("-ip ${IP}")
    STARTUP+=("-port ${PORT}")
    STARTUP+=("+sv_clockcorrection_msecs ${CLOCK_CORRECTION_MSECS}")
    STARTUP+=("-timeout ${TIMEOUT}")
    STARTUP+=("-tickrate ${TICKRATE}")
    STARTUP+=("+map ${DEFAULT_MAP}")
    STARTUP+=("+exec ${EXEC_CFG}")
    if [ -n "${MAXPLAYERS:-}" ] && [ "${MAXPLAYERS}" -gt 0 ]; then
        STARTUP+=("-maxplayers ${MAXPLAYERS}")
    fi
fi

echo ">>> Starting L4D2 server..."
echo ">>> Command: ${STARTUP[*]}"
nohup setsid "${STARTUP[@]}" >>"${LOG_FILE}" 2>&1 &
SRCDS_PID=$!

# setsid may have to fork when the calling shell already made the background
# job a process-group leader (interactive shells). Resolve the real server PID.
if ! is_srcds_pid "${SRCDS_PID}" || ! kill -0 "${SRCDS_PID}" 2>/dev/null; then
    sleep 1
    SRCDS_PID=$(pgrep -f 'srcds_(run|linux)' 2>/dev/null | head -n1) || true
fi

echo "${SRCDS_PID}" > "${PID_FILE}"
echo ">>> L4D2 server started (PID ${SRCDS_PID}). Console log: ${LOG_FILE}"
exit 0