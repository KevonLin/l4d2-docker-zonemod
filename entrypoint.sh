#!/bin/bash
set -e

: "${DEFAULT_MAP:=c2m1_highway}"
: "${PORT:=27015}"
: "${IP:=0.0.0.0}"
: "${CLOCK_CORRECTION_MSECS:=25}"
: "${TIMEOUT:=10}"
: "${TICKRATE:=100}"
: "${EXEC_CFG:=server.cfg}"

GAME_ID=222860
INSTALL_DIR="l4d2"

./steamcmd.sh +runscript update.txt

cd "${INSTALL_DIR}" || exit 50

if [ "${INSTALL_DIR}" = "l4d2" ]; then
    GAME_DIR="left4dead2"
else
    exit 100
fi

if [ $# -gt 0 ]; then
    ./srcds_run "$@"
else
    STARTUP=("./srcds_run")
    
    STARTUP+=("-game ${GAME_DIR}")
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
    
    exec ${STARTUP[*]}
fi