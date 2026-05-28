# ============================================================
#  install-claude.ps1 — 安装 Claude Code (via npm)
# ============================================================
param(
    [string]$Version = "2.1.150",
    [string]$ProxyUrl = "",
    [switch]$Skip
)

$ErrorActionPreference = "Stop"

if ($Skip) {
    Write-Host "已跳过 Claude Code 安装"
    exit 0
}

# 检查 npm
if (-not (Get-Command npm.exe -ErrorAction SilentlyContinue)) {
    Write-Error "npm 未安装或不在 PATH 中，请先安装 Node.js"
    exit 1
}

# 配置 npm prefix
$npmPrefix = "$env:USERPROFILE\.npm-global"
if (-not (Test-Path $npmPrefix)) {
    New-Item -ItemType Directory -Path $npmPrefix -Force | Out-Null
}
npm config set prefix $npmPrefix

# 代理配置
if ($ProxyUrl) {
    Write-Host "配置 npm 代理: $ProxyUrl"
    npm config set proxy $ProxyUrl
    npm config set https-proxy $ProxyUrl
}

# 安装
$package = "@anthropic-ai/claude-code@$Version"
Write-Host "安装 $package ..."
npm install -g $package

if ($LASTEXITCODE -eq 0) {
    $ver = (& "$npmPrefix\claude.cmd" --version 2>&1).Trim()
    Write-Host "Claude Code 安装成功: $ver"
    Write-Host "二进制路径: $npmPrefix\node_modules\@anthropic-ai\claude-code"
} else {
    Write-Error "安装失败 (exit code: $LASTEXITCODE)"
    exit 1
}
