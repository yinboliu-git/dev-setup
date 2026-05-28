# ============================================================
#  install-conda.ps1 — 安装 Miniconda
# ============================================================
param(
    [switch]$Force,
    [string]$InstallPath = "$env:USERPROFILE\Miniconda3"
)

$ErrorActionPreference = "Stop"

if (-not $Force -and (Get-Command conda.exe -ErrorAction SilentlyContinue)) {
    Write-Host "Conda 已安装: $((conda --version 2>&1).Trim())"
    exit 0
}

$url  = "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe"
$installer = "$env:TEMP\Miniconda3-Installer.exe"

Write-Host "下载 Miniconda..."
Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing

Write-Host "安装到 $InstallPath ..."
Start-Process -FilePath $installer -ArgumentList "/S","/InstallationType=JustMe","/RegisterPython=0","/AddToPath=0","/D=$InstallPath" -Wait -NoNewWindow

Remove-Item $installer -Force

# 添加到当前会话 PATH
$env:Path = "$InstallPath;$InstallPath\Scripts;$InstallPath\Library\bin;$env:Path"

if (Test-Path "$InstallPath\Scripts\conda.exe") {
    Write-Host "Miniconda 安装成功: $InstallPath"
    & "$InstallPath\Scripts\conda.exe" --version
} else {
    Write-Host "安装可能未完成，请检查 $InstallPath"
}
