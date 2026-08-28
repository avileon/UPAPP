# Starts UP: fetches the latest web build, then runs the server.
# Run from this folder:  .\run.ps1
#
#   .\run.ps1            fetch the web app if it is missing, then start
#   .\run.ps1 -Update    fetch it again even if it is already there
#   .\run.ps1 -NoWeb     skip the fetch entirely (API only)
param(
  [switch]$Update,
  [switch]$NoWeb
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$node = (Get-Command node -ErrorAction SilentlyContinue)
if (-not $node) {
  Write-Host "Node is not installed. Get Node 22 LTS from https://nodejs.org" -ForegroundColor Red
  exit 1
}

$version = (node --version) -replace '^v', ''
$major = [int]($version -split '\.')[0]
$minor = [int]($version -split '\.')[1]
if ($major -lt 22 -or ($major -eq 22 -and $minor -lt 5)) {
  Write-Host "Node $version is too old. This server needs 22.5 or newer (it uses the built-in SQLite)." -ForegroundColor Red
  exit 1
}
Write-Host "Node $version - OK" -ForegroundColor Green

# --- the signing key -------------------------------------------------------
# Generated once and kept. Without this the server invents a new key on every
# start, which signs every user out each time you restart it.
$secretFile = Join-Path $PSScriptRoot '.jwt-secret'
if (-not (Test-Path $secretFile)) {
  $bytes = New-Object byte[] 32
  [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
  ($bytes | ForEach-Object { $_.ToString('x2') }) -join '' | Set-Content -NoNewline $secretFile
  Write-Host "Created a signing key in server\.jwt-secret" -ForegroundColor DarkGray
}
$env:JWT_SECRET = (Get-Content -Raw $secretFile).Trim()

# --- the web app -----------------------------------------------------------
# Built by GitHub Actions on every push and published with the release, so
# there is no Flutter toolchain needed on this machine.
$public = Join-Path $PSScriptRoot 'public'
$haveWeb = Test-Path (Join-Path $public 'index.html')

if (-not $NoWeb -and ($Update -or -not $haveWeb)) {
  $url = 'https://github.com/avileon/UPAPP/releases/latest/download/web.zip'
  $zip = Join-Path $env:TEMP 'up-web.zip'
  Write-Host "Fetching the web app..." -ForegroundColor Cyan
  try {
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    if (Test-Path $public) { Remove-Item -Recurse -Force $public }
    New-Item -ItemType Directory -Path $public | Out-Null
    Expand-Archive -Path $zip -DestinationPath $public -Force
    Remove-Item $zip -Force
    $haveWeb = Test-Path (Join-Path $public 'index.html')
    Write-Host "Web app ready" -ForegroundColor Green
  } catch {
    Write-Host "Could not fetch the web app: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "The API will still run. Re-run with -Update to try again." -ForegroundColor Yellow
  }
}

Write-Host ""
if ($haveWeb) {
  Write-Host "In a SECOND PowerShell window, put it on the internet with:" -ForegroundColor Cyan
  Write-Host "    cloudflared tunnel --url http://localhost:3000" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "Then open the address it prints. That one link is the whole app -" -ForegroundColor Cyan
  Write-Host "no install, works on iPhone too. Share it and you are testing." -ForegroundColor Cyan
} else {
  Write-Host "No web build present - the API is running on its own." -ForegroundColor Yellow
  Write-Host "    cloudflared tunnel --url http://localhost:3000" -ForegroundColor Yellow
}
Write-Host ""

node src/server.js
