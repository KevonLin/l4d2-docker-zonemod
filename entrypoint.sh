#!/bin/bash
set -e

: "${TZ:=UTC}"
: "${BASE_DIR:=/home/louis}"
: "${INSTALL_DIR:=l4d2}"
: "${GAME_NAME:=left4dead2}"
: "${GAME_ID:=222860}"
: "${INSTALL_PLUGINS:=true}"

# The image is deliberately timezone-agnostic: the timezone is applied at
# container startup from the live environment ("TZ" env var). Setting it
# requires root, so the root branch below updates /etc/timezone and
# /etc/localtime, then drops to the unprivileged "louis" user (via gosu) and
# re-enters this script to do the actual install/launch work.
if [ "$(id -u)" -eq 0 ]; then
    ZONEINFO="/usr/share/zoneinfo/${TZ}"
    if [ -e "$ZONEINFO" ]; then
        echo "${TZ}" > /etc/timezone
        ln -sf "$ZONEINFO" /etc/localtime
        echo ">>> Timezone set to ${TZ}"
    else
        echo "Warning: timezone '${TZ}' not found in /usr/share/zoneinfo. Keeping default." >&2
    fi

    echo ">>> Switching to unprivileged user 'louis'."
    exec gosu louis "$0" "$@"
fi

GAME_ROOT="${BASE_DIR}/${INSTALL_DIR}"
PLUGIN_DIR="${GAME_ROOT}/${GAME_NAME}"

export BASE_DIR INSTALL_DIR GAME_NAME GAME_ID INSTALL_PLUGINS GAME_ROOT PLUGIN_DIR TZ

: "${DEFAULT_MAP:=c2m1_highway}"
: "${PORT:=27015}"
: "${IP:=0.0.0.0}"
: "${CLOCK_CORRECTION_MSECS:=25}"
: "${TIMEOUT:=10}"
: "${TICKRATE:=100}"
: "${EXEC_CFG:=server.cfg}"

./install-plugins.sh

./as-user.sh

cd "${GAME_ROOT}" || exit 50

if [ $# -gt 0 ]; then
    exec ./srcds_run "$@"
else
    STARTUP=("./srcds_run")
    STARTUP+=("-game ${GAME_NAME}")
    STARTUP+=("-ip ${IP}")
    STARTUP+=("-port ${PORT}")
    STARTUP+=("+sv_clockcorrection_msecs ${CLOCK_CORRECTION_MSECS}")
    STARTUP+=("-timeout ${TIMEOUT}")
    STARTUP+=("-tickrate ${TICKRATE}")
    STARTUP+=("+map ${DEFAULT_MAP}")
    STARTUP+=("+exec ${EXEC_CFG}")
    
    if [ -n "${MAXPLAYERS}" ] && [ "${MAXPLAYERS}" -gt 0 ]; then
        STARTUP+=("-maxplayers ${MAXPLAYERS}")
    fi
    
    exec "${STARTUP[@]}"
fi