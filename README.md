# n8n

Workflow automation tool.

> **STATUS: WIP** - Native build with custom patching for FreeBSD.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PUID` | User ID for the application process | `1000` |
| `PGID` | Group ID for the application process | `1000` |
| `TZ` | Timezone for the container | `UTC` |
| `S6_LOG_ENABLE` | Enable/Disable file logging | `1` |
| `S6_LOG_MAX_SIZE` | Max size per log file (bytes) | `1048576` |
| `S6_LOG_MAX_FILES` | Number of rotated log files to keep | `10` |

## Logging

This image uses `s6-log` for internal log rotation.
- **System Logs**: Captured from console and stored at `/config/logs/daemonless/n8n/`.
- **Application Logs**: Managed by the app and typically found in `/config/logs/`.
- **Podman Logs**: Output is mirrored to the console, so `podman logs` still works.

## Quick Start

```bash
podman run -d --name n8n \
  -p 5678:5678 \
  -e PUID=1000 -e PGID=1000 \
  -v /path/to/data:/config \
  ghcr.io/daemonless/n8n:latest
```

Access at: http://localhost:5678

## podman-compose

```yaml
services:
  n8n:
    image: ghcr.io/daemonless/n8n:latest
    container_name: n8n
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
      - N8N_HOST=n8n.example.com
      - WEBHOOK_URL=https://n8n.example.com/
    volumes:
      - /data/n8n:/config
    ports:
      - 5678:5678
    restart: unless-stopped
```

## Tags

| Tag | Source | Description |
|-----|--------|-------------|
| `:latest` | [Upstream Releases](https://n8n.io/) | Built from source (npm) |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | 1000 | User ID for app |
| `PGID` | 1000 | Group ID for app |
| `TZ` | UTC | Timezone |
| `N8N_ENCRYPTION_KEY` | - | Encryption key for credentials |
| `WEBHOOK_URL` | - | URL for webhooks |

## Volumes

| Path | Description |
|------|-------------|
| `/config` | n8n data (workflows, credentials, settings) |

## Ports

| Port | Description |
|------|-------------|
| 5678 | Web UI |

## Notes

- **User:** `bsd` (UID/GID set via PUID/PGID, default 1000)
- **Base:** Built on `ghcr.io/daemonless/base-image` (FreeBSD)

## Links

- [Website](https://n8n.io/)
- [GitHub](https://github.com/n8n-io/n8n)
