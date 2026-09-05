# Left 4 Dead 2 服务器 Docker 部署指南

## [English](./README.md) | 简体中文

## 项目概述

这是一个用于快速部署 Left 4 Dead 2 (L4D2) 专用服务器的 Docker 容器化解决方案，
内置完整的服务器配置、插件系统和一键部署能力。

核心设计：

- **游戏在容器启动时安装，而不是打包进镜像。** 镜像体积很小；首次启动时
  `as-user.sh` 通过 SteamCMD 下载并安装 L4D2，之后每次启动仅做更新/校验。
- **所有游戏数据持久化。** 游戏基础目录（`HOME`，默认 `/home/louis`）以
  Docker 卷方式挂载，因此这个几十 GB 的下载在容器重建后依然保留。
- **所有运行时配置集中在一个 `.env` 文件中。** 唯一的 `docker-compose.yml`
  会自动读取它，常见修改无需编辑 compose 文件。

## 工作原理

1. `as-root.sh` 在**构建时**（Dockerfile 内）运行：安装系统依赖、`gosu`（用于
   降权）、非特权用户 `louis`，并准备好系统环境。镜像本身不固定时区。
2. 构建出的镜像**不包含**游戏本体。
3. 在**容器启动时** `entrypoint.sh` 会：
   - （以 root）根据实时环境变量 `TZ` 设置时区，并按 `SSH_PORT` 配置并启动
     SSH 服务，然后通过 `gosu` 降权为 `louis` 用户；
   - （以 `louis`）运行 `install-plugins.sh` 将插件安装到游戏目录（仅首次
     运行时，除非 `INSTALL_PLUGINS=false`）；
   - 运行 `as-user.sh` 通过 SteamCMD 安装/更新游戏；
   - 通过 `start.sh` 启动游戏服务器并接管守护：`srcds` 以后台守护进程方式
     运行，控制台输出实时转发到 `docker logs`，崩溃时自动重启；也可随时
     使用 `stop.sh` / `restart.sh` 停止/重启（见下文）。

## 文件结构

```
.
├── as-root.sh            # 构建期系统初始化脚本（root 权限，在 Dockerfile 内执行）
├── as-user.sh            # 游戏安装脚本，容器启动时执行
├── entrypoint.sh         # 容器入口点脚本（插件 + 游戏 + 守护）
├── install-plugins.sh    # 插件安装脚本，容器启动时执行
├── start.sh              # 将 srcds 作为后台守护进程启动（安装到 /usr/local/bin）
├── stop.sh               # 优雅停止 srcds
├── restart.sh            # 在同一容器内重启 srcds
├── docker-compose.yml    # 使用 Docker 命名卷部署（默认文件名）
├── .env                  # 所有运行时配置
├── build-l4d2.sh         # Docker 镜像构建辅助脚本
└── README.md             # 英文文档
```

## 快速开始

### 1. 构建镜像

```bash
chmod +x *.sh
sudo ./build-l4d2.sh      # 构建 kevonlin/l4d2:latest
```

### 2. 配置

将提供的 `.env` 复制/重命名为你的配置（或至少检查其中各项取值）。所有运行时
设置均由 `docker-compose.yml` 从该文件读取。

### 3. 部署

```bash
docker compose up -d
```

> **注意**：游戏**不会**打包进镜像。首次启动容器时，`as-user.sh` 会通过
> SteamCMD 下载并安装 L4D2（耗时较长，需要稳定的网络连接）。之后启动只会
> 更新/校验已有的安装。

## 在容器内管理服务器

管理脚本安装在镜像的 `/usr/local/bin/` 下，可通过 SSH（以 `louis` 登录）或
`docker exec` 使用：

```bash
docker exec l4d2 /usr/local/bin/restart.sh   # 重启游戏服务器
docker exec l4d2 /usr/local/bin/stop.sh      # 停止游戏服务器
docker exec l4d2 /usr/local/bin/start.sh     # （重新）启动游戏服务器
```

- `start.sh` 将 `srcds_run` 作为后台守护进程运行，状态（PID 文件、控制台日志、
  控制文件）存放在 `{HOME}/.l4d2/`，由 `entrypoint.sh` 在每次启动容器时自动调用。
- `entrypoint.sh` 让容器保持存活，把控制台实时转发到 `docker logs`，并在服务端
  意外退出时自动重启（带退避；连续多次快速崩溃后放弃）。
- `restart.sh` 在**同一容器内**重启服务端——不重建容器，SSH 会话不受影响。
- `stop.sh` 停止服务端并结束容器。由于 `docker-compose.yml` 使用了
  `restart: unless-stopped`，如需长期停服请用 `docker compose stop`。

## 配置说明

### 环境变量

所有设置都在 `.env` 文件中定义（由 `docker-compose.yml` 加载）：

| 变量                       | 默认值         | 说明                                                          |
| -------------------------- | ------------- | ------------------------------------------------------------- |
| `HOME`                     | /home/louis   | 游戏用户（`louis`）的基础目录                                   |
| `INSTALL_DIR`              | l4d2          | `HOME` 下的安装子目录                                          |
| `GAME_NAME`                | left4dead2    | 游戏目录名（用于 `-game` 参数和插件路径）                       |
| `GAME_ID`                  | 222860        | 游戏服务器的 Steam AppID                                      |
| `INSTALL_PLUGINS`          | true          | 首次启动时自动安装插件（`true` / `false`）                      |
| `PORT`                     | 27015         | 游戏服务器端口（TCP/UDP）                                      |
| `IP`                       | 0.0.0.0       | 绑定 IP 地址                                                  |
| `CLOCK_CORRECTION_MSECS`   | 25            | `+sv_clockcorrection_msecs` 启动参数                          |
| `TIMEOUT`                  | 10            | 连接超时秒数（`-timeout`）                                     |
| `TICKRATE`                 | 100           | 服务器刷新率（如更改需修改 server.cfg）                        |
| `EXEC_CFG`                 | server.cfg    | 要执行的服务器配置文件（`+exec`）                              |
| `MAXPLAYERS`               | -             | 最大玩家数（未设置或 <= 0 时不传）                             |
| `DEFAULT_MAP`              | c2m1_highway  | 默认地图                                                      |
| `TZ`                       | Asia/Shanghai | 时区                                                          |
| `SSH_PUBLIC_KEY`           | -             | 你的 SSH 公钥（启用后可用 `louis` 用户 SSH 登录）               |
| `SSH_PORT`                 | 22            | SSH 服务端口（启动时写入 sshd_config）                         |

> **时区在容器启动时生效。** `entrypoint.sh` 每次启动时读取环境变量 `TZ`
> （来自 `.env`），并设置 `/etc/timezone` 与 `/etc/localtime`。无需重建镜像
> —— 修改 `.env` 中的 `TZ` 后重启容器即可。
>
> **SSH 端口在容器启动时生效。** `entrypoint.sh` 读取 `SSH_PORT` 环境变量，
> 在启动 sshd 前改写 `/etc/ssh/sshd_config` 中的 `Port` 指令。修改 `.env` 中的
> `SSH_PORT` 后重启即可更换端口。

### 数据持久化

整个游戏目录通过 `l4d2-game` 卷挂载在 `${HOME}`（默认 `/home/louis`）下：

- `{HOME}/{INSTALL_DIR}` —— 已安装的游戏（体积最大的部分）
- `{HOME}/{INSTALL_DIR}/{GAME_NAME}/addons` —— 插件
- `{HOME}/{INSTALL_DIR}/{GAME_NAME}/cfg` —— 配置文件
- `{HOME}/{INSTALL_DIR}/{GAME_NAME}/scripts` —— 脚本文件

`docker compose down` / `up` 后数据仍保留；仅 `docker compose down -v` 会清空数据。

## 插件管理

首次启动时（当 `addons/sourcemod` 目录不存在时），`install-plugins.sh` 会将
[L4D2-Competitive-Rework](https://github.com/SirPlease/L4D2-Competitive-Rework)
插件安装到游戏目录的 `addons` / `cfg` / `scripts` 中。如需重装，清空
`addons/sourcemod` 目录后重启容器即可。在 `.env` 中设置 `INSTALL_PLUGINS=false`
可完全跳过自动安装。

## 注意事项与排错

- **首次启动很慢：** 第一次会有较长时间的 SteamCMD 下载。
- **时区在启动时生效：** 修改 `.env` 中的 `TZ` 后重启容器即可，无需重建镜像。
- **SSH（可选）：** 设置 `SSH_PUBLIC_KEY` 即可用 `louis` 登录（密码登录已禁用），
  用 `SSH_PORT` 指定端口（默认 22）。两者均在启动时生效，无需重建镜像。
- **崩溃自愈：** `srcds` 由入口脚本守护，异常退出时会自动重启（带退避）；
  `restart.sh` / `stop.sh` 可在不重建容器的情况下管理服务端。
- **权限：** `${HOME}` 下所有内容均归 `louis` 所有，因此通过 SSH 上传到
  这些目录无需手动 `chown`。
- **合规性：** 请遵守 Steam / Valve 的使用条款，仅用于个人或社区服务器。

## 许可证

本项目基于开源许可证发布。插件部分遵循其各自的许可证。

## 支持与贡献

如有问题或建议，欢迎提交 Issue 或 Pull Request。
