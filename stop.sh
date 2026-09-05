#!/bin/bash
set -euo pipefail

# stop.sh — gracefully stops the L4D2 dedicated server.
#
# Sends SIGTERM to the server (whole process group, since start.sh launches it
# with setsid the group id equals the recorded PID), waits up to STOP_TIMEOUT
# seconds, then escalates to SIGKILL.
#
# Before killing anything it records a "stop" request in
# ${HOME}/.l4d2/srcds.request so the entrypoint supervisor knows this was an
# intentional stop and shuts the container down instead of treating it as a
# crash and restarting the server. restart.sh records "restart" first; that
# request is never overwritten here.

: "${HOME:=/home/louis}"
: "${STOP_TIMEOUT:=30}"

RUNTIME_DIR="${HOME}/.l4d2"
PID_FILE="${RUNTIME_DIR}/srcds.pid"
REQUEST_FILE="${RUNTIME_DIR}/srcds.request"

mkdir -p "${RUNTIME_DIR}"

# A PID only counts as "ours" when it is alive and actually runs srcds
# (guards against a stale PID file after a container recreation).
is_srcds_pid() {
    local pid="$1"
    [ -r "/proc/${pid}/cmdline" ] || return 1
    grep -aq 'srcds' "/proc/${pid}/cmdline" 2>/dev/null
}

find_srcds_pid() {
    if [ -f "${PID_FILE}" ]; then
        local pid
        pid=$(cat "${PID_FILE}")
        if [ -n "${pid}" ] && is_srcds_pid "${pid}" && kill -0 "${pid}" 2>/dev/null; then
            echo "${pid}"
            return 0
        fi
        rm -f "${PID_FILE}"
    fi
    # Fallback: scan for the game process. The pattern cannot match this
    # script itself.
    local fallback
    fallback=$(pgrep -f 'srcds_(run|linux)' 2>/dev/null | head -n1) || true
    if [ -n "${fallback}" ]; then
        echo "${fallback}"
        return 0
    fi
    return 1
}

# Record the operator's intent (unless restart.sh asked for a restart first).
CURRENT_REQUEST=""
if [ -f "${REQUEST_FILE}" ]; then
    CURRENT_REQUEST=$(cat "${REQUEST_FILE}") || true
fi
if [ "${CURRENT_REQUEST}" != "restart" ]; then
    echo "stop" > "${REQUEST_FILE}"
fi

SRCDS_PID=""
if ! SRCDS_PID=$(find_srcds_pid); then
    echo ">>> srcds is not running."
    exit 0
fi

# Drop the PID file *before* killing. Once the process has exited the
# supervisor may immediately start a fresh server (restart.sh), and it must
# never pick up an entry that is about to go stale mid-shutdown.
rm -f "${PID_FILE}"

echo ">>> Stopping L4D2 server (PID ${SRCDS_PID}, timeout ${STOP_TIMEOUT}s)..."
kill -TERM -- "-${SRCDS_PID}" 2>/dev/null || true
kill -TERM "${SRCDS_PID}" 2>/dev/null || true

WAITED=0
while kill -0 "${SRCDS_PID}" 2>/dev/null; do
    if [ "${WAITED}" -ge "${STOP_TIMEOUT}" ]; then
        echo ">>> srcds did not exit after ${STOP_TIMEOUT}s; sending SIGKILL."
        kill -KILL -- "-${SRCDS_PID}" 2>/dev/null || true
        kill -KILL "${SRCDS_PID}" 2>/dev/null || true
        break
    fi
    sleep 1
    WAITED=$((WAITED + 1))
done

echo ">>> L4D2 server stopped."