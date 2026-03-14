#!/bin/bash
set -e  # 仍然开启，但 Windows 命令已用 || 处理

cd /home/louis

mkdir -p .steam/sdk32
ln -sf ~/linux32/steamclient.so .steam/sdk32/steamclient.so

# 下载 steamcmd（如果尚未存在）
if [ ! -f steamcmd.sh ]; then
    echo ">>> Downloading steamcmd..."
    curl -sSL https://media.steampowered.com/installer/steamcmd_linux.tar.gz | tar -xzvf -
fi

# 初始化 steamcmd（更新自身）
echo ">>> Initializing steamcmd..."
./steamcmd.sh +quit

# 设置安装目录
INSTALL_DIR="${INSTALL_DIR:-l4d2}"
GAME_DIR="${INSTALL_DIR}/left4dead2"
mkdir -p "${GAME_DIR}"

# 创建软链接（挂载点）
echo ">>> Creating symlinks for mount points..."
ln -sf /addons         "${GAME_DIR}/addons"
ln -sf /cfg            "${GAME_DIR}/cfg"
ln -sf /scripts        "${GAME_DIR}/scripts"
ln -sf /motd/myhost.txt  "${GAME_DIR}/myhost.txt"
ln -sf /motd/mymotd.txt  "${GAME_DIR}/mymotd.txt"

# Install game
echo """force_install_dir "/home/louis/${INSTALL_DIR}"
login anonymous
app_update ${GAME_ID}
quit""" > update.txt
if [ "${INSTALL_DIR}" = "l4d2" ]; then
  # https://github.com/ValveSoftware/steam-for-linux/issues/11522
  echo """force_install_dir "/home/louis/${INSTALL_DIR}"
  login anonymous
  @sSteamCmdForcePlatformType windows
  app_update ${GAME_ID}
  @sSteamCmdForcePlatformType linux
  app_update ${GAME_ID} validate
  quit""" > first-install-l4d2.txt
  ./steamcmd.sh +runscript first-install-l4d2.txt
else
  ./steamcmd.sh +runscript update.txt
fi