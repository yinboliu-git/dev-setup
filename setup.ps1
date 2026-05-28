# ============================================================
#  setup.ps1 — 开发环境一键安装主脚本
#  在 Git Bash (MinGW) 基础上安装全栈 AI 开发环境
# ============================================================
param (
    [switch]$SkipGit,
    [switch]$SkipConda,
    [switch]$SkipNode,
    [switch]$SkipClaude,
    [string]$ClaudeVersion = "2.1.150"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ---- 全局状态 ----
$Global:InstallLog = @()
$Global:Config = @{}

# ---- 常量 ----
$MINICONDA_URL = "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe"
$NODE_URL      = "https://nodejs.org/dist/v20.18.0/node-v20.18.0-x64.msi"
$GIT_URL       = "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.1/Git-2.47.1-64-bit.exe"

function Write-Step { param($msg) Write-Host "`n==> $msg" -ForegroundColor Cyan; $Global:InstallLog += $msg }
function Write-OK   { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow }
function Write-Err  { param($msg) Write-Host "  [ERR] $msg" -ForegroundColor Red }

# ============================================================
#  工具检测
# ============================================================
function Test-Command { param($cmd) return (Get-Command $cmd -ErrorAction SilentlyContinue) -ne $null }

function Get-InstalledVersion {
    param($cmd, $args)
    try {
        $output = & $cmd $args 2>&1 | Out-String
        return $output.Trim()
    } catch { return $null }
}

function Detect-Environment {
    Write-Step "检测当前环境..."

    $Global:Config.IsWin11       = [Environment]::OSVersion.Version.Build -ge 22000
    $Global:Config.HasWinget     = Test-Command winget.exe
    $Global:Config.HasGit        = Test-Command git.exe
    $Global:Config.HasConda      = Test-Command conda.exe
    $Global:Config.HasNode       = Test-Command node.exe
    $Global:Config.HasNpm        = Test-Command npm.exe
    $Global:Config.HasClaude     = Test-Command claude.exe

    # Git Bash 路径
    $Global:Config.GitBashPath = ""
    if ($Global:Config.HasGit) {
        $gitPath = (Get-Command git.exe).Source
        $gitDir  = Split-Path -Parent (Split-Path -Parent $gitPath)
        $bashPath = Join-Path $gitDir "bin\bash.exe"
        if (Test-Path $bashPath) { $Global:Config.GitBashPath = $bashPath }
    }

    # Git Bash 的 home 目录
    $Global:Config.GitBashHome = "$env:USERPROFILE"
    $Global:Config.BashrcPath  = Join-Path $Global:Config.GitBashHome ".bashrc"

    Write-OK "Windows 11: $($Global:Config.IsWin11)"
    Write-OK "winget: $($Global:Config.HasWinget)"
    Write-OK "Git: $($Global:Config.HasGit)"
    if ($Global:Config.HasGit) {
        $ver = (git --version 2>&1).Trim()
        Write-OK "  $ver ($(Split-Path -Parent (Get-Command git.exe).Source))"
    }
    Write-OK "Conda: $($Global:Config.HasConda)"
    Write-OK "Node.js: $($Global:Config.HasNode)"
    Write-OK "npm: $($Global:Config.HasNpm)"
    Write-OK "Claude Code: $($Global:Config.HasClaude)"
    if ($Global:Config.HasClaude) {
        $ver = (claude --version 2>&1).Trim()
        Write-OK "  $ver"
    }
    Write-OK "Git Bash: $(if ($Global:Config.GitBashPath) { $Global:Config.GitBashPath } else { '未找到' })"
}

# ============================================================
#  用户交互式配置收集
# ============================================================
function Invoke-ConfigWizard {
    Write-Step "配置向导"

    # --- Git 配置 ---
    Write-Host "`n  --- Git 配置 ---" -ForegroundColor Yellow
    if (-not $Global:Config.GitUser) {
        $Global:Config.GitUser = Read-Host "  Git 用户名"
    }
    if (-not $Global:Config.GitEmail) {
        $Global:Config.GitEmail = Read-Host "  Git 邮箱"
    }

    # --- 代理 / VPN 配置 ---
    Write-Host "`n  --- 代理 / VPN 配置 (留空跳过) ---" -ForegroundColor Yellow
    if ($null -eq $Global:Config.ProxyHost) {
        $input = Read-Host "  代理地址 (如 127.0.0.1)"
        $Global:Config.ProxyHost = if ($input) { $input } else { "" }
    }
    if ($null -eq $Global:Config.ProxyPort) {
        $input = Read-Host "  代理端口 (如 7890)"
        $Global:Config.ProxyPort = if ($input) { $input } else { "" }
    }
    if ($Global:Config.ProxyHost -and $Global:Config.ProxyPort) {
        $Global:Config.ProxyUrl = "http://$($Global:Config.ProxyHost):$($Global:Config.ProxyPort)"
        Write-OK "代理地址: $($Global:Config.ProxyUrl)"
    } else {
        $Global:Config.ProxyUrl = ""
        Write-OK "不使用代理"
    }

    # --- AI 后端配置 ---
    Write-Host "`n  --- AI 后端配置 ---" -ForegroundColor Yellow
    $backends = @{
        "1" = @{ Name="DeepSeek";         Url="https://api.deepseek.com/anthropic"; KeyLabel="DeepSeek API Key" }
        "2" = @{ Name="OpenAI (兼容)";    Url="https://api.openai.com/v1";           KeyLabel="OpenAI API Key" }
        "3" = @{ Name="自定义";           Url="";                                    KeyLabel="API Key" }
    }

    Write-Host "  可选后端:"
    foreach ($k in $backends.Keys | Sort-Object) {
        Write-Host "    $k. $($backends[$k].Name)  ($($backends[$k].Url))"
    }
    $choice = Read-Host "  选择后端 (1/2/3, 默认 1)"
    if (-not $choice) { $choice = "1" }
    $selected = $backends[$choice]

    if ($choice -eq "3" -and -not $Global:Config.ApiBaseUrl) {
        $Global:Config.ApiBaseUrl = Read-Host "  输入后端 URL"
    } elseif (-not $Global:Config.ApiBaseUrl) {
        $Global:Config.ApiBaseUrl = $selected.Url
    }

    if (-not $Global:Config.ApiKey) {
        $Global:Config.ApiKey = Read-Host "  $($selected.KeyLabel)"
    }

    if (-not $Global:Config.ApiModel) {
        $defaultModel = if ($choice -eq "1") { "deepseek-v4-pro" } else { "" }
        $input = Read-Host "  模型名称 (默认: $defaultModel)"
        $Global:Config.ApiModel = if ($input) { $input } else { $defaultModel }
    }

    # --- Claude Code 版本 ---
    if (-not $Global:Config.ClaudeVersion) {
        $Global:Config.ClaudeVersion = $ClaudeVersion
        $input = Read-Host "`n  Claude Code 版本 (默认: $ClaudeVersion, 输入 skip 跳过安装)"
        if ($input -eq "skip") { $Global:Config.SkipClaude = $true }
        elseif ($input) { $Global:Config.ClaudeVersion = $input }
    }

    Write-OK "配置收集完成"
}

# ============================================================
#  安装函数
# ============================================================
function Install-GitForWindows {
    if ($Global:Config.HasGit) {
        Write-Step "Git 已安装，跳过"
        return
    }
    Write-Step "安装 Git for Windows..."

    if ($Global:Config.HasWinget) {
        winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) { Write-OK "Git 安装完成 (winget)"; return }
    }

    # fallback: 直接下载
    $installer = "$env:TEMP\Git-Installer.exe"
    Write-OK "下载 Git for Windows..."
    Invoke-WebRequest -Uri $GIT_URL -OutFile $installer
    Start-Process -FilePath $installer -ArgumentList '/VERYSILENT','/NORESTART','/NOCANCEL','/SP-','/CLOSEAPPLICATIONS','/RESTARTAPPLICATIONS' -Wait
    Remove-Item $installer -Force
    Write-OK "Git 安装完成 (direct download)"
}

function Install-Miniconda {
    if ($Global:Config.HasConda) {
        Write-Step "Conda 已安装，跳过"
        return
    }
    Write-Step "安装 Miniconda..."

    $installer = "$env:TEMP\Miniconda3-Installer.exe"
    Write-OK "下载 Miniconda..."
    Invoke-WebRequest -Uri $MINICONDA_URL -OutFile $installer

    # 安装到用户目录下
    $installPath = "$env:USERPROFILE\Miniconda3"
    Start-Process -FilePath $installer -ArgumentList "/S","/InstallationType=JustMe","/RegisterPython=0","/AddToPath=0","/D=$installPath" -Wait
    Remove-Item $installer -Force

    # 添加到 PATH (当前会话)
    $env:Path = "$installPath;$installPath\Scripts;$installPath\Library\bin;$env:Path"
    Write-OK "Miniconda 安装完成: $installPath"
}

function Install-NodeJS {
    if ($Global:Config.HasNode -and $Global:Config.HasNpm) {
        Write-Step "Node.js 已安装，跳过"
        return
    }
    Write-Step "安装 Node.js..."

    if ($Global:Config.HasWinget) {
        winget install --id OpenJS.NodeJS.LTS -e --source winget --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            # 刷新 PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            Write-OK "Node.js 安装完成 (winget)"
            return
        }
    }

    # fallback: 直接下载
    $installer = "$env:TEMP\NodeJS-Installer.msi"
    Write-OK "下载 Node.js LTS..."
    Invoke-WebRequest -Uri $NODE_URL -OutFile $installer
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i","`"$installer`"","/qn","/norestart" -Wait
    Remove-Item $installer -Force
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-OK "Node.js 安装完成 (direct download)"
}

function Install-ClaudeCode {
    if ($Global:Config.SkipClaude) {
        Write-Step "已选择跳过 Claude Code 安装"
        return
    }
    Write-Step "安装 Claude Code v$($Global:Config.ClaudeVersion)..."

    # 确保 npm 可用
    if (-not (Test-Command npm.exe)) {
        Write-Err "npm 不可用，无法安装 Claude Code"
        return
    }

    # 配置 npm prefix
    $npmPrefix = "$env:USERPROFILE\.npm-global"
    if (-not (Test-Path $npmPrefix)) { New-Item -ItemType Directory -Path $npmPrefix -Force | Out-Null }
    npm config set prefix $npmPrefix

    # 如果配置了代理，设置 npm 代理
    if ($Global:Config.ProxyUrl) {
        npm config set proxy $Global:Config.ProxyUrl
        npm config set https-proxy $Global:Config.ProxyUrl
    }

    # 安装指定版本
    $package = "@anthropic-ai/claude-code@$($Global:Config.ClaudeVersion)"
    npm install -g $package
    if ($LASTEXITCODE -eq 0) {
        Write-OK "Claude Code v$($Global:Config.ClaudeVersion) 安装完成"
        Write-OK "路径: $npmPrefix\node_modules\@anthropic-ai\claude-code"
    } else {
        Write-Err "Claude Code 安装失败 (exit code: $LASTEXITCODE)"
    }
}

# ============================================================
#  环境配置 — 写入 Git Bash 的 .bashrc
# ============================================================
function Initialize-Bashrc {
    param([string]$Marker = "# >>> dev-setup auto config >>>")

    $bashrc = $Global:Config.BashrcPath
    if (-not (Test-Path $bashrc)) { New-Item -ItemType File -Path $bashrc -Force | Out-Null }

    $content = Get-Content $bashrc -Raw -ErrorAction SilentlyContinue
    if (-not $content) { $content = "" }

    # 移除旧配置段
    $endMarker = "# <<< dev-setup auto config <<<"
    if ($content -match [regex]::Escape($Marker)) {
        $content = $content -replace "(?s)$Marker.*$endMarker", ""
    }

    # 构建新配置
    $lines = @()
    $lines += ""
    $lines += $Marker
    $lines += "# 此段由 dev-setup 自动生成 — $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $lines += ""

    # npm global path
    $lines += "# npm global bin"
    $lines += 'export PATH="$HOME/.npm-global:$HOME/.npm-global/bin:$PATH"'
    $lines += ""

    # conda init (如果 conda 已安装)
    if ($Global:Config.HasConda -or (Test-Path "$env:USERPROFILE\Miniconda3\Scripts\conda.exe")) {
        $condaPath = if ($Global:Config.HasConda) {
            (Split-Path -Parent (Split-Path -Parent (Get-Command conda.exe).Source))
        } else {
            "$env:USERPROFILE\Miniconda3"
        }
        $condaPathUnix = $condaPath -replace '\\', '/' -replace '^C:', '/c'
        $lines += "# conda"
        $lines += "export CONDA_ROOT=`"$condaPathUnix`""
        $lines += 'export PATH="$CONDA_ROOT:$CONDA_ROOT/Scripts:$CONDA_ROOT/Library/bin:$PATH"'
        $lines += ""
    }

    # Node.js path
    if ($Global:Config.HasNode) {
        $nodeDir = Split-Path -Parent (Get-Command node.exe).Source
        $nodeDirUnix = $nodeDir -replace '\\', '/' -replace '^C:', '/c'
        $lines += "# Node.js"
        $lines += "export NODE_HOME=`"$nodeDirUnix`""
        $lines += 'export PATH="$NODE_HOME:$PATH"'
        $lines += ""
    }

    # 代理
    if ($Global:Config.ProxyUrl) {
        $lines += "# 代理设置"
        $lines += "export HTTP_PROXY=`"$($Global:Config.ProxyUrl)`""
        $lines += "export HTTPS_PROXY=`"$($Global:Config.ProxyUrl)`""
        $lines += "export http_proxy=`"$($Global:Config.ProxyUrl)`""
        $lines += "export https_proxy=`"$($Global:Config.ProxyUrl)`""
        $lines += "export NO_PROXY=`"localhost,127.0.0.1,.local`""
        $lines += ""
    }

    # Claude Code / AI 后端
    if ($Global:Config.ApiBaseUrl) {
        $lines += "# AI 后端 (Claude Code 兼容)"
        $lines += "export ANTHROPIC_BASE_URL=`"$($Global:Config.ApiBaseUrl)`""
        $lines += "export ANTHROPIC_API_KEY=`"$($Global:Config.ApiKey)`""
        if ($Global:Config.ApiModel) {
            $lines += "export CLAUDE_MODEL=`"$($Global:Config.ApiModel)`""
        }
        $lines += ""
    }

    # Claude Code alias
    if (-not $Global:Config.SkipClaude) {
        $lines += "# Claude Code"
        $lines += "alias claude=`"claude.cmd`""
        $lines += ""
    }

    $lines += $endMarker
    $lines += ""

    $newBlock = $lines -join "`r`n"
    Set-Content -Path $bashrc -Value ($content.TrimEnd() + "`r`n" + $newBlock) -Encoding UTF8

    Write-OK ".bashrc 已更新: $bashrc"
}

function Initialize-GitConfig {
    Write-Step "配置 Git 全局设置..."

    if ($Global:Config.GitUser) {
        git config --global user.name $Global:Config.GitUser
        Write-OK "git user.name = $($Global:Config.GitUser)"
    }
    if ($Global:Config.GitEmail) {
        git config --global user.email $Global:Config.GitEmail
        Write-OK "git user.email = $($Global:Config.GitEmail)"
    }

    if ($Global:Config.ProxyUrl) {
        git config --global http.proxy $Global:Config.ProxyUrl
        git config --global https.proxy $Global:Config.ProxyUrl
        Write-OK "git 代理已配置: $($Global:Config.ProxyUrl)"
    }

    # 设置默认分支名
    git config --global init.defaultBranch main
    Write-OK "git 默认分支: main"
}

function Initialize-CondaConfig {
    if (-not (Test-Command conda.exe)) { return }
    Write-Step "配置 Conda..."

    if ($Global:Config.ProxyUrl) {
        conda config --set proxy_servers.http $Global:Config.ProxyUrl
        conda config --set proxy_servers.https $Global:Config.ProxyUrl
        Write-OK "conda 代理已配置"
    }
}

# ============================================================
#  保存配置文件
# ============================================================
function Save-ConfigFile {
    $configDir = Join-Path $ScriptDir "config"
    if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }

    $configPath = Join-Path $configDir "config.local.json"
    $safeConfig = @{
        installedAt   = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        gitUser       = $Global:Config.GitUser
        gitEmail      = $Global:Config.GitEmail
        proxyUrl      = $Global:Config.ProxyUrl
        apiBaseUrl    = $Global:Config.ApiBaseUrl
        apiModel      = $Global:Config.ApiModel
        claudeVersion = $Global:Config.ClaudeVersion
        # 不保存 API Key 到配置文件
    }
    $safeConfig | ConvertTo-Json -Depth 3 | Set-Content -Path $configPath -Encoding UTF8
    Write-OK "配置已保存: $configPath"
}

# ============================================================
#  Web 仪表盘
# ============================================================
function Start-Dashboard {
    Write-Step "启动 Web 仪表盘..."

    $frontendDir = Join-Path $ScriptDir "frontend"
    $serverScript = Join-Path $ScriptDir "scripts\server.py"

    # 写一个简单的 Python 服务器脚本
    $pyScript = @'
import http.server
import json
import os
import sys
import socket
from pathlib import Path

PORT = 18888
FRONTEND_DIR = r"{FRONTEND_DIR}"
CONFIG_DIR = r"{CONFIG_DIR}"

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=FRONTEND_DIR, **kwargs)

    def do_GET(self):
        if self.path == "/api/config":
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            config_path = os.path.join(CONFIG_DIR, "config.local.json")
            if os.path.exists(config_path):
                with open(config_path, "r", encoding="utf-8") as f:
                    self.wfile.write(f.read().encode("utf-8"))
            else:
                self.wfile.write(b"{}")
            return
        if self.path == "/api/status":
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            status = {
                "python": sys.version,
                "hostname": socket.gethostname(),
                "dashboard": "running"
            }
            self.wfile.write(json.dumps(status, ensure_ascii=False).encode("utf-8"))
            return
        super().do_GET()

    def log_message(self, format, *args):
        pass  # 安静模式

if __name__ == "__main__":
    os.chdir(FRONTEND_DIR)
    server = http.server.HTTPServer(("127.0.0.1", PORT), Handler)
    print(f"DASHBOARD_READY:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
'@
    $pyScript = $pyScript -replace '{FRONTEND_DIR}', ($frontendDir -replace '\\', '\\')
    $pyScript = $pyScript -replace '{CONFIG_DIR}', ((Join-Path $ScriptDir "config") -replace '\\', '\\')

    $scriptsDir = Join-Path $ScriptDir "scripts"
    if (-not (Test-Path $scriptsDir)) { New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null }
    Set-Content -Path $serverScript -Value $pyScript -Encoding UTF8

    # 用 Python 启动服务器
    $pythonCmd = $null
    if (Test-Command python.exe) {
        $pythonCmd = (Get-Command python.exe).Source
    } elseif (Test-Path "$env:USERPROFILE\Miniconda3\python.exe") {
        $pythonCmd = "$env:USERPROFILE\Miniconda3\python.exe"
    } elseif (Test-Path "$env:USERPROFILE\anaconda3\python.exe") {
        $pythonCmd = "$env:USERPROFILE\anaconda3\python.exe"
    }

    if (-not $pythonCmd) {
        Write-Warn "未找到 Python，跳过仪表盘启动"
        return
    }

    # 后台启动服务器
    $proc = Start-Process -FilePath $pythonCmd -ArgumentList $serverScript -PassThru -WindowStyle Hidden -RedirectStandardOutput "$env:TEMP\dashboard_stdout.txt"

    # 等待服务器就绪
    $ready = $false
    for ($i = 0; $i -lt 10; $i++) {
        Start-Sleep -Seconds 1
        if (Test-Path "$env:TEMP\dashboard_stdout.txt") {
            $out = Get-Content "$env:TEMP\dashboard_stdout.txt" -Raw
            if ($out -match "DASHBOARD_READY:(\d+)") {
                $port = $Matches[1]
                $ready = $true
                break
            }
        }
    }

    if ($ready) {
        $url = "http://127.0.0.1:$port"
        Write-OK "仪表盘已启动: $url"
        Start-Process $url  # 自动打开浏览器
    } else {
        Write-Warn "仪表盘启动超时，请手动运行: python `"$serverScript`""
    }
}

# ============================================================
#  安装报告
# ============================================================
function Write-InstallReport {
    Write-Host "`n" -NoNewline
    Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║     安装完成!                                            ║" -ForegroundColor Green
    Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""

    Write-Host "  已安装组件:" -ForegroundColor Yellow
    Write-Host "    Git Bash:    $(if ($Global:Config.GitBashPath) { '已配置' } else { '未安装' })"
    Write-Host "    Miniconda:   $(if (Test-Command conda.exe) { '已配置' } else { '未安装' })"
    Write-Host "    Node.js:     $(if (Test-Command node.exe) { (node --version 2>&1).Trim() } else { '未安装' })"
    Write-Host "    npm:         $(if (Test-Command npm.exe) { (npm --version 2>&1).Trim() } else { '未安装' })"
    Write-Host "    Claude Code: $(if (Test-Command claude.exe) { (claude --version 2>&1).Trim() } else { '未安装' })"

    Write-Host ""
    Write-Host "  配置文件:" -ForegroundColor Yellow
    Write-Host "    .bashrc:     $($Global:Config.BashrcPath)"
    Write-Host "    安装配置:    $(Join-Path $ScriptDir 'config\config.local.json')"

    Write-Host ""
    Write-Host "  打开 Git Bash 即可使用以下命令:" -ForegroundColor Yellow
    Write-Host "    claude      启动 Claude Code"
    Write-Host "    conda       管理 Python 环境"
    Write-Host "    git         版本控制"
}

# ============================================================
#  主流程
# ============================================================
function Main {
    Write-Host "`n  开发环境一键安装工具" -ForegroundColor Magenta
    Write-Host "  目标: Git Bash + Miniconda + Node.js + Claude Code" -ForegroundColor Gray
    Write-Host ""

    try {
        # 1. 检测环境
        Detect-Environment

        # 2. 收集配置
        Invoke-ConfigWizard

        # 3. 安装
        Install-GitForWindows
        Install-Miniconda
        Install-NodeJS
        Install-ClaudeCode

        # 4. 配置
        Initialize-GitConfig
        Initialize-CondaConfig
        Initialize-Bashrc
        Save-ConfigFile

        # 5. 启动仪表盘
        Start-Dashboard

        # 6. 报告
        Write-InstallReport
    }
    catch {
        Write-Err "安装过程中出现错误: $_"
        Write-Host $_.ScriptStackTrace
        pause
        exit 1
    }
}

Main
