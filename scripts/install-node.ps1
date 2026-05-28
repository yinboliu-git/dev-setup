# ============================================================
#  install-node.ps1 — 安装 Node.js LTS
# ============================================================
param(
    [switch]$Force,
    [string]$Version = "20.18.0"
)

$ErrorActionPreference = "Stop"

if (-not $Force -and (Get-Command node.exe -ErrorAction SilentlyContinue)) {
    Write-Host "Node.js 已安装: $((node --version 2>&1).Trim())"
    exit 0
}

# 尝试 winget 优先
$hasWinget = Get-Command winget.exe -ErrorAction SilentlyContinue
if ($hasWinget) {
    Write-Host "通过 winget 安装 Node.js LTS..."
    winget install --id OpenJS.NodeJS.LTS -e --source winget --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -eq 0) {
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Host "Node.js 安装成功: $((node --version 2>&1).Trim())"
        exit 0
    }
    Write-Host "winget 安装失败，回退到直接下载..."
}

# 直接下载
$url = "https://nodejs.org/dist/v$Version/node-v$Version-x64.msi"
$installer = "$env:TEMP\NodeJS-Installer.msi"

Write-Host "下载 Node.js v$Version ..."
Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing

Write-Host "安装中..."
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i","`"$installer`"","/qn","/norestart" -Wait -NoNewWindow

Remove-Item $installer -Force

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

if (Get-Command node.exe -ErrorAction SilentlyContinue) {
    Write-Host "Node.js 安装成功: $((node --version 2>&1).Trim())"
    Write-Host "npm 版本: $((npm --version 2>&1).Trim())"
} else {
    Write-Host "Node.js 安装完成，请重启终端以使 PATH 生效"
}
