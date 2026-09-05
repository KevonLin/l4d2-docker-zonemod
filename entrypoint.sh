#!/bin/bash
set -e

: "${TZ:=UTC}"
: "${HOME:=/home/louis}"
: "${INSTALL_DIR:=l4d2}"
: "${GAME_NAME:=left4dead2}"
: "${GAME_ID:=222860}"
: "${INSTALL_PLUGINS:=true}"
: "${SSH_PORT:=22}"

# The image is deliberately timezone-agnostic: the timezone is applied at
# container startup from the live environment ("TZ" env var). Setting it
# requires root, so the root branch below updates /etc/timezone and
# /etc/localtime, configures and starts the SSH server, then drops to the
# unprivileged "louis" user (via gosu) and re-enters this script to do the
# actual install/launch work.
if [ "$(id -u)" -eq 0 ]; then
    ZONEINFO="/usr/share/zoneinfo/${TZ}"
    if [ -e "$ZONEINFO" ]; then
        echo "${TZ}" > /etc/timezone
        ln -sf "$ZONEINFO" /etc/localtime
        echo ">>> Timezone set to ${TZ}"
    else
        echo "Warning: timezone '${TZ}' not found in /usr/share/zoneinfo. Keeping default." >&2
    fi

    # SSH server: apply the SSH_PORT from the environment to sshd_config and
    # (re)start sshd (run as root; the authorized_keys for 'louis' are written
    # by as-user.sh when the unprivileged user runs).
    if [ -n "${SSH_PORT}" ]; then
        # Clear any existing commented/active Port directives, then append the
        # desired one. sshd uses the last value, so appending wins.
        sed -ri 's/^[[:space:]]*#?[[:space:]]*Port[[:space:]]+[0-9]+.*$//' /etc/ssh/sshd_config
        echo "Port ${SSH_PORT}" >> /etc/ssh/sshd_config
        echo ">>> SSH server port set to ${SSH_PORT}"
    fi

    mkdir -p /run/sshd

    # A container boots into a clean slate, so on a normal start sshd is not
    # running yet and simply needs launching. If this script is ever re-run
    # while a stale daemon is still up, stop it first so the (possibly changed)
    # Port directive is honoured. pkill exits 1 when nothing matches — that is
    # expected and harmless.
    pkill -x sshd 2>/dev/null || true
    /usr/sbin/sshd
    sleep 1
    if ! pgrep -x sshd >/dev/null 2>&1; then
        echo "ERROR: sshd failed to start. Check /var/log/auth.log." >&2
        exit 1
    fi
    echo ">>> SSH server started (port ${SSH_PORT})."

    echo ">>> Switching to unprivileged user 'louis'."
    exec gosu louis "$0" "$@"
fi

GAME_ROOT="${HOME}/${INSTALL_DIR}"
PLUGIN_DIR="${GAME_ROOT}/${GAME_NAME}"

export HOME INSTALL_DIR GAME_NAME GAME_ID INSTALL_PLUGINS GAME_ROOT PLUGIN_DIR TZ

# Everything below runs as the unprivileged "louis" user, after the plugin
# installer and the game installer have finished. install-plugins.sh and
# as-user.sh are idempotent (see each script) and run on every container start.
/usr/local/bin/install-plugins.sh
/usr/local/bin/as-user.sh

# Start the dedicated server as a supervised background daemon and keep the
# container alive. start.sh launches srcds (PID file + console log live in
# ${HOME}/.l4d2/); stop.sh / restart.sh talk to this loop through the
# ${HOME}/.l4d2/srcds.request control file ("stop" or "restart").
RUNTIME_DIR="${HOME}/.l4d2"
PID_FILE="${RUNTIME_DIR}/srcds.pid"
LOG_FILE="${RUNTIME_DIR}/srcds.log"
REQUEST_FILE="${RUNTIME_DIR}/srcds.request"

mkdir -p "${RUNTIME_DIR}"
rm -f "${REQUEST_FILE}"    # clear a stale request from a previous container run
touch "${LOG_FILE}"

/usr/local/bin/start.sh "$@"
SRCDS_PID=$(cat "${PID_FILE}" 2>/dev/null || true)

if [ -z "${SRCDS_PID}" ] || ! kill -0 "${SRCDS_PID}" 2>/dev/null; then
    echo "ERROR: srcds failed to start. See ${LOG_FILE}" >&2
    exit 1
fi

# Stream the server console to stdout so `docker logs` keeps working.
tail -f "${LOG_FILE}" 2>/dev/null &
TAIL_PID=$!

# Forward docker stop / docker compose down to the server so it can shut down
# gracefully instead of being killed outright.
forward_signal() {
    echo ">>> Caught SIGTERM/SIGINT; stopping the server gracefully..."
    kill -TERM -- "-${SRCDS_PID}" 2>/dev/null || true
    kill -TERM "${SRCDS_PID}" 2>/dev/null || true
    for _ in $(seq 1 15); do
        if ! kill -0 "${SRCDS_PID}" 2>/dev/null; then
            break
        fi
        sleep 1
    done
    echo ">>> Container stopping."
    exit 0
}
trap forward_signal TERM INT

# apply_request returns 0 when nothing was pending (or "stop" already exited
# the script) and 1 when a "restart" request was applied.
apply_request() {
    if [ ! -f "${REQUEST_FILE}" ]; then
        return 0
    fi
    REQUEST=$(cat "${REQUEST_FILE}")
    rm -f "${REQUEST_FILE}"
    case "${REQUEST}" in
        stop)
            echo ">>> stop.sh requested; shutting down the container."
            exit 0
            ;;
        restart)
            echo ">>> restart.sh requested; starting the server again."
            /usr/local/bin/start.sh
            SRCDS_PID=$(cat "${PID_FILE}" 2>/dev/null || true)
            LAST_START=$(date +%s)
            return 1
            ;;
    esac
    return 0
}

# Supervisor loop:
#   - while the server is up, just wait;
#   - on server exit apply srcds.request:
#       "restart" -> start.sh again in the SAME container,
#       "stop"    -> exit the container cleanly,
#       none      -> unexpected crash: back off and restart, give up after 4
#                    fast crashes so a broken config cannot loop forever.
CONSECUTIVE_CRASHES=0
LAST_START=$(date +%s)

while true; do
    while kill -0 "${SRCDS_PID}" 2>/dev/null; do
        sleep 2
    done

    if apply_request; then
        :
    else
        continue
    fi

    # Unexpected exit — restart with a short backoff.
    UPTIME=$(( $(date +%s) - LAST_START ))
    if [ "${UPTIME}" -ge 60 ]; then
        CONSECUTIVE_CRASHES=0
    fi
    CONSECUTIVE_CRASHES=$((CONSECUTIVE_CRASHES + 1))
    if [ "${CONSECUTIVE_CRASHES}" -ge 5 ]; then
        echo ">>> srcds kept crashing; giving up. The container will exit, the Docker restart policy may bring it back." >&2
        exit 1
    fi
    echo ">>> srcds exited unexpectedly (crash #${CONSECUTIVE_CRASHES}); restarting in 5s..."

    # Watch for an operator request arriving during the backoff window.
    for _ in $(seq 1 5); do
        sleep 1
        if [ -f "${REQUEST_FILE}" ]; then
            break
        fi
    done
    if apply_request; then
        :
    else
        continue
    fi

    /usr/local/bin/start.sh
    SRCDS_PID=$(cat "${PID_FILE}" 2>/dev/null || true)
    LAST_START=$(date +%s)
done