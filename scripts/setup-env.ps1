# ============================================================
#  setup-env.ps1 — 环境变量配置（写入 Git Bash .bashrc）
# ============================================================
param(
    [string]$GitUser = "",
    [string]$GitEmail = "",
    [string]$ProxyUrl = "",
    [string]$ApiBaseUrl = "",
    [string]$ApiKey = "",
    [string]$ApiModel = "",
    [string]$ClaudeVersion = "2.1.150"
)

$ErrorActionPreference = "Stop"
$MARKER = "# >>> dev-setup auto config >>>"
$END    = "# <<< dev-setup auto config <<<"

$bashrc = "$env:USERPROFILE\.bashrc"
if (-not (Test-Path $bashrc)) { New-Item -ItemType File -Path $bashrc -Force | Out-Null }

$content = Get-Content $bashrc -Raw -ErrorAction SilentlyContinue
if (-not $content) { $content = "" }

# 移除旧配置
if ($content -match [regex]::Escape($MARKER)) {
    $content = $content -replace "(?s)$MARKER.*$END", ""
}

# 构建新配置块
function To-UnixPath($winPath) {
    return $winPath -replace '\\', '/' -replace '^C:', '/c'
}

$lines = @()
$lines += ""
$lines += $MARKER
$lines += "# 由 dev-setup 生成 — $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$lines += ""

# npm global path
$lines += 'export PATH="$HOME/.npm-global:$HOME/.npm-global/bin:$PATH"'
$lines += ""

# Git config
if ($GitUser) {
    $lines += "# Git 身份"
    $lines += "export GIT_AUTHOR_NAME=`"$GitUser`""
    $lines += "export GIT_COMMITTER_NAME=`"$GitUser`""
    $lines += ""
}

# Conda (如果存在)
$condaPaths = @("$env:USERPROFILE\Miniconda3", "$env:USERPROFILE\anaconda3")
foreach ($cp in $condaPaths) {
    if (Test-Path "$cp\Scripts\conda.exe") {
        $lines += "# Conda"
        $lines += "export CONDA_ROOT=`"$(To-UnixPath $cp)`""
        $lines += 'export PATH="$CONDA_ROOT:$CONDA_ROOT/Scripts:$CONDA_ROOT/Library/bin:$PATH"'
        $lines += ""
        break
    }
}

# Node.js
$nodePath = (Get-Command node.exe -ErrorAction SilentlyContinue).Source
if ($nodePath) {
    $nodeDir = To-UnixPath (Split-Path -Parent $nodePath)
    $lines += "# Node.js"
    $lines += "export NODE_HOME=`"$nodeDir`""
    $lines += 'export PATH="$NODE_HOME:$PATH"'
    $lines += ""
}

# 代理
if ($ProxyUrl) {
    $lines += "# 代理 / VPN"
    $lines += "export HTTP_PROXY=`"$ProxyUrl`""
    $lines += "export HTTPS_PROXY=`"$ProxyUrl`""
    $lines += "export http_proxy=`"$ProxyUrl`""
    $lines += "export https_proxy=`"$ProxyUrl`""
    $lines += 'export NO_PROXY="localhost,127.0.0.1,.local"'
    $lines += ""
}

# AI 后端
if ($ApiBaseUrl -and $ApiKey) {
    $lines += "# AI 后端 (Claude Code)"
    $lines += "export ANTHROPIC_BASE_URL=`"$ApiBaseUrl`""
    $lines += "export ANTHROPIC_API_KEY=`"$ApiKey`""
    if ($ApiModel) {
        $lines += "export CLAUDE_MODEL=`"$ApiModel`""
    }
    $lines += ""
}

# Claude Code alias
$lines += "alias claude=`"claude.cmd`""
$lines += ""

$lines += $END
$lines += ""

$newBlock = $lines -join "`r`n"
Set-Content -Path $bashrc -Value ($content.TrimEnd() + "`r`n" + $newBlock) -Encoding UTF8

Write-Host "环境配置已写入: $bashrc"

# 显示摘要
Write-Host ""
Write-Host "已配置的环境变量:" -ForegroundColor Yellow
if ($GitUser)     { Write-Host "  GIT_AUTHOR_NAME = $GitUser" }
if ($ProxyUrl)    { Write-Host "  HTTP_PROXY     = $ProxyUrl" }
if ($ApiBaseUrl)  { Write-Host "  ANTHROPIC_BASE_URL = $ApiBaseUrl" }
if ($ApiModel)    { Write-Host "  CLAUDE_MODEL       = $ApiModel" }
Write-Host "  ANTHROPIC_API_KEY = *** (已设置)"
Write-Host ""
Write-Host "打开 Git Bash 后生效，或执行: source ~/.bashrc"
