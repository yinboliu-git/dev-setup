# ============================================================
#  install-node.ps1 — Install Node.js LTS
# ============================================================
param(
    [switch]$Force,
    [string]$Version = "20.18.0"
)

$ErrorActionPreference = "Stop"

if (-not $Force -and (Get-Command node.exe -ErrorAction SilentlyContinue)) {
    Write-Host "Node.js already installed: $((node --version 2>&1).Trim())"
    exit 0
}

# Try winget first
$hasWinget = Get-Command winget.exe -ErrorAction SilentlyContinue
if ($hasWinget) {
    Write-Host "Installing Node.js LTS via winget..."
    winget install --id OpenJS.NodeJS.LTS -e --source winget --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -eq 0) {
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Host "Node.js installed: $((node --version 2>&1).Trim())"
        exit 0
    }
    Write-Host "winget failed, falling back to direct download..."
}

# Direct download
$url = "https://nodejs.org/dist/v$Version/node-v$Version-x64.msi"
$installer = "$env:TEMP\NodeJS-Installer.msi"

Write-Host "Downloading Node.js v$Version ..."
Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing

Write-Host "Installing..."
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i","`"$installer`"","/qn","/norestart" -Wait -NoNewWindow

Remove-Item $installer -Force

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

if (Get-Command node.exe -ErrorAction SilentlyContinue) {
    Write-Host "Node.js installed: $((node --version 2>&1).Trim())"
    Write-Host "npm version: $((npm --version 2>&1).Trim())"
} else {
    Write-Host "Node.js installed. Restart terminal for PATH to take effect."
}

