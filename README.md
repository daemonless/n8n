# n8n

Workflow automation tool on FreeBSD.

| | |
|---|---|
| **Port** | 5678 |
| **Registry** | `ghcr.io/daemonless/n8n` |
| **Source** | [https://github.com/n8n-io/n8n](https://github.com/n8n-io/n8n) |
| **Website** | [https://n8n.io/](https://n8n.io/) |

## Deployment

### Podman Compose

```yaml
services:
  n8n:
    image: ghcr.io/daemonless/n8n:latest
    container_name: n8n
    environment:
      - N8N_ENCRYPTION_KEY=your-encryption-key-here
      - PUID=1000
      - PGID=1000
      - TZ=UTC
    volumes:
      - /path/to/containers/n8n:/config
    ports:
      - 5678:5678
    restart: unless-stopped
```

### Podman CLI

```bash
podman run -d --name n8n \
  -p 5678:5678 \
  -e N8N_ENCRYPTION_KEY=your-encryption-key-here \
  -e PUID=@PUID@ \
  -e PGID=@PGID@ \
  -e TZ=@TZ@ \
  -v /path/to/containers/n8n:/config \ 
  ghcr.io/daemonless/n8n:latest
```
Access at: `http://localhost:5678`

### Ansible

```yaml
- name: Deploy n8n
  containers.podman.podman_container:
    name: n8n
    image: ghcr.io/daemonless/n8n:latest
    state: started
    restart_policy: always
    env:
      N8N_ENCRYPTION_KEY: "your-encryption-key-here"
      PUID: "1000"
      PGID: "1000"
      TZ: "UTC"
    ports:
      - "5678:5678"
    volumes:
      - "/path/to/containers/n8n:/config"
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `N8N_ENCRYPTION_KEY` | `your-encryption-key-here` | Encryption key for credentials (keep safe!) |
| `PUID` | `1000` | User ID for the application process |
| `PGID` | `1000` | Group ID for the application process |
| `TZ` | `UTC` | Timezone for the container |

### Volumes

| Path | Description |
|------|-------------|
| `/config` | Configuration directory (database, workflows) |

### Ports

| Port | Protocol | Description |
|------|----------|-------------|
| `5678` | TCP | Web UI |

## Notes

- **User:** `bsd` (UID/GID set via PUID/PGID)
- **Base:** Built on `ghcr.io/daemonless/base` (FreeBSD)