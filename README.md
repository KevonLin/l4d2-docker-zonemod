# Left 4 Dead 2 Server Docker Deployment Guide

## English | [简体中文](./README-zh.md)

## Project Overview

A containerized Docker solution for quickly deploying a dedicated Left 4 Dead 2
(L4D2) server. It ships with the complete server setup, a plugin system, and
one-click deployment.

Key design choices:

- **The game is installed at container startup, not baked into the image.** The
  image stays small; `as-user.sh` downloads and installs L4D2 via SteamCMD on the
  first start, then only updates/validates on later starts.
- **Game data is persisted.** The install directory is mounted as a volume (or
  bind mount), so the multi-GB download survives container recreation.

## How it works

1. `as-root.sh` (runs at **build time**) installs system dependencies, `gosu`,
   creates the unprivileged `louis` user, and prepares the mount points.
2. The image is built **without** the game inside it.
3. At **container startup**, `entrypoint.sh`:
   - (as root) sets the timezone, installs your SSH key, makes sure the game
     directory is owned by `louis`, installs plugins on first run, starts SSHd;
   - (as `louis`) runs `as-user.sh` to install/update the game, then launches
     `srcds_run`.

## File Structure

```
.
├── as-root.sh          # Build-time system setup (root)
├── as-user.sh          # Game installer, runs at CONTAINER STARTUP via entrypoint.sh
├── build-l4d2.sh       # Docker image build helper
├── entrypoint.sh       # Container entrypoint (root -> louis)
├── install-plugins.sh  # (legacy) standalone plugin installer
├── compose.yml         # Sample: deployment with Docker named volumes
├── compose.bind.yml    # Sample: deployment with host bind mounts
└── README.md           # This file
```

## Quick Start

### 1. Build the image

```bash
chmod +x *.sh
sudo ./build-l4d2.sh      # builds kevonlin/l4d2:latest
```

### 2. Deploy

Pick one of the two deployment styles below, then start the server:

```bash
# Named volumes (recommended)
docker compose -f compose.yml up -d

# Host bind mounts
docker compose -f compose.bind.yml up -d
```

> **Note:** The game is **not** in the image. On the first container start,
> `as-user.sh` downloads and installs L4D2 via SteamCMD (slow, needs a stable
> network). Later starts only update/validate the existing install.

## Deployment methods

Both samples expose the same server; they differ only in how data is stored.

### A. Named volumes (`compose.yml`) — recommended

Data lives in Docker-managed volumes. Simplest, no host paths to manage. Data
survives `docker compose down` / `up`. Use `docker compose down -v` to wipe it.

### B. Bind mounts (`compose.bind.yml`)

Data lives in directories next to the compose file (`l4d2/`, `addons/`, `cfg/`,
`scripts/`) so you can inspect/edit files directly on the host. On first start
the directories are created and the game directory is chowned to UID 1000
(`louis`); the plugin step chowns `/addons`, `/cfg`, `/scripts` the same way.

## Configuration

### Environment variables

Set these in the `environment:` block of the compose file.

| Variable         | Default        | Description                                                        |
| ---------------- | -------------- | ------------------------------------------------------------------ |
| `PORT`           | 27015          | Game server port                                                   |
| `DEFAULT_MAP`    | c2m1_highway   | Default map                                                        |
| `MAXPLAYERS`     | -              | Maximum players (omitted if unset / <= 0)                          |
| `TICKRATE`       | 100            | Server tickrate (needs `server.cfg` adjustment if changed)         |
| `TZ`             | Asia/Shanghai  | Timezone                                                           |
| `IP`             | 0.0.0.0        | Bind IP address                                                    |
| `EXEC_CFG`       | server.cfg     | Server config file                                                 |
| `SSH_PUBLIC_KEY` | -              | Your SSH public key (enables SSH login as `louis`)                 |
| `GAME_ID`        | 222860         | Steam AppID of the game server                                     |
| `INSTALL_DIR`    | l4d2           | Install directory under `/home/louis` (must match the mount path)  |

> If you override `INSTALL_DIR`, also update the volume/bind mount path for the
> game (e.g. `/home/louis/<your-dir>` or `./<your-dir>`).

### Data persistence

Persisted via Docker volumes / bind mounts:

- `/home/louis/l4d2` — the installed game (the big one). **Mount this or the
  game re-downloads on every recreate.**
- `/addons` — plugins
- `/cfg` — configuration
- `/scripts` — scripts

SteamCMD itself (`/home/louis/steamcmd.sh`, `.steam`) is **not** persisted;
it is re-fetched on each start if missing (small download).

## Plugin management

The [L4D2-Competitive-Rework](https://github.com/SirPlease/L4D2-Competitive-Rework)
plugins are installed automatically into `/addons`, `/cfg`, `/scripts` on the
first start (when those directories are empty). To re-install, clear the
`/addons/sourcemod` directory and restart.

## Notes & troubleshooting

- **First start is slow.** Expect a long SteamCMD download the first time.
- **Permissions (bind mounts):** host directories end up owned by UID 1000. Edit
  them as UID 1000 or `chown` to your own UID.
- **SSH:** add your key via `SSH_PUBLIC_KEY`. Password auth is disabled.
- **Compliance:** respect Steam/Valve ToS. For personal or community servers only.

## License

Open source. Plugin components follow their respective licenses.

## Support & contribution

Issues and pull requests are welcome.
