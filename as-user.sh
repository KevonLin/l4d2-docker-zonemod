#!/bin/bash
# Install steamcmd
mkdir -p .steam/sdk32/
ln -s ~/linux32/steamclient.so ~/.steam/sdk32/steamclient.so
curl https://media.steampowered.com/installer/steamcmd_linux.tar.gz | tar -xzvf -

# Convenient symlinks for mount points
if [ "${INSTALL_DIR}" = "l4d2" ]; then
    GAME_DIR="${INSTALL_DIR}/left4dead2"
else
    exit 100
fi

mkdir -p ./"${GAME_DIR}"
ln -s /addons         "./${GAME_DIR}/addons"
ln -s /cfg            "./${GAME_DIR}/cfg"
ln -s /scripts        "./${GAME_DIR}/scripts"
ln -s /motd/myhost.txt  "./${GAME_DIR}/myhost.txt"
ln -s /motd/mymotd.txt  "./${GAME_DIR}/mymotd.txt"

# Install game
echo """force_install_dir "/home/louis/${INSTALL_DIR}"
login anonymous
app_update ${GAME_ID}
quit""" > update.txt
if [ "${INSTALL_DIR}" = "l4d2" ]; then
  ./steamcmd.sh +force_install_dir "/home/louis/${INSTALL_DIR}" +login anonymous +@sSteamCmdForcePlatformType windows +app_update ${GAME_ID} validate +quit && \
  ./steamcmd.sh +force_install_dir "/home/louis/${INSTALL_DIR}" +login anonymous +@sSteamCmdForcePlatformType linux +app_update ${GAME_ID} validate +quit
else
  ./steamcmd.sh +runscript update.txt
fi