# Left 4 Dead 2 Server Docker Deployment Guide

## English | [简体中文](./README-zh.md)

## Project Overview

A containerized Docker solution for quickly deploying a dedicated Left 4 Dead 2
(L4D2) server. It ships with the complete server setup, a plugin system, and
one-click deployment.

Key design choices:

- **The game is installed at container startup, not baked into the image.** The
  image stays small; `as-user.sh` downloads and installs L4D2 via SteamCMD on
  the first start, then only updates/validates on later starts.
- **All game data is persisted.** The base directory (`BASE_DIR`, default
  `/home/louis`) is mounted as a Docker volume, so the multi-GB download
  survives container recreation.
- **All runtime settings live in one `.env` file.** The single
  `docker-compose.yml` reads them automatically, so there is no need to edit
  compose files for common changes.

## How it works

1. `as-root.sh` runs at **build time** (inside the Dockerfile): installs system
   dependencies, sets the timezone that is baked into the image, creates the
   unprivileged `louis` user, and prepares the system.
2. The image is built **without** the game inside it.
3. At **container startup**, `entrypoint.sh` (running as `louis`):
   - derives `GAME_ROOT` / `PLUGIN_DIR` from `BASE_DIR` / `INSTALL_DIR` /
     `GAME_NAME`;
   - runs `install-plugins.sh` to install plugins into the game directory on
     first run (unless `INSTALL_PLUGINS=false`);
   - runs `as-user.sh` to install/update the game via SteamCMD;
   - launches `srcds_run` with your settings.

## File Structure

```
.
├── as-root.sh            # Build-time system setup (root, run inside Dockerfile)
├── as-user.sh            # Game installer - runs at container startup
├── entrypoint.sh         # Container entrypoint (plugins + game)
├── install-plugins.sh    # Plugin installer - runs at container startup
├── docker-compose.yml    # Deployment with Docker named volumes (the default file)
├── .env                  # All runtime configuration
├── build-l4d2.sh         # Docker image build helper
└── README.md             # This file
```

## Quick Start

### 1. Build the image

```bash
chmod +x *.sh
sudo ./build-l4d2.sh      # builds kevonlin/l4d2:latest
```

### 2. Configure

Copy/rename the supplied `.env` (or at least review its values). Every runtime
setting is read from this file by `docker-compose.yml`.

### 3. Deploy

```bash
docker compose up -d
```

> **Note:** The game is **not** in the image. On the first container start,
> `as-user.sh` downloads and installs L4D2 via SteamCMD (slow, needs a stable
> network). Later starts only update/validate the existing install.

## Configuration

### Environment variables

All settings are defined in the `.env` file (loaded by `docker-compose.yml`).

| Variable                    | Default       | Description                                                          |
| --------------------------- | ------------- | -------------------------------------------------------------------- |
| `BASE_DIR`                  | /home/louis   | Base directory for the game user (`louis`)                           |
| `INSTALL_DIR`               | l4d2          | Install subdirectory under `BASE_DIR`                                |
| `GAME_NAME`                 | left4dead2    | Game directory name (used for the `-game` and plugin path)           |
| `GAME_ID`                   | 222860        | Steam AppID of the game server                                       |
| `INSTALL_PLUGINS`           | true          | Auto-install plugins on first start (`true` / `false`)               |
| `PORT`                      | 27015         | Game server port (TCP/UDP)                                           |
| `IP`                        | 0.0.0.0       | Bind IP address                                                      |
| `CLOCK_CORRECTION_MSECS`    | 25            | `+sv_clockcorrection_msecs` startup value                            |
| `TIMEOUT`                   | 10            | Connection timeout in seconds (`-timeout`)                           |
| `TICKRATE`                  | 100           | Server tickrate (needs `server.cfg` adjustment if changed)           |
| `EXEC_CFG`                  | server.cfg    | Config file to execute (`+exec`)                                     |
| `MAXPLAYERS`                | -             | Maximum players (omitted if unset or <= 0)                           |
| `DEFAULT_MAP`               | c2m1_highway  | Default map                                                          |
| `TZ`                        | Asia/Shanghai | Timezone                                                             |
| `SSH_PUBLIC_KEY`            | -             | Your SSH public key (reserved - not applied at runtime yet)          |

> **Timezone is applied at build time.** `as-root.sh` bakes the `TZ` value into
> the image during `build-l4d2.sh`; changing it in `.env` does not alter a
> running container. Rebuild the image to change it.

### Data persistence

The whole game directory is mounted via the `l4d2-game` volume at `${BASE_DIR}`
(default `/home/louis`):

- `{BASE_DIR}/{INSTALL_DIR}` — the installed game (the big one).
- `{BASE_DIR}/{INSTALL_DIR}/{GAME_NAME}/addons` — plugins
- `{BASE_DIR}/{INSTALL_DIR}/{GAME_NAME}/cfg` — configuration
- `{BASE_DIR}/{INSTALL_DIR}/{GAME_NAME}/scripts` — scripts

`docker compose down` / `up` keeps all data; only `docker compose down -v`
removes it.

## Plugin management

The
[L4D2-Competitive-Rework](https://github.com/SirPlease/L4D2-Competitive-Rework)
plugins are installed by `install-plugins.sh` into the game directory's
`addons` / `cfg` / `scripts` folders on the first start (when
`addons/sourcemod` is absent). To re-install, clear `addons/sourcemod` and
restart the container. Set `INSTALL_PLUGINS=false` in `.env` to skip automatic
installation entirely.

## Notes & troubleshooting

- **First start is slow.** Expect a long SteamCMD download the first time.
- **Timezone is baked in at build time.** Change `TZ` and rebuild the image.
- **Permissions:** `louis` owns everything under `${BASE_DIR}`, so SSH uploads
  to those directories need no manual `chown`.
- **Compliance:** respect Steam/Valve ToS. For personal or community servers only.

## License

Open source. Plugin components follow their respective licenses.

## Support & contribution

Issues and pull requests are welcome.
