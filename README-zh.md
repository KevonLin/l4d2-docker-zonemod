# Left 4 Dead 2 服务器 Docker 部署指南

## [English](./README.md) | 简体中文

## 项目概述

这是一个用于快速部署 Left 4 Dead 2 (L4D2) 专用服务器的 Docker 容器化解决方案，
内置完整的服务器配置、插件系统和一键部署能力。

核心设计：

- **游戏在容器启动时安装，而不是打包进镜像。** 镜像体积很小；首次启动时
  `as-user.sh` 通过 SteamCMD 下载并安装 L4D2，之后每次启动仅做更新/校验。
- **游戏数据持久化。** 安装目录以卷（volume）或绑定挂载（bind mount）方式挂载，
  因此这个几十 GB 的下载在容器重建后依然保留。

## 工作原理

1. `as-root.sh`（在**构建时**运行）安装系统依赖、`gosu`，创建非特权用户
   `louis`，并准备好各挂载点。
2. 构建出的镜像**不包含**游戏本体。
3. 在**容器启动时**，`entrypoint.sh` 会：
   - （以 root）设置时区、写入你的 SSH 公钥、确保游戏目录归 `louis` 所有、
     首次运行时安装插件、启动 SSH 服务；
   - （以 `louis`）运行 `as-user.sh` 安装/更新游戏，然后启动 `srcds_run`。

## 文件结构

```
.
├── as-root.sh          # 构建期系统初始化脚本（root 权限）
├── as-user.sh         # 游戏安装脚本，在容器启动时（由 entrypoint.sh 调用）执行
├── build-l4d2.sh       # Docker 镜像构建辅助脚本
├── entrypoint.sh       # 容器入口点脚本（root -> louis）
├── install-plugins.sh  # （旧）独立插件安装脚本
├── compose.yml         # 样本：使用 Docker 命名卷部署
├── compose.bind.yml    # 样本：使用主机绑定挂载部署
└── README.md           # 英文文档
```

## 快速开始

### 1. 构建镜像

```bash
chmod +x *.sh
sudo ./build-l4d2.sh      # 构建 kevonlin/l4d2:latest
```

### 2. 部署

选择下面两种部署方式之一，然后启动服务器：

```bash
# 命名卷方式（推荐）
docker compose -f compose.yml up -d

# 主机绑定挂载方式
docker compose -f compose.bind.yml up -d
```

> **注意**：游戏**不会**打包进镜像。首次启动容器时，`as-user.sh` 会通过
> SteamCMD 下载并安装 L4D2（耗时较长，需要稳定的网络连接）。之后启动只会
> 更新/校验已有的安装。

## 部署方式

两个样本暴露的服务器完全一致，区别仅在于数据如何存储。

### A. 命名卷（`compose.yml`）—— 推荐

数据存放在 Docker 管理的卷中。最简单，无需管理主机路径。数据在
`docker compose down` / `up` 后仍保留；使用 `docker compose down -v` 可清空数据。

### B. 绑定挂载（`compose.bind.yml`)

数据存放在 compose 文件同级目录下（`l4d2/`、`addons/`、`cfg/`、`scripts/`），
方便你在主机上直接查看/编辑文件。容器每次启动时，`entrypoint` 都会把
`/home/louis/l4d2`、`/addons`、`/cfg`、`/scripts` 的归属改为 `louis`
（UID 1000），因此你可以直接用 `louis` 通过 SSH 登录并上传文件，无需手动
`chown`。

## 配置说明

### 环境变量

在 compose 文件的 `environment:` 块中配置：

| 变量名          | 默认值        | 说明                                                  |
| --------------- | ------------- | ----------------------------------------------------- |
| `PORT`          | 27015         | 游戏服务器端口                                        |
| `DEFAULT_MAP`   | c2m1_highway  | 默认地图                                              |
| `MAXPLAYERS`    | -             | 最大玩家数（未设置或 <= 0 时不传）                    |
| `TICKRATE`      | 100           | 服务器刷新率（如更改需修改 server.cfg）               |
| `TZ`            | Asia/Shanghai | 时区                                                  |
| `IP`            | 0.0.0.0       | 绑定 IP 地址                                          |
| `EXEC_CFG`      | server.cfg    | 服务器配置文件                                        |
| `SSH_PUBLIC_KEY`| -             | 你的 SSH 公钥（启用后可用 `louis` 用户 SSH 登录）     |
| `GAME_ID`       | 222860        | 游戏服务器的 Steam AppID                              |
| `INSTALL_DIR`   | l4d2          | `/home/louis` 下的安装目录（须与挂载路径一致）        |

> 如果你覆盖了 `INSTALL_DIR`，请同步修改游戏对应的卷/绑定挂载路径
> （例如 `/home/louis/<你的目录>` 或 `./<你的目录>`）。

### 数据持久化

通过 Docker 卷 / 绑定挂载持久化的内容：

- `/home/louis/l4d2` —— 已安装的游戏（体积最大的部分）。**必须挂载此目录，
  否则每次重建容器都会重新下载游戏。**
- `/addons` —— 插件
- `/cfg` —— 配置文件
- `/scripts` —— 脚本文件

SteamCMD 本身（`/home/louis/steamcmd.sh`、`.steam`）**不会**持久化；若缺失会在
每次启动时重新下载（体积很小）。

## 插件管理

首次启动（当上述目录为空时）会自动将
[L4D2-Competitive-Rework](https://github.com/SirPlease/L4D2-Competitive-Rework)
插件安装到 `/addons`、`/cfg`、`/scripts`。如需重装，清空 `/addons/sourcemod`
目录后重启容器即可。

## 注意事项与排错

- **首次启动很慢：** 第一次会有较长时间的 SteamCMD 下载。
- **权限（绑定挂载）：** 容器每次启动都会把 `/home/louis/l4d2`、`/addons`、
  `/cfg`、`/scripts` 设为 `louis`（UID 1000）所有，因此以 `louis` 通过 SSH
  上传文件无需手动 `chown`。若主机上已存在归 root 所有的旧文件（罕见），就地
  编辑它们可能仍需一次性 `chown -R louis:louis`。
- **SSH：** 通过 `SSH_PUBLIC_KEY` 添加公钥（密码登录已禁用）。以 `louis` 登录后
  即可上传插件/配置；目标目录归 `louis` 所有，上传无需手动 `chown`。
- **合规性：** 请遵守 Steam / Valve 的使用条款，仅用于个人或社区服务器。

## 许可证

本项目基于开源许可证发布。插件部分遵循其各自的许可证。

## 支持与贡献

如有问题或建议，欢迎提交 Issue 或 Pull Request。
