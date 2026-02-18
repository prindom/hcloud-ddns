# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Home Assistant addon that automatically updates DNS A records in a Hetzner DNS zone to match the host's current public IP address. It is packaged as a Docker container using the [hassio-addons base image](https://github.com/hassio-addons/base).

## Local development (without Home Assistant)

The addon can be run standalone via Docker Compose for rapid iteration. The compose file mounts a local `options.json` in place of the HA config system that `bashio::config` reads from.

```bash
# First-time setup: copy the example and fill in your credentials
cp dev/options.example.json dev/options.json
# edit dev/options.json — dry_run is true by default

docker compose -f docker-compose.dev.yml up --build
```

`dev/options.json` is gitignored so credentials are never committed. `dry_run: true` is set in the example by default, so no DNS records will be modified during development.

The force-update web UI is available at `http://localhost:8099` once the container is running.

> **Note:** The init service still validates the API token and zone ID against the live Hetzner DNS API on startup, so real credentials are required even in dry run mode.

## Building

Build the Docker image locally:

```bash
docker build \
  --build-arg BUILD_FROM=ghcr.io/hassio-addons/base:20.0.1 \
  --build-arg BUILD_ARCH=amd64 \
  -t hcloud-ddns .
```

For development inside Home Assistant, use the devcontainer (VS Code) and run the **Start Home Assistant** task (`supervisor_run`). The devcontainer mounts the addon into the local supervisor at `/mnt/supervisor/addons/local/`.

## Linting

Shell scripts use `shellcheck`. The devcontainer installs the `timonwong.shellcheck` VS Code extension. To lint manually:

```bash
shellcheck rootfs/usr/bin/hcloud-ddns.sh
shellcheck rootfs/etc/s6-overlay/s6-rc.d/init-hcloud/run
shellcheck rootfs/etc/s6-overlay/s6-rc.d/hcloud-ddns/run
```

## Architecture

### Startup sequence (s6-overlay)

The container uses [s6-overlay](https://github.com/just-containers/s6-overlay) for process supervision. Services run in this order:

1. **`init-hcloud`** (`rootfs/etc/s6-overlay/s6-rc.d/init-hcloud/run`) — one-shot init service that:
   - Reads `api_key` from the addon config via `bashio::config`
   - Writes it to `/root/.config/hetzner-dns-token` (mode 600)
   - Validates `zone_id` and `domain` are set
   - Tests the Hetzner DNS API connection and fails fast on auth errors

2. **`hcloud-ddns`** (`rootfs/etc/s6-overlay/s6-rc.d/hcloud-ddns/run`) — long-running service that execs `/usr/bin/hcloud-ddns.sh`

### Main script (`rootfs/usr/bin/hcloud-ddns.sh`)

Written in bash using `bashio` helpers (provided by the base image). Key functions:

- `get_current_ip` — fetches public IP from ipify.org / icanhazip.com / ifconfig.me
- `get_dns_ip` — resolves current A record via Google DNS (8.8.8.8) using `nslookup`
- `get_api_token` — reads token from `/root/.config/hetzner-dns-token`
- `find_record_id` — queries `GET /api/v1/records?zone_id=…` and filters with `jq`
- `update_dns` — PUTs to update an existing record or POSTs to create a new one
- `main` — loops with `sleep` between checks; interval comes from `bashio::config 'update_interval'`

The Hetzner Cloud API base URL is `https://api.hetzner.cloud/v1`. Authentication header: `Authorization: Bearer <token>`. The token is a Hetzner Cloud project API token (created at console.hetzner.cloud), not the legacy dns.hetzner.com token (that service is EOL May 2026). DNS records use the **RRSet** model: `GET/POST/PUT /zones/{id}/rrsets`. Record names are relative to the zone (e.g. `home`, not `home.example.com`); the init script fetches and stores the zone name so the main script can derive the relative name from the configured FQDN.

### Addon configuration (`config.yaml`)

| Option | Type | Values |
|---|---|---|
| `api_key` | password | Hetzner DNS API token |
| `zone_id` | str | DNS zone ID |
| `domain` | str | Fully qualified domain name |
| `update_interval` | list | `hourly` / `daily` / `weekly` |
| `dry_run` | bool | Log what would change without making API calls |
| `log_level` | list | `trace` / `debug` / `info` / `notice` / `warning` / `error` / `fatal` |

### CI/CD

- **CI** runs on PRs via the shared `hassio-addons/workflows` reusable workflow.
- **Deploy** runs on push to `main` or release publication; builds and publishes the container image to GHCR.
- Dependency updates are managed by Renovate (`/.github/renovate.json`).
