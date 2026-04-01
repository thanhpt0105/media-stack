# =============================================================================
# setup.ps1 - Media Stack bootstrap script (Windows 11)
# =============================================================================
# Run in PowerShell:
#   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
#   .\setup.ps1
# =============================================================================

$ErrorActionPreference = "Stop"

function Info    { param($msg) Write-Host "[INFO]  $msg" -ForegroundColor Green }
function Warning { param($msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }

# -----------------------------------------------------------------------------
# 1. Create directory structure
# -----------------------------------------------------------------------------
Info "Creating directory structure..."

$dirs = @(
    "config\gluetun",
    "config\qbittorrent",
    "config\prowlarr",
    "config\radarr",
    "config\sonarr",
    "config\jellyseerr",
    "config\jellyfin",
    "config\recommendarr",
    "media\movies",
    "media\tv",
    "media\downloads\complete",
    "media\downloads\incomplete"
)

foreach ($dir in $dirs) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Info "  Created: $dir"
}

# -----------------------------------------------------------------------------
# 2. Copy .env.example → .env
# -----------------------------------------------------------------------------
if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Info ".env created — open it and fill in your VPN credentials and paths."
} else {
    Warning ".env already exists, skipping copy."
}

# -----------------------------------------------------------------------------
# 3. Check Docker Desktop is running
# -----------------------------------------------------------------------------
if (-not (Get-Command "docker" -ErrorAction SilentlyContinue)) {
    Warning "Docker not found. Install Docker Desktop: https://docs.docker.com/desktop/windows/"
} else {
    $dockerRunning = docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Warning "Docker Desktop is not running. Start it before running 'docker compose up -d'."
    } else {
        Info "Docker Desktop is running."
    }
}

# -----------------------------------------------------------------------------
Write-Host ""
Info "Setup complete!"
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Cyan
Write-Host "  1. Edit .env  — add your VPN credentials and adjust paths/ports"
Write-Host "  2. docker compose up -d   — start all services"
Write-Host "  3. Open the service URLs listed in README.md"
Write-Host ""
Write-Host "  Windows tip: For best performance, store your media on a drive" -ForegroundColor Yellow
Write-Host "  formatted as NTFS and use absolute paths in .env (e.g. D:/media)." -ForegroundColor Yellow
Write-Host ""
