# Private Media Stack Setup Guide: yourdomain.com

This guide describes a reusable pattern for exposing private Docker services through Nginx Proxy Manager while keeping access limited to your local network and/or Tailscale.

## 1. Domain and DNS Setup

You can use any domain registrar and any DNS provider that supports the records and API access you need.

Recommended pattern:

- Keep your main domain, for example `yourdomain.com`
- Use a private service subdomain zone such as `home.yourdomain.com`
- Give each app its own hostname under that zone

Examples:

- `jellyfin.home.yourdomain.com`
- `sonarr.home.yourdomain.com`
- `radarr.home.yourdomain.com`

Important:

- The place where you bought the domain and the place where DNS is hosted do not have to be the same.
- What matters most for certificate automation is whether your DNS provider supports API-based DNS updates.

## 2. DNS Record Pattern

To support private services over Tailscale or local-only access, use one of these DNS models.

### Option A: Public DNS record pointing to the Tailscale IP

Create a wildcard or per-host record:

- **Type:** `A`
- **Name:** `*.home`
- **Value:** `<tailscale-ip-of-host>`

This resolves names such as `jellyfin.home.yourdomain.com` to the Tailscale IP of your server.

If your DNS provider supports traffic proxying, disable it for these records. Private Tailscale IPs should usually be set to DNS-only mode.

### Option B: Split DNS

Keep service DNS private by resolving `*.home.yourdomain.com` only from your internal DNS resolver or a DNS service reachable through Tailscale.

This is cleaner if you do not want the records publicly visible, but it requires you to operate your own DNS resolution path.

## 3. Docker Infrastructure (Nginx Proxy Manager)

The stack should be organized so that only Nginx Proxy Manager publishes host ports.

### Docker Compose Pattern

- **Network:** shared Docker bridge network such as `media-network`
- **NPM Ports:** `80`, `443`, `81`
- **Service Containers:** Jellyfin, Sonarr, Radarr, and similar apps stay on the Docker network without individual host port mappings

This gives you:

- a single ingress point
- simpler HTTPS management
- less direct host exposure

## 4. SSL Certificate Generation

If the server is not publicly exposed, use a **DNS-01 challenge** through Nginx Proxy Manager.

- **Method:** Let's Encrypt DNS Challenge
- **Domains:** `*.home.yourdomain.com`, `home.yourdomain.com`
- **Authentication:** API credentials for your DNS provider

Requirements:

- Your DNS provider must support API-based TXT record updates, or you need a compatible plugin/integration.
- NPM must be able to create `_acme-challenge` TXT records for the zone.

Cloudflare is a common choice because its API support is straightforward, but the same pattern works with any supported DNS provider.

## 5. Proxy Host Configuration

Each service is mapped in the NPM dashboard to an internal Docker hostname and port.

| Public URL | Internal Forward | Port | SSL |
| :--- | :--- | :--- | :--- |
| `jellyfin.home.yourdomain.com` | `jellyfin` | `8096` | Force SSL |
| `sonarr.home.yourdomain.com` | `sonarr` | `8989` | Force SSL |
| `radarr.home.yourdomain.com` | `radarr` | `7878` | Force SSL |

General rule:

- `service.home.yourdomain.com` forwards to `http://service:<port>` on the Docker network

## 6. Accessing Services

### Through Tailscale

1. Connect the client device to the same Tailscale tailnet.
2. Ensure the service DNS name resolves to the host's Tailscale IP or to a route that is reachable through Tailscale.
3. Open `https://service.home.yourdomain.com`.

### Through Local Network

1. Make sure local DNS resolves the service hostname to the host's LAN IP.
2. Open `https://service.home.yourdomain.com` from a device on the same network.

In both cases, Nginx Proxy Manager terminates TLS and forwards traffic privately to the Docker container.

## 7. Summary

This pattern is portable across registrars and DNS providers:

- buy the domain anywhere
- host DNS wherever API automation is easiest
- point private service names to a Tailscale IP or private IP
- use Nginx Proxy Manager as the only published entrypoint
- issue certificates with DNS-01 instead of exposing the stack publicly