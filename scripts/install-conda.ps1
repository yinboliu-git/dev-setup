# ============================================================
#  install-conda.ps1 — Install Miniconda
# ============================================================
param(
    [switch]$Force,
    [string]$InstallPath = "$env:USERPROFILE\Miniconda3"
)

$ErrorActionPreference = "Stop"

if (-not $Force -and (Get-Command conda.exe -ErrorAction SilentlyContinue)) {
    Write-Host "Conda already installed: $((conda --version 2>&1).Trim())"
    exit 0
}

$url  = "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe"
$installer = "$env:TEMP\Miniconda3-Installer.exe"

Write-Host "Downloading Miniconda..."
Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing

Write-Host "Installing to $InstallPath ..."
Start-Process -FilePath $installer -ArgumentList "/S","/InstallationType=JustMe","/RegisterPython=0","/AddToPath=0","/D=$InstallPath" -Wait -NoNewWindow

Remove-Item $installer -Force

$env:Path = "$InstallPath;$InstallPath\Scripts;$InstallPath\Library\bin;$env:Path"

if (Test-Path "$InstallPath\Scripts\conda.exe") {
    Write-Host "Miniconda installed: $InstallPath"
    & "$InstallPath\Scripts\conda.exe" --version
} else {
    Write-Host "Install may be incomplete, check: $InstallPath"
}

