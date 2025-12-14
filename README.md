# Left 4 Dead 2 Server Docker Deployment Guide

## Project Overview

This is a containerized Docker solution for quickly deploying a dedicated Left 4 Dead 2 (L4D2) server. The project includes complete server configuration, plugin system, and one-click deployment functionality.

## System Requirements

- Linux system (Ubuntu/Debian/CentOS recommended)
- Docker and Docker Compose
- At least 10GB available disk space
- Stable network connection

## File Structure

```
.
├── as-root.sh          # Docker container initialization script (root privileges)
├── as-user.sh         # SteamCMD and game installation script
├── build-l4d2.sh      # Docker image build script
├── entrypoint.sh      # Container entrypoint script
├── compose.yml        # Docker Compose configuration file
└── install-plugins.sh # Plugin installation script
```

## Quick Start

### 1. Build Docker Image

```bash
# Grant execution permissions
chmod +x build-l4d2.sh

# Build image
./build-l4d2.sh
```

### 2. Start Server

```bash
# Start using Docker Compose
docker-compose up -d
```

## Configuration

### Environment Variables

The following environment variables can be configured in `compose.yml`:

| Variable      | Default Value | Description                                                  |
| ------------- | ------------- | ------------------------------------------------------------ |
| `PORT`        | 27015         | Game server port                                             |
| `DEFAULT_MAP` | c2m1_highway  | Default map                                                  |
| `MAXPLAYERS`  | -             | Maximum players (default if not set)                         |
| `TICKRATE`    | 100           | Server tickrate (requires server.cfg modification if changed) |
| `TZ`          | Asia/Shanghai | Timezone setting                                             |
| `IP`          | 0.0.0.0       | Bind IP address                                              |
| `EXEC_CFG`    | server.cfg    | Server configuration file                                    |

### Data Persistence

The following directories are persistently stored via Docker volumes:

- `/addons` - Plugin files
- `/cfg` - Configuration files
- `/scripts` - Script files

## Plugin Management

### Default Plugins

The project comes pre-installed with the [L4D2-Competitive-Rework](https://github.com/SirPlease/L4D2-Competitive-Rework) plugin.

## License

This project is released under an open source license. Plugin components follow their respective licenses.

## Support and Contribution

For issues or suggestions, please submit an Issue or Pull Request.

---

**Note**: Please ensure compliance with Steam and Valve's Terms of Service. This project is only for setting up personal or community game servers.
