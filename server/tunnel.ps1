# Puts UP on a fixed address through a named Cloudflare tunnel.
#
#   .\tunnel.ps1 -Setup      once: create the tunnel and point up.atar.co at it
#   .\tunnel.ps1             every time after that: run it
#
# Why a *named* tunnel: `cloudflared tunnel --url ...` hands out a random
# trycloudflare address that changes on every restart. Every change signs
# everyone out (browser storage is per-origin) and invalidates every link and QR
# already shared. A named tunnel keeps one address forever.
param(
  [switch]$Setup,
  [string]$Hostname = 'up.atar.co',
  [string]$Name = 'up',
  [int]$Port = 3000
)

$ErrorActionPreference = 'Stop'

$cloudflared = (Get-Command cloudflared -ErrorAction SilentlyContinue)
if (-not $cloudflared) {
  Write-Host "cloudflared is not installed. Install it with:" -ForegroundColor Red
  Write-Host "    winget install --id Cloudflare.cloudflared" -ForegroundColor Yellow
  exit 1
}

# The certificate `cloudflared tunnel login` writes. Without it nothing below
# can talk to the Cloudflare account.
$cert = Join-Path $env:USERPROFILE '.cloudflared\cert.pem'
if (-not (Test-Path $cert)) {
  Write-Host "Not signed in to Cloudflare yet. Run this first:" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "    cloudflared tunnel login" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "A browser opens - pick the zone that owns $Hostname." -ForegroundColor Yellow
  exit 1
}

if ($Setup) {
  $existing = (cloudflared tunnel list 2>&1 | Select-String -SimpleMatch " $Name ")
  if ($existing) {
    Write-Host "Tunnel '$Name' already exists - keeping it." -ForegroundColor DarkGray
  } else {
    Write-Host "Creating tunnel '$Name'..." -ForegroundColor Cyan
    cloudflared tunnel create $Name
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }

  Write-Host ""
  Write-Host "Pointing $Hostname at it." -ForegroundColor Cyan
  Write-Host "This adds ONE CNAME record for $Hostname and touches nothing else -" -ForegroundColor DarkGray
  Write-Host "not the root domain, not its A record, not any other subdomain." -ForegroundColor DarkGray
  Write-Host ""
  cloudflared tunnel route dns $Name $Hostname
  if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "If that failed because a record for $Hostname already exists," -ForegroundColor Yellow
    Write-Host "delete that one record in the Cloudflare dashboard and run this again." -ForegroundColor Yellow
    Write-Host "Do NOT pass --overwrite-dns unless you know what that record was." -ForegroundColor Yellow
    exit $LASTEXITCODE
  }

  Write-Host ""
  Write-Host "Done. From now on just:  .\tunnel.ps1" -ForegroundColor Green
  Write-Host ""
}

Write-Host "UP is at  https://$Hostname" -ForegroundColor Green
Write-Host "The server must be running in the other window (.\run.ps1)." -ForegroundColor DarkGray
Write-Host ""

cloudflared tunnel run --url "http://localhost:$Port" $Name
