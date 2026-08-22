#!/bin/bash
set -euo pipefail

: "${HOME?}" "${INSTALL_DIR?}" "${GAME_ID?}" "${GAME_ROOT?}" "${SSH_PUBLIC_KEY?}"

if [ -n "${SSH_PUBLIC_KEY}" ]; then
    mkdir -p "${HOME}/.ssh"
    echo "${SSH_PUBLIC_KEY}" > "${HOME}/.ssh/authorized_keys"
    chmod 700 "${HOME}/.ssh"
    chmod 600 "${HOME}/.ssh/authorized_keys"
fi

mkdir -p "/tmp/dumps"

mkdir -p "${GAME_ROOT}"

cd "${HOME}"

mkdir -p ".steam/sdk32"

if [ -f "./linux32/steamclient.so" ]; then
    ln -sf "./linux32/steamclient.so" "${HOME}/.steam/sdk32/steamclient.so"
fi

if [ ! -f steamcmd.sh ]; then
    echo ">>> Downloading steamcmd..."
    curl -sSL https://media.steampowered.com/installer/steamcmd_linux.tar.gz | tar -xzvf -
fi

echo ">>> Initializing steamcmd..."
if ! ./steamcmd.sh +quit; then
    echo "ERROR: steamcmd initialization failed." >&2
    exit 1
fi

echo """force_install_dir "${GAME_ROOT}"
login anonymous
app_update ${GAME_ID}
quit""" > update.txt

check_game_installed() {
    if [ ! -f "${GAME_ROOT}/srcds_run" ]; then
        echo "ERROR: Game installation failed - srcds_run not found in ${GAME_ROOT}." >&2
        exit 1
    fi
}

if [ ! -f "${GAME_ROOT}/srcds_run" ]; then
    if [ "${GAME_NAME}" = "left4dead2" ]; then
        echo """force_install_dir "${GAME_ROOT}"
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