#!/bin/bash
set -euo pipefail

# restart.sh — restarts the L4D2 dedicated server.
#
# Works together with the entrypoint supervisor: it records a "restart"
# request in ${HOME}/.l4d2/srcds.request and then stops the server with
# stop.sh. As soon as the process exits the supervisor calls start.sh again —
# all inside the same container, so no container recreation is needed.
#
# If the server is not currently running, start.sh is invoked directly.

: "${HOME:=/home/louis}"

RUNTIME_DIR="${HOME}/.l4d2"
PID_FILE="${RUNTIME_DIR}/srcds.pid"
REQUEST_FILE="${RUNTIME_DIR}/srcds.request"

mkdir -p "${RUNTIME_DIR}"

RUNNING=0
if [ -f "${PID_FILE}" ]; then
    RPID=$(cat "${PID_FILE}")
    if [ -n "${RPID}" ] && kill -0 "${RPID}" 2>/dev/null; then
        RUNNING=1
    fi
fi

echo ">>> Restarting L4D2 server..."

if [ "${RUNNING}" -eq 1 ]; then
    # stop.sh does the graceful shutdown; the supervisor restarts the server.
    echo "restart" > "${REQUEST_FILE}"
    /usr/local/bin/stop.sh
    echo ">>> Server stopped. The supervisor will start it again."
else
    echo ">>> Server is not running — starting it now."
    rm -f "${REQUEST_FILE}"
    /usr/local/bin/start.sh
fi