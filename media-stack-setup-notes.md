# Media Stack Setup Notes

This document covers the setup and troubleshooting notes for the media stack, including Radarr, Sonarr, Prowlarr, qBittorrent, Bazarr, Jellyfin, FlareSolverr, and Jackett.

## qBittorrent Configuration
- **Hostname in Radarr/Sonarr**: Use `gluetun` (not `qbittorrent`) because qBittorrent shares the VPN container's network namespace.
- **Download Paths**:
  - Default Save Path: `/data/downloads/complete`
  - Keep incomplete torrents in: `/data/downloads/incomplete`
- **Port**: 8080
- **Category**: `radarr` for movies, `sonarr` for TV shows.
- **Credentials**: Default admin/adminadmin; change immediately.

## Prowlarr Setup
- **Purpose**: Indexer manager for Radarr and Sonarr.
- **URL**: http://localhost:9696
- **Add Apps**:
  - Radarr: URL `http://radarr:7878`, API key from Radarr Settings > General > Security.
  - Sonarr: URL `http://sonarr:8989`, API key from Sonarr.
  - Sync Level: Full Sync.
- **Add Indexers**: TorrentGalaxyClone, etc. Map categories (Movies: 2000, TV: 5000+).
- **Sync**: Settings > Apps > Sync App Indexers to push to Radarr/Sonarr.
- **Troubleshooting**: API key mismatch (401), category mapping (no results), Cloudflare blocks (use Jackett/FlareSolverr).

## Radarr Setup
- **URL**: http://localhost:7878
- **Root Folders**: Add `/data/movies`.
- **Download Client**: qBittorrent with Host `gluetun`, Port 8080, Category `radarr`.
- **Indexers**: Automatically synced from Prowlarr; test them.
- **Profiles**: Set quality profiles (e.g., HD-1080p).
- **Testing**: Add a movie, search for releases, verify download in qBittorrent.

## Sonarr Setup
- **URL**: http://localhost:8989
- **Root Folders**: Add `/data/tv`.
- **Download Client**: qBittorrent with Host `gluetun`, Port 8080, Category `sonarr`.
- **Indexers**: Synced from Prowlarr.
- **Series**: Monitor all episodes, enable search.
- **Troubleshooting**: If no downloads, check Prowlarr sync, indexer categories, and series settings.

## Bazarr Setup
- **URL**: http://localhost:6767
- **Purpose**: Subtitle downloader for Radarr/Sonarr.
- **Add Apps**: Radarr and Sonarr with API keys and paths (`/data/movies`, `/data/tv`).
- **Language Profiles**: Create profiles (e.g., English) and assign to movies/series.
- **Providers**: Add OpenSubtitles with credentials.
- **Auto Settings**: Enable automatic search/download/scan.
- **Troubleshooting**: "Unknown profile" (reassign), search not enabled (check profile/provider), queued forever (auth/rate limit).

## Jellyfin Setup
- **URL**: http://localhost:8096
- **Libraries**: Add Movies (`/data/movies`), TV Shows (`/data/tv`).
- **Scanning**: Enable real-time monitoring; manual scan via Dashboard > Libraries.
- **Subtitles**: Use Bazarr or Jellyfin plugin (OpenSubtitles); avoid direct plugin if format errors.
- **Troubleshooting**: Library not updating (scan manually), subtitles invalid (use Bazarr).

## FlareSolverr and Jackett Setup
- **FlareSolverr**: Bypasses Cloudflare for indexers. URL: http://localhost:8191
- **Jackett**: Proxy for indexers. URL: http://localhost:9117
  - Enable FlareSolverr in Jackett: URL `http://flaresolverr:8191`
  - Add indexers (e.g., 1337x) and test.
- **Prowlarr Integration**: Add Torznab indexers from Jackett (copy feed URL).
- **Troubleshooting**: Indexer fails (enable FlareSolverr in Jackett), Prowlarr no results (test Jackett indexer first).

## General Troubleshooting
- **API Keys**: Ensure matching between services (Prowlarr ↔ Radarr/Sonarr, Bazarr ↔ Radarr/Sonarr).
- **Paths**: Use container paths (`/data/...`) consistently.
- **Logs**: Check `docker compose logs -f <service>` for errors.
- **Connectivity**: Test with curl (e.g., `docker compose exec prowlarr curl -Is http://radarr:7878/api/v3/health?apikey=<key>`).
- **VPN**: qBittorrent traffic routed through Gluetun; verify VPN IP.
- **Updates**: `docker compose pull` and `up -d` for latest images.

## Common Issues
- **No indexers in Radarr/Sonarr**: Prowlarr sync failed; check API keys and categories.
- **Downloads not starting**: Download client config wrong; test connection.
- **Subtitles not downloading**: Bazarr profile/provider issues; check OpenSubtitles auth.
- **Cloudflare blocks**: Use Jackett + FlareSolverr instead of direct indexers.
- **Library not scanning**: Enable real-time monitoring or manual scan in Jellyfin.

## Quick Start Checklist
1. Run `docker compose up -d`.
2. Configure VPN in Gluetun (.env).
3. Set up Prowlarr indexers and apps.
4. Configure Radarr/Sonarr download clients and root folders.
5. Add Bazarr apps and providers.
6. Set up Jackett with FlareSolverr for blocked indexers.
7. Test downloads and subtitles.
8. Scan Jellyfin libraries.
2. Search for releases; choose one from the indexer.
3. Verify download starts in qBittorrent.
4. Once complete, Radarr should import to `/data/movies` using hardlinks.

## Additional Notes
- All services share the same `/data` mount for efficient file handling (hardlinks instead of copies).
- VPN kill-switch: qBittorrent stops if VPN drops.
- Change default qBittorrent password immediately.