#!/bin/bash
set -e

: "${BASE_DIR:=/home/louis}"
: "${INSTALL_DIR:=l4d2}"
: "${GAME_NAME:=left4dead2}"
: "${GAME_ID:=222860}"
: "${INSTALL_PLUGINS:=true}"

GAME_ROOT="${BASE_DIR}/${INSTALL_DIR}"
PLUGIN_DIR="${GAME_ROOT}/${GAME_NAME}"

export BASE_DIR INSTALL_DIR GAME_NAME GAME_ID INSTALL_PLUGINS GAME_ROOT PLUGIN_DIR

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