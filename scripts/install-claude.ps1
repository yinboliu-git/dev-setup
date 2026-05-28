# ============================================================
#  install-claude.ps1 — Install Claude Code (via npm)
# ============================================================
param(
    [string]$Version = "2.1.150",
    [string]$ProxyUrl = "",
    [switch]$Skip
)

$ErrorActionPreference = "Stop"

if ($Skip) {
    Write-Host "Claude Code install skipped"
    exit 0
}

if (-not (Get-Command npm.exe -ErrorAction SilentlyContinue)) {
    Write-Error "npm not found. Please install Node.js first."
    exit 1
}

$npmPrefix = "$env:USERPROFILE\.npm-global"
if (-not (Test-Path $npmPrefix)) {
    New-Item -ItemType Directory -Path $npmPrefix -Force | Out-Null
}
npm config set prefix $npmPrefix

if ($ProxyUrl) {
    Write-Host "Setting npm proxy: $ProxyUrl"
    npm config set proxy $ProxyUrl
    npm config set https-proxy $ProxyUrl
}

$package = "@anthropic-ai/claude-code@$Version"
Write-Host "Installing $package ..."
npm install -g $package

if ($LASTEXITCODE -eq 0) {
    $ver = (& "$npmPrefix\claude.cmd" --version 2>&1).Trim()
    Write-Host "Claude Code installed: $ver"
    Write-Host "Binary: $npmPrefix\node_modules\@anthropic-ai\claude-code"
} else {
    Write-Error "Install failed (exit code: $LASTEXITCODE)"
    exit 1
}

