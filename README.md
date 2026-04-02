# Media Stack

A self-hosted media ecosystem combining automated downloading, media management, streaming, and AI-powered recommendations — all protected by a VPN kill-switch.

## Stack Components

| Service | Role | Default Port |
|---|---|---|
| [Gluetun](https://github.com/qdm12/gluetun) | VPN tunnel (WireGuard / OpenVPN) | — |
| [qBittorrent](https://github.com/linuxserver/docker-qbittorrent) | Torrent client (routed through VPN) | 8080 |
| [Prowlarr](https://github.com/Prowlarr/Prowlarr) | Indexer / tracker manager | 9696 |
| [Radarr](https://radarr.video) | Movie automation | 7878 |
| [Sonarr](https://sonarr.tv) | TV show automation | 8989 |
| [Jellyseerr](https://github.com/Fallenbagel/jellyseerr) | Media request portal | 5055 |
| [Jellyfin](https://jellyfin.org) | Media server / streaming | 8096 |
| [Bazarr](https://github.com/morpheus65535/bazarr) | Subtitle downloader | 6767 |
| [FlareSolverr](https://github.com/FlareSolverr/FlareSolverr) | Cloudflare bypass helper | 8191 |
| [Jackett](https://github.com/Jackett/Jackett) | Indexer proxy | 9117 |
| [Recommendarr](https://github.com/fingerthief/recommendarr) | AI-powered recommendations | 3232 |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Host Machine                         │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                   media-network                      │   │
│  │                                                      │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐            │   │
│  │  │ Prowlarr │  │  Radarr  │  │  Sonarr  │            │   │
│  │  │ +Jackett │  └────┬─────┘  └────┬─────┘            │   │
│  │  └────┬─────┘       │(movies)      │(tv)             │   │
│  │       │(indexers)   └─────────────┼──────────────────│   │
│  │       │                           │                  │   │
│  │  ┌────▼─────┐  ┌────▼─────┐  ┌──────────────────┐    │   │
│  │  │Jellyseerr│  │ Gluetun  │  │     Jellyfin     │    │   │
│  │  │ (seerr)  │  │  (VPN)   │  │  (media server)  │    │   │
│  │  └──────────┘  └────┬─────┘  └────┬─────────────┘    │   │
│  │                     │              │                 │   │
│  │               ┌─────▼──────┐  ┌────▼─────┐  ┌─────┐  │   │
│  │               │qBittorrent │  │  Bazarr  │  │ Rec │  │   │
│  │               │(VPN tunnel)│  │ (subs)   │  │ (AI)│  │   │
│  │               └────────────┘  └──────────┘  └─────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
│  ./media/                    ./config/                      │
│    movies/                     radarr/  sonarr/  ...        │
│    tv/                                                      │
│    downloads/complete/                                      │
│    downloads/incomplete/                                    │
└─────────────────────────────────────────────────────────────┘
```

**Key design decisions:**
- qBittorrent runs entirely inside the Gluetun network namespace — if the VPN drops, downloads stop (kill-switch).
- All services that handle media share the same `/data` mount (`./media`) so the OS can use **hardlinks** instead of copying files when Radarr/Sonarr import completed downloads.
- Internal service-to-service communication uses Docker container names (e.g. `http://radarr:7878`) — no host port exposure needed for inter-service calls.

---

## Prerequisites

### Windows 11
1. Install **Docker Desktop** ≥ 4.x with the **WSL 2 backend** enabled.
   - Download: https://docs.docker.com/desktop/install/windows-install/
   - Enable WSL 2: _Settings → General → Use WSL 2 based engine_
2. Install **WSL 2** with a Linux distribution (Ubuntu recommended):
   ```powershell
   wsl --install
   ```
3. Ensure virtualisation is enabled in BIOS (required for WSL 2).

### Linux
1. Install Docker Engine and the Compose plugin:
   ```bash
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker $USER   # log out and back in after this
   ```
2. Verify: `docker compose version`

---

## Quick Start

### 1. Clone / Download

```bash
git clone <repo-url> media-stack
cd media-stack
```

### 2. Run the Setup Script

**Linux / macOS:**
```bash
chmod +x setup.sh
./setup.sh
```

**Windows (PowerShell as Administrator):**
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\setup.ps1
```

The script creates the required directory tree and copies `.env.example` → `.env`.

### 3. Configure Environment Variables

Edit `.env` and fill in at minimum:

| Variable | Description |
|---|---|
| `VPN_PROVIDER` | Your VPN provider name (e.g. `mullvad`, `nordvpn`) |
| `VPN_TYPE` | `wireguard` (recommended) or `openvpn` |
| `WIREGUARD_PRIVATE_KEY` | WireGuard private key from your VPN provider |
| `WIREGUARD_ADDRESSES` | Assigned IP (e.g. `10.64.0.1/32`) |
| `TZ` | Your timezone (e.g. `America/New_York`) |
| `PUID` / `PGID` | Your user/group IDs (`id` command on Linux) |

> **Windows note:** You can leave `PUID`/`PGID` as `1000`. For `CONFIG_DIR` and `MEDIA_DIR`, use absolute paths with forward slashes: `C:/Users/YourName/media-stack/config`.

VPN provider-specific setup guides: https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers

---

## NordVPN Setup

NordVPN supports two modes with Gluetun. Pick one.

### Option A — OpenVPN (easiest, no key extraction)

1. Log in to your NordVPN account at https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/
2. Find **Service credentials** (username + password — these are different from your account login).
3. Set in `.env`:
   ```env
   VPN_PROVIDER=nordvpn
   VPN_TYPE=openvpn
   VPN_USER=<service username>
   VPN_PASSWORD=<service password>
   VPN_COUNTRIES=Netherlands        # or any NordVPN-supported country
   ```

### Option B — WireGuard / NordLynx (faster, recommended)

NordVPN does not expose WireGuard keys in the dashboard, so the key must be extracted once using the NordVPN CLI.

#### Step 1 — Get your private key (Linux)

```bash
# Install the NordVPN client
sh <(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh)

# Log in
nordvpn login

# Switch to NordLynx (WireGuard) technology
nordvpn set technology nordlynx

# Connect to any server (only needed to activate the WireGuard interface)
nordvpn connect

# Extract the private key
sudo wg show nordlynx private-key
# Output looks like: aBcDeFgH1234...  (a 44-character base64 string)

# Disconnect — Gluetun will manage connections from here
nordvpn disconnect
nordvpn set technology openvpn   # restore default if you wish
```

> **Windows / macOS alternative:** Run the commands above inside WSL (Windows) or a temporary Linux Docker container that has the NordVPN CLI installed.

#### Step 2 — Configure `.env`

```env
VPN_PROVIDER=nordvpn
VPN_TYPE=wireguard
WIREGUARD_PRIVATE_KEY=<paste the 44-char key from the step above>
# Leave WIREGUARD_ADDRESSES blank — Gluetun auto-assigns it for NordVPN
WIREGUARD_ADDRESSES=
VPN_COUNTRIES=Netherlands        # P2P-friendly country recommended for downloads
```

#### Step 3 — Start and verify

```bash
docker compose up -d

# Confirm the VPN IP is a NordVPN exit node (should NOT be your real IP)
docker exec gluetun wget -qO- https://ifconfig.me

# Watch Gluetun logs for "Connected" confirmation
docker compose logs -f gluetun
```

### Recommended NordVPN countries for P2P downloads

| Country | Notes |
|---|---|
| Netherlands | NordVPN's largest P2P fleet |
| Switzerland | No data retention laws |
| Romania | No data retention laws |
| Sweden | Good speeds, large fleet |

Set via: `VPN_COUNTRIES=Netherlands` in `.env`.

---

### 4. Start the Stack

```bash
docker compose up -d
```

Check logs:
```bash
docker compose logs -f gluetun        # verify VPN is connected
docker compose logs -f qbittorrent    # verify torrent client started
```

---

## Service URLs

Once running, access each service at:

| Service | URL | Default Credentials |
|---|---|---|
| qBittorrent | http://localhost:8080 | `admin` / `adminadmin` |
| Prowlarr | http://localhost:9696 | Set on first run |
| Radarr | http://localhost:7878 | Set on first run |
| Sonarr | http://localhost:8989 | Set on first run |
| Jellyseerr | http://localhost:5055 | Set on first run |
| Jellyfin | http://localhost:8096 | Set on first run |
| Bazarr | http://localhost:6767 | Set on first run |
| SABnzbd | http://localhost:8085 | Set on first run |
| Jackett | http://localhost:9117 | Set on first run |
| FlareSolverr | http://localhost:8191 | — |
| Recommendarr | http://localhost:3232 | Set on first run |

> **Important:** Change the default qBittorrent password immediately after first login.

---

## Post-Installation Configuration

### qBittorrent
1. Log in at http://localhost:8080 (admin / adminadmin).
2. Go to **Tools → Options → Downloads**:
   - Default save path: `/data/downloads/complete`
   - Keep incomplete torrents in: `/data/downloads/incomplete`
3. Go to **Tools → Options → Web UI** and change the password.

### Prowlarr
1. Open http://localhost:9696 and create an admin account.
2. Go to **Indexers → Add Indexer** and add your preferred public/private trackers.
3. Go to **Settings → Apps** and add **Radarr** and **Sonarr** as applications:
   - Radarr URL: `http://radarr:7878`
   - Sonarr URL: `http://sonarr:8989`
   - API keys: copy from each app's _Settings → General_ page.

### Radarr
1. Open http://localhost:7878 and create an admin account.
2. **Settings → Media Management → Root Folders**: add `/data/movies`.
3. **Settings → Download Clients → Add**: choose qBittorrent:
   - Host: `gluetun`  ← qBittorrent shares the VPN container's network
   - Port: `8080`
   - Category: `radarr`
4. Prowlarr will automatically push indexers to Radarr (configured in the Prowlarr step above).

### Sonarr
1. Open http://localhost:8989 and create an admin account.
2. **Settings → Media Management → Root Folders**: add `/data/tv`.
3. **Settings → Download Clients → Add**: choose qBittorrent:
   - Host: `gluetun`
   - Port: `8080`
   - Category: `sonarr`

### SABnzbd (optional, for Usenet indexers like NZBGeek)
1. Open http://localhost:8085 and complete first-run setup.
2. Configure your Usenet provider server host/port/credentials in SABnzbd.
3. In Sonarr, add SABnzbd as a download client:
   - Host: `sabnzbd`
   - Port: `8080`
   - API Key: copy from SABnzbd Settings
4. In Prowlarr, if using NZBGeek, ensure NZBGeek is set as a Usenet indexer and the app sync profile includes Sonarr.

### Jellyfin
1. Open http://localhost:8096 and complete the setup wizard.
2. Add two libraries in the wizard (or later via **Dashboard → Libraries**):
   - **Movies**: path `/data/movies`
   - **TV Shows**: path `/data/tv`
3. Copy your **API Key** from _Dashboard → API Keys_ — you will need it for Jellyseerr and Recommendarr.

### Jellyseerr
1. Open http://localhost:5055 and sign in with your Jellyfin account.
2. Connect to Jellyfin: `http://jellyfin:8096`
3. Connect to Radarr: `http://radarr:7878`, set root folder `/data/movies`.
4. Connect to Sonarr: `http://sonarr:8989`, set root folder `/data/tv`.

### Recommendarr
1. Open http://localhost:3232.
2. Enter your Jellyfin URL (`http://jellyfin:8096`) and API key.
3. Configure your preferred AI provider (OpenAI, Ollama, etc.) and API key.
4. Recommendarr will analyse your Jellyfin library and provide personalised suggestions.

### Bazarr
1. Open http://localhost:6767 and set up an admin account.
2. **Settings → Apps**: Add Radarr and Sonarr.
   - Radarr: URL `http://radarr:7878`, API key from Radarr.
   - Sonarr: URL `http://sonarr:8989`, API key from Sonarr.
   - Paths: `/data/movies` and `/data/tv`.
3. **Settings → Subtitles**: Add providers like OpenSubtitles (with credentials).
4. **Settings → Languages**: Create profiles (e.g., English) and assign to series/movies.
5. **Settings → Options**: Enable automatic search/download/scan.

### FlareSolverr
- No UI setup needed; it runs as a helper for Jackett.
- Accessible at http://localhost:8191 for status checks.

### Jackett
1. Open http://localhost:9117 and set up an admin account.
2. **System → FlareSolverr**: Enable and set URL to `http://flaresolverr:8191`.
3. **Indexers**: Add indexers (e.g., 1337x, TorrentGalaxyClone).
4. Test each indexer to ensure it works with FlareSolverr.
5. In Prowlarr, add Torznab indexers using Jackett's feed URLs.

---

## Directory Structure

```
media-stack/
├── docker-compose.yml      # All service definitions
├── .env.example            # Environment template (copy to .env)
├── .env                    # Your local config (NOT committed to git)
├── setup.sh                # Bootstrap script (Linux/macOS)
├── setup.ps1               # Bootstrap script (Windows)
├── config/                 # Per-service configuration (auto-created)
│   ├── gluetun/
│   ├── qbittorrent/
│   ├── prowlarr/
│   ├── radarr/
│   ├── sonarr/
│   ├── jellyseerr/
│   ├── jellyfin/
│   ├── bazarr/
│   ├── jackett/
│   ├── flaresolverr/
│   └── recommendarr/
└── media/                  # All media and downloads
    ├── movies/             # Radarr-managed movies
    ├── tv/                 # Sonarr-managed TV shows
    └── downloads/
        ├── complete/       # Completed torrents (Radarr/Sonarr import from here)
        └── incomplete/     # In-progress torrents
```

---

## Common Operations

```bash
# Start all services
docker compose up -d

# Stop all services (data preserved)
docker compose down

# Restart a single service
docker compose restart radarr

# View logs (all services)
docker compose logs -f

# View logs for one service
docker compose logs -f jellyfin

# View logs for subtitle/indexer services
docker compose logs -f bazarr
docker compose logs -f jackett
docker compose logs -f flaresolverr

# Pull latest images and recreate containers
docker compose pull
docker compose up -d --force-recreate

# Check VPN is working (should show VPN IP, not your real IP)
docker exec gluetun wget -qO- https://ifconfig.me
```

---

## Hardware-Accelerated Transcoding (Optional)

For smoother streaming, enable GPU transcoding in Jellyfin by uncommenting the
relevant section in `docker-compose.yml`:

**Intel / AMD (Linux):**
```yaml
devices:
  - /dev/dri:/dev/dri
```
Then in Jellyfin Dashboard → Playback → Transcoding, select **Intel QuickSync** or **AMD AMF**.

**NVIDIA (Linux):**
```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: 1
          capabilities: [gpu]
```
Requires the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html).

**Windows:** Docker Desktop with WSL 2 supports GPU passthrough. See [Docker GPU docs](https://docs.docker.com/desktop/gpu/).

---

## Backup

The `config/` directory contains all service settings. Back it up regularly:

```bash
# Create a timestamped backup
tar -czf "backup-$(date +%Y%m%d).tar.gz" config/
```

Media files (`media/`) do not need to be backed up unless you want to avoid re-downloading.

---

## Troubleshooting

### VPN not connecting
- Check `docker compose logs gluetun` for errors.
- Verify `WIREGUARD_PRIVATE_KEY` and `WIREGUARD_ADDRESSES` in `.env`.
- Some providers require specific `VPN_REGIONS` or `VPN_COUNTRIES` values.
- See provider-specific docs: https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers

### qBittorrent won't start / not accessible
- qBittorrent starts only after Gluetun is healthy. Watch: `docker compose logs -f gluetun`.
- The WebUI is available at the host through the **gluetun** container port, not qbittorrent directly.

### Permission errors on media files (Linux)
```bash
# Adjust to match your PUID/PGID from .env
sudo chown -R 1000:1000 media/ config/
```

### Radarr/Sonarr can't connect to qBittorrent
- Use **Host: `gluetun`** (not `qbittorrent`) in the download client settings.
  qBittorrent shares the VPN container's network, so it is only reachable via the gluetun hostname.

### Port conflict
- Edit the relevant `_PORT` variable in `.env` and restart: `docker compose up -d`.

### Windows: `/dev/net/tun` error
- Ensure Docker Desktop is using the **WSL 2** backend (not Hyper-V).
- Try restarting Docker Desktop and WSL: `wsl --shutdown`.

---

## Updating Services

```bash
docker compose pull          # download latest images
docker compose up -d         # recreate containers with new images
docker image prune -f        # remove old images to free disk space
```

>