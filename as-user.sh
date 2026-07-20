#!/bin/bash
# Runtime game installer.
# This script is executed at CONTAINER STARTUP (not baked into the image).
# It is invoked by entrypoint.sh as the unprivileged "louis" user.
# It is safe to run on every startup: the heavy first-install only happens
# when the game is not already present, otherwise it just updates/validates.
set -euo pipefail

cd /home/louis

GAME_ID="${GAME_ID:-222860}"
INSTALL_DIR="${INSTALL_DIR:-l4d2}"

mkdir -p .steam/sdk32
ln -sf ~/linux32/steamclient.so .steam/sdk32/steamclient.so

if [ ! -f steamcmd.sh ]; then
    echo ">>> Downloading steamcmd..."
    curl -sSL https://media.steampowered.com/installer/steamcmd_linux.tar.gz | tar -xzvf -
fi

echo ">>> Initializing steamcmd..."
if ! ./steamcmd.sh +quit; then
    echo "ERROR: steamcmd initialization failed." >&2
    exit 1
fi

GAME_DIR="${INSTALL_DIR}/left4dead2"
mkdir -p "${GAME_DIR}"

echo ">>> Creating symlinks for mount points..."
ln -sf /addons         "${GAME_DIR}/addons"
ln -sf /cfg            "${GAME_DIR}/cfg"
ln -sf /scripts        "${GAME_DIR}/scripts"
ln -sf /motd/myhost.txt  "${GAME_DIR}/myhost.txt"
ln -sf /motd/mymotd.txt  "${GAME_DIR}/mymotd.txt"

echo """force_install_dir "/home/louis/${INSTALL_DIR}"
login anonymous
app_update ${GAME_ID}
quit""" > update.txt

check_game_installed() {
    if [ ! -f "${INSTALL_DIR}/srcds_run" ]; then
        echo "ERROR: Game installation failed - srcds_run not found in ${INSTALL_DIR}." >&2
        exit 1
    fi
}

if [ ! -f "${INSTALL_DIR}/srcds_run" ]; then
    if [ "${INSTALL_DIR}" = "l4d2" ]; then
        echo """force_install_dir "/home/louis/${INSTALL_DIR}"
        login anonymous
        @sSteamCmdForcePlatformType windows
        app_update ${GAME_ID}
        @sSteamCmdForcePlatformType linux
        app_update ${GAME_ID} validate
        quit""" > first-install-l4d2.txt

        echo ">>> Installing L4D2 (first install, may take a while)..."
        if ! ./steamcmd.sh +runscript first-install-l4d2.txt; then
            echo "ERROR: steamcmd failed to execute the install script." >&2
            exit 1
        fi
    else
        echo ">>> Installing game (AppID: ${GAME_ID})..."
        if ! ./steamcmd.sh +runscript update.txt; then
            echo "ERROR: steamcmd failed to execute the install script." >&2
            exit 1
        fi
    fi
    check_game_installed
else
    echo ">>> Game already installed, updating/validating..."
    if ! ./steamcmd.sh +runscript update.txt; then
        echo "ERROR: steamcmd failed to execute the update script." >&2
        exit 1
    fi
fi

echo ">>> Game preparation completed successfully."
