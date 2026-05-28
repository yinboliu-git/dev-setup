# ============================================================
#  install-git.ps1 — 安装 Git for Windows
# ============================================================
param(
    [switch]$Force,
    [string]$Version = "2.47.1"
)

$ErrorActionPreference = "Stop"

# 检查是否已安装
if (-not $Force -and (Get-Command git.exe -ErrorAction SilentlyContinue)) {
    Write-Host "Git 已安装: $((git --version 2>&1).Trim())"
    exit 0
}

$arch = if ([Environment]::Is64BitOperatingSystem) { "64-bit" } else { "32-bit" }
$url  = "https://github.com/git-for-windows/git/releases/download/v$Version.windows.1/Git-$Version-$arch.exe"
$installer = "$env:TEMP\Git-Installer.exe"

Write-Host "下载 Git for Windows v$Version ($arch)..."
Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing

Write-Host "安装中..."
$args = @(
    '/VERYSILENT',
    '/NORESTART',
    '/NOCANCEL',
    '/SP-',
    '/CLOSEAPPLICATIONS',
    '/RESTARTAPPLICATIONS',
    '/COMPONENTS=icons,ext,ext\reg,assoc,assoc_sh'
)
Start-Process -FilePath $installer -ArgumentList $args -Wait -NoNewWindow

Remove-Item $installer -Force

# 刷新 PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

if (Get-Command git.exe -ErrorAction SilentlyContinue) {
    Write-Host "Git 安装成功: $((git --version 2>&1).Trim())"
} else {
    Write-Host "Git 安装完成，请重启终端以使 PATH 生效"
}
