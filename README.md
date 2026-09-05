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
- **All game data is persisted.** The base directory (`HOME`, default
  `/home/louis`) is mounted as a Docker volume, so the multi-GB download
  survives container recreation.
- **All runtime settings live in one `.env` file.** The single
  `docker-compose.yml` reads them automatically, so there is no need to edit
  compose files for common changes.

## How it works

1. `as-root.sh` runs at **build time** (inside the Dockerfile): installs system
   dependencies, `gosu` (for privilege dropping), the unprivileged `louis`
   user, and prepares the system. The image itself stays timezone-agnostic.
2. The image is built **without** the game inside it.
3. At **container startup**, `entrypoint.sh`:
   - (as root) applies the timezone from the live `TZ` environment variable,
     starts the SSH server (set to the `SSH_PORT` from the environment), then
     drops to the `louis` user via `gosu`;
   - (as `louis`) runs `install-plugins.sh` to install plugins into the game
     directory on first run (unless `INSTALL_PLUGINS=false`);
   - runs `as-user.sh` to install/update the game via SteamCMD;
   - launches the game server through `start.sh` and supervises it: `srcds`
     runs as a background daemon, its console is streamed to `docker logs`,
     and it is restarted automatically after a crash. You can also stop or
     restart it on the fly with `stop.sh` / `restart.sh`.

## File Structure

```
.
├── as-root.sh            # Build-time system setup (root, run inside Dockerfile)
├── as-user.sh            # Game installer - runs at container startup
├── entrypoint.sh         # Container entrypoint (plugins + game + supervisor)
├── install-plugins.sh    # Plugin installer - runs at container startup
├── start.sh              # Starts srcds as a daemon (installed to /usr/local/bin)
├── stop.sh               # Gracefully stops srcds
├── restart.sh            # Restarts srcds in the same container
├── docker-compose.yml    # Deployment with Docker named volumes (the default file)
├── .env.example          # All runtime configuration template (copy to .env)
├── build-l4d2.sh         # Docker image build helper
├── Makefile              # Local CI targets: `make ci` / `make ci-full`
├── setup-hooks.sh        # Installs a git pre-push hook that runs `make ci`
├── .scripts              # Local CI script mirroring .github/workflows/ci.yml
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

## Server management (inside the container)

The management scripts are installed at `/usr/local/bin/` in the image and can
be used over SSH (as `louis`) or with `docker exec`:

```bash
docker exec l4d2 /usr/local/bin/restart.sh   # restart the game server
docker exec l4d2 /usr/local/bin/stop.sh      # stop the game server
docker exec l4d2 /usr/local/bin/start.sh     # (re)start the game server
```

- `start.sh` runs `srcds_run` as a background daemon; its state (PID file,
  console log, control file) lives in `{HOME}/.l4d2/`. `entrypoint.sh` calls
  it on every container start.
- `entrypoint.sh` keeps the container alive, streams the console to
  `docker logs`, and restarts the server automatically when it crashes
  (with a short backoff; it gives up after repeated fast crashes).
- `restart.sh` restarts the server **in the same container** — no recreation,
  SSH sessions stay up.
- `stop.sh` stops the server and shuts the container down. Because
  `docker-compose.yml` uses `restart: unless-stopped`, use `docker compose
  stop` to keep the server down for good.

## Local development & CI

Contributors can run the same validation as
[`.github/workflows/ci.yml`](.github/workflows/ci.yml) locally — no GitHub
Actions needed:

```bash
make ci            # quick checks: YAML lint, shell syntax, Dockerfile static
                   # check, external-URL reachability, .env.example validation,
                   # cross-file consistency (no game download)
make ci-full       # quick checks + full image build (downloads the game)
```

Or run the script directly:

```bash
./.scripts/local-ci.sh          # quick checks
./.scripts/local-ci.sh --full   # full image build
```

To run the quick checks automatically before every `git push`, install the
bundled pre-push hook:

```bash
./setup-hooks.sh
```

The hook is installed only into your local clone's `.git/hooks/` directory and
is never shared with other contributors.

## Configuration

### Environment variables

All settings are defined in the `.env` file (loaded by `docker-compose.yml`).

| Variable                    | Default       | Description                                                          |
| --------------------------- | ------------- | -------------------------------------------------------------------- |
| `HOME`                      | /home/louis   | Base directory for the game user (`louis`)                           |
| `INSTALL_DIR`               | l4d2          | Install subdirectory under `HOME`                                    |
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
| `SSH_PUBLIC_KEY`            | -             | Your SSH public key (enables SSH login as `louis`)                   |
| `SSH_PORT`                  | 22            | SSH server port (applied to sshd_config at startup)                  |

> **Timezone is applied at container startup.** `entrypoint.sh` reads the `TZ`
> environment variable (from `.env`) and sets `/etc/timezone` +
> `/etc/localtime` on every start. No rebuild needed — just change `TZ` in
> `.env` and restart the container.
>
> **SSH port is applied at container startup.** `entrypoint.sh` reads `SSH_PORT`
> from the environment and rewrites the `Port` directive in `/etc/ssh/sshd_config`
> before starting sshd. Change `SSH_PORT` in `.env` and restart to use another
> port.

### Data persistence

The whole game directory is mounted via the `l4d2-game` volume at `${HOME}`
(default `/home/louis`):

- `{HOME}/{INSTALL_DIR}` — the installed game (the big one).
- `{HOME}/{INSTALL_DIR}/{GAME_NAME}/addons` — plugins
- `{HOME}/{INSTALL_DIR}/{GAME_NAME}/cfg` — configuration
- `{HOME}/{INSTALL_DIR}/{GAME_NAME}/scripts` — scripts

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
- **Timezone is applied at startup.** Change `TZ` in `.env` and restart the
  container — no rebuild required.
- **SSH:** optional. Set `SSH_PUBLIC_KEY` to log in as `louis` (password auth
  is disabled) and `SSH_PORT` to choose its port (default 22). Both apply at
  startup; no rebuild needed.
- **Crash recovery:** `srcds` is supervised — unexpected exits are restarted
  automatically with a short backoff, and `restart.sh` / `stop.sh` manage the
  server without recreating the container.
- **Permissions:** `louis` owns everything under `${HOME}`, so SSH uploads
  to those directories need no manual `chown`.
- **Compliance:** respect Steam/Valve ToS. For personal or community servers only.

## License

Open source. Plugin components follow their respective licenses.

## Support & contribution

Issues and pull requests are welcome.
