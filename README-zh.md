# Left 4 Dead 2 服务器 Docker 部署指南

## 项目概述

这是一个用于快速部署 Left 4 Dead 2 (L4D2) 专用服务器的 Docker 容器化解决方案。项目包含完整的服务器配置、插件系统和一键部署功能。

## 系统要求

- Linux 系统（推荐 Ubuntu/Debian/CentOS）
- Docker 和 Docker Compose
- 至少 10GB 可用磁盘空间
- 稳定的网络连接

## 文件结构

```
.
├── as-root.sh          # Docker 容器初始化脚本（root 权限）
├── as-user.sh         # SteamCMD 和游戏安装脚本
├── build-l4d2.sh      # Docker 镜像构建脚本
├── entrypoint.sh      # 容器入口点脚本
├── compose.yml        # Docker Compose 配置文件
└── install-plugins.sh # 插件安装脚本
```

## 快速开始

### 1. 构建 Docker 镜像

```bash
# 赋予执行权限
chmod +x *.sh

# 构建镜像
sudo ./build-l4d2.sh
```

### 2. 启动服务器

```bash
# 使用 Docker Compose 启动
docker-compose up -d
```

## 配置说明

### 环境变量

在 `compose.yml` 中可配置以下环境变量：

| 变量名        | 默认值        | 说明                                  |
| ------------- | ------------- | ------------------------------------- |
| `PORT`        | 27015         | 游戏服务器端口                        |
| `DEFAULT_MAP` | c2m1_highway  | 默认地图                              |
| `MAXPLAYERS`  | -             | 最大玩家数（不设置则使用默认）        |
| `TICKRATE`    | 100           | 服务器刷新率（如更改需修改server.cfg) |
| `TZ`          | Asia/Shanghai | 时区设置                              |
| `IP`          | 0.0.0.0       | 绑定IP地址                            |
| `EXEC_CFG`    | server.cfg    | 服务器配置文件                        |

### 数据持久化

以下目录通过 Docker 卷持久化存储：

- `/addons` - 插件文件
- `/cfg` - 配置文件
- `/scripts` - 脚本文件

## 插件管理

### 默认插件

项目默认安装了 [L4D2-Competitive-Rework](https://github.com/SirPlease/L4D2-Competitive-Rework) 插件。

## 许可证

本项目基于开源许可证发布。插件部分遵循其各自的许可证。

## 支持与贡献

如有问题或建议，请提交 Issue 或 Pull Request。

---

**注意**: 请确保遵守 Steam 和 Valve 的使用条款。此项目仅用于搭建个人或社区游戏服务器。
