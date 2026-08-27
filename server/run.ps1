# Starts the UP server and prints the tunnel command.
# Run from this folder:  .\run.ps1
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
Write-Host ""
Write-Host "In a SECOND PowerShell window, expose it to your phone with:" -ForegroundColor Cyan
Write-Host "    cloudflared tunnel --url http://localhost:3000" -ForegroundColor Yellow
Write-Host ""

node src/server.js
