#!/bin/bash
set -euo pipefail

cd /home/louis

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

INSTALL_DIR="${INSTALL_DIR:-l4d2}"
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
        echo "ERROR: steamcmd failed to download/update the game (AppID: ${GAME_ID})." >&2
        exit 1
    fi
else
    echo ">>> Installing/updating game (AppID: ${GAME_ID})..."
    if ! ./steamcmd.sh +runscript update.txt; then
        echo "ERROR: steamcmd failed to download/update the game (AppID: ${GAME_ID})." >&2
        exit 1
    fi
fi

echo ">>> Game installation completed successfully."