#!/bin/bash
set -e

# Runtime-configurable values (override via environment / compose).
: "${GAME_ID:=222860}"
: "${INSTALL_DIR:=l4d2}"
export GAME_ID INSTALL_DIR

install_plugins_if_needed() {
    if [ ! -d /addons/sourcemod ]; then
        echo "Plugins not found. Installing L4D2 Competitive Rework plugins..."
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"
        git clone https://github.com/SirPlease/L4D2-Competitive-Rework.git
        cp -r L4D2-Competitive-Rework/addons/* /addons/
        cp -r L4D2-Competitive-Rework/cfg/* /cfg/
        cp -r L4D2-Competitive-Rework/scripts/* /scripts/
        cd /
        rm -rf "$TEMP_DIR"
        chown -R louis:louis /addons /cfg /scripts
        echo "Plugins installed successfully."
    else
        echo "Plugins already present, skipping installation."
    fi
}

if [ "$(id -u)" -eq 0 ]; then
    if [ -n "$TZ" ]; then
        ZONEINFO="/usr/share/zoneinfo/$TZ"
        if [ -f "$ZONEINFO" ]; then
            ln -sf "$ZONEINFO" /etc/localtime
            echo "$TZ" > /etc/timezone
            dpkg-reconfigure -f noninteractive tzdata 2>/dev/null || true
        else
            echo "Warning: Timezone $TZ not found in /usr/share/zoneinfo. Keeping default." >&2
        fi
    else
        echo "No TZ environment variable set. Using container default timezone." >&2
    fi

    if [ -n "$SSH_PUBLIC_KEY" ]; then
        echo "Setting up SSH public key for user louis..."
        mkdir -p /home/louis/.ssh
        chmod 700 /home/louis/.ssh
        echo "$SSH_PUBLIC_KEY" >> /home/louis/.ssh/authorized_keys
        chmod 600 /home/louis/.ssh/authorized_keys
        chown -R louis:louis /home/louis/.ssh
    fi

    # Ensure the game install directory exists and is writable by the unprivileged
    # "louis" user. This matters whether the directory is a named volume or a
    # bind mount (for a bind mount this also chowns the host directory to UID 1000).
    mkdir -p "/home/louis/${INSTALL_DIR}"
    chown louis:louis "/home/louis/${INSTALL_DIR}"

    install_plugins_if_needed

    echo "Starting SSH daemon..."
    /usr/sbin/sshd -D &

    exec gosu louis "$0" "$@"
fi

: "${DEFAULT_MAP:=c2m1_highway}"
: "${PORT:=27015}"
: "${IP:=0.0.0.0}"
: "${CLOCK_CORRECTION_MSECS:=25}"
: "${TIMEOUT:=10}"
: "${TICKRATE:=100}"
: "${EXEC_CFG:=server.cfg}"

# Install/update the game at container startup (it is no longer baked into the image).
# The game is stored under /home/louis/${INSTALL_DIR}, which should be mounted as a
# volume/bind mount so it survives container recreation.
./as-user.sh

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
