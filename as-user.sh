#!/bin/bash
set -euo pipefail

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
if ! ./steamcmd.sh +quit; then
    echo "ERROR: steamcmd initialization failed." >&2
    exit 1
fi

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

# 生成安装脚本
echo """force_install_dir "/home/louis/${INSTALL_DIR}"
login anonymous
app_update ${GAME_ID}
quit""" > update.txt

# 定义验证函数：检查游戏可执行文件是否存在
check_game_installed() {
    if [ ! -f "${INSTALL_DIR}/srcds_run" ]; then
        echo "ERROR: Game installation failed - srcds_run not found in ${INSTALL_DIR}." >&2
        exit 1
    fi
}

if [ "${INSTALL_DIR}" = "l4d2" ]; then
    # 针对 L4D2 的首次安装脚本（处理 Windows 依赖）
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
    # 验证安装结果
    check_game_installed
else
    echo ">>> Installing/updating game (AppID: ${GAME_ID})..."
    if ! ./steamcmd.sh +runscript update.txt; then
        echo "ERROR: steamcmd failed to execute the install script." >&2
        exit 1
    fi
    check_game_installed
fi

echo ">>> Game installation completed successfully."