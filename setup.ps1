# ============================================================
#  setup.ps1 — Dev Environment One-Click Setup
#  Installs on Git Bash base: Miniconda + Node.js + Claude Code
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

# ---- Global state ----
$Global:InstallLog = @()
$Global:Config = @{}

# ---- Constants ----
$MINICONDA_URL = "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe"
$NODE_URL      = "https://nodejs.org/dist/v20.18.0/node-v20.18.0-x64.msi"
$GIT_URL       = "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.1/Git-2.47.1-64-bit.exe"
$MARKER        = "# >>> dev-setup auto config >>>"
$ENDMARKER     = "# <<< dev-setup auto config <<<"

function Write-Step { param($msg) Write-Host "`n==> $msg" -ForegroundColor Cyan; $Global:InstallLog += $msg }
function Write-OK   { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow }
function Write-Err  { param($msg) Write-Host "  [ERR] $msg" -ForegroundColor Red }

# ============================================================
#  Environment Detection
# ============================================================
function Test-Command { param($cmd) return (Get-Command $cmd -ErrorAction SilentlyContinue) -ne $null }

function Detect-Environment {
    Write-Step "Detecting environment..."

    $Global:Config.IsWin11       = [Environment]::OSVersion.Version.Build -ge 22000
    $Global:Config.HasWinget     = Test-Command winget.exe
    $Global:Config.HasGit        = Test-Command git.exe
    $Global:Config.HasConda      = Test-Command conda.exe
    $Global:Config.HasNode       = Test-Command node.exe
    $Global:Config.HasNpm        = Test-Command npm.exe
    $Global:Config.HasClaude     = Test-Command claude.exe

    $Global:Config.GitBashPath = ""
    if ($Global:Config.HasGit) {
        $gitPath = (Get-Command git.exe).Source
        $gitDir  = Split-Path -Parent (Split-Path -Parent $gitPath)
        $bashPath = Join-Path $gitDir "bin\bash.exe"
        if (Test-Path $bashPath) { $Global:Config.GitBashPath = $bashPath }
    }

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
    Write-OK "Git Bash: $(if ($Global:Config.GitBashPath) { $Global:Config.GitBashPath } else { 'not found' })"
}

# ============================================================
#  Interactive Config Wizard
# ============================================================
function Invoke-ConfigWizard {
    Write-Step "Configuration Wizard"

    # --- Git ---
    Write-Host "`n  --- Git Config ---" -ForegroundColor Yellow
    if (-not $Global:Config.GitUser) {
        $Global:Config.GitUser = Read-Host "  Git user name"
    }
    if (-not $Global:Config.GitEmail) {
        $Global:Config.GitEmail = Read-Host "  Git email"
    }

    # --- Proxy / VPN ---
    Write-Host "`n  --- Proxy / VPN (leave blank to skip) ---" -ForegroundColor Yellow
    if ($null -eq $Global:Config.ProxyHost) {
        $input = Read-Host "  Proxy host (e.g. 127.0.0.1)"
        $Global:Config.ProxyHost = if ($input) { $input } else { "" }
    }
    if ($null -eq $Global:Config.ProxyPort) {
        $input = Read-Host "  Proxy port (e.g. 7890)"
        $Global:Config.ProxyPort = if ($input) { $input } else { "" }
    }
    if ($Global:Config.ProxyHost -and $Global:Config.ProxyPort) {
        $Global:Config.ProxyUrl = "http://$($Global:Config.ProxyHost):$($Global:Config.ProxyPort)"
        Write-OK "Proxy: $($Global:Config.ProxyUrl)"
    } else {
        $Global:Config.ProxyUrl = ""
        Write-OK "No proxy"
    }

    # --- AI Backend ---
    Write-Host "`n  --- AI Backend Config ---" -ForegroundColor Yellow
    $backends = @{
        "1" = @{ Name="DeepSeek";             Url="https://api.deepseek.com/anthropic"; KeyLabel="DeepSeek API Key" }
        "2" = @{ Name="OpenAI Compatible";    Url="https://api.openai.com/v1";           KeyLabel="OpenAI API Key" }
        "3" = @{ Name="Custom";               Url="";                                    KeyLabel="API Key" }
    }

    Write-Host "  Available backends:"
    foreach ($k in $backends.Keys | Sort-Object) {
        $urlStr = if ($backends[$k].Url) { " ($($backends[$k].Url))" } else { "" }
        Write-Host "    $k. $($backends[$k].Name)$urlStr"
    }
    $choice = Read-Host "  Select backend (1/2/3, default 1)"
    if (-not $choice) { $choice = "1" }
    $selected = $backends[$choice]

    if ($choice -eq "3" -and -not $Global:Config.ApiBaseUrl) {
        $Global:Config.ApiBaseUrl = Read-Host "  Enter backend URL"
    } elseif (-not $Global:Config.ApiBaseUrl) {
        $Global:Config.ApiBaseUrl = $selected.Url
    }

    if (-not $Global:Config.ApiKey) {
        $Global:Config.ApiKey = Read-Host "  $($selected.KeyLabel)"
    }

    if (-not $Global:Config.ApiModel) {
        $defaultModel = if ($choice -eq "1") { "deepseek-v4-pro" } else { "" }
        $input = Read-Host "  Model name (default: $defaultModel)"
        $Global:Config.ApiModel = if ($input) { $input } else { $defaultModel }
    }

    # --- Claude Code version ---
    if (-not $Global:Config.ClaudeVersion) {
        $Global:Config.ClaudeVersion = $ClaudeVersion
        $input = Read-Host "`n  Claude Code version (default: $ClaudeVersion, type 'skip' to skip)"
        if ($input -eq "skip") { $Global:Config.SkipClaude = $true }
        elseif ($input) { $Global:Config.ClaudeVersion = $input }
    }

    Write-OK "Configuration complete"
}

# ============================================================
#  Install Functions
# ============================================================
function Install-GitForWindows {
    if ($Global:Config.HasGit) {
        Write-Step "Git already installed, skipping"
        return
    }
    Write-Step "Installing Git for Windows..."

    if ($Global:Config.HasWinget) {
        winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) { Write-OK "Git installed (winget)"; return }
    }

    $installer = "$env:TEMP\Git-Installer.exe"
    Write-OK "Downloading Git for Windows..."
    Invoke-WebRequest -Uri $GIT_URL -OutFile $installer
    Start-Process -FilePath $installer -ArgumentList '/VERYSILENT','/NORESTART','/NOCANCEL','/SP-','/CLOSEAPPLICATIONS','/RESTARTAPPLICATIONS' -Wait
    Remove-Item $installer -Force
    Write-OK "Git installed (direct download)"
}

function Install-Miniconda {
    if ($Global:Config.HasConda) {
        Write-Step "Conda already installed, skipping"
        return
    }
    Write-Step "Installing Miniconda..."

    $installer = "$env:TEMP\Miniconda3-Installer.exe"
    Write-OK "Downloading Miniconda..."
    Invoke-WebRequest -Uri $MINICONDA_URL -OutFile $installer

    $installPath = "$env:USERPROFILE\Miniconda3"
    Start-Process -FilePath $installer -ArgumentList "/S","/InstallationType=JustMe","/RegisterPython=0","/AddToPath=0","/D=$installPath" -Wait
    Remove-Item $installer -Force

    $env:Path = "$installPath;$installPath\Scripts;$installPath\Library\bin;$env:Path"
    Write-OK "Miniconda installed: $installPath"
}

function Install-NodeJS {
    if ($Global:Config.HasNode -and $Global:Config.HasNpm) {
        Write-Step "Node.js already installed, skipping"
        return
    }
    Write-Step "Installing Node.js..."

    if ($Global:Config.HasWinget) {
        winget install --id OpenJS.NodeJS.LTS -e --source winget --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            Write-OK "Node.js installed (winget)"
            return
        }
    }

    $installer = "$env:TEMP\NodeJS-Installer.msi"
    Write-OK "Downloading Node.js LTS..."
    Invoke-WebRequest -Uri $NODE_URL -OutFile $installer
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i","`"$installer`"","/qn","/norestart" -Wait
    Remove-Item $installer -Force
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-OK "Node.js installed (direct download)"
}

function Install-ClaudeCode {
    if ($Global:Config.SkipClaude) {
        Write-Step "Claude Code install skipped by user"
        return
    }
    Write-Step "Installing Claude Code v$($Global:Config.ClaudeVersion)..."

    if (-not (Test-Command npm.exe)) {
        Write-Err "npm not available, cannot install Claude Code"
        return
    }

    $npmPrefix = "$env:USERPROFILE\.npm-global"
    if (-not (Test-Path $npmPrefix)) { New-Item -ItemType Directory -Path $npmPrefix -Force | Out-Null }
    npm config set prefix $npmPrefix

    if ($Global:Config.ProxyUrl) {
        npm config set proxy $Global:Config.ProxyUrl
        npm config set https-proxy $Global:Config.ProxyUrl
    }

    $package = "@anthropic-ai/claude-code@$($Global:Config.ClaudeVersion)"
    npm install -g $package
    if ($LASTEXITCODE -eq 0) {
        Write-OK "Claude Code v$($Global:Config.ClaudeVersion) installed"
        Write-OK "Path: $npmPrefix\node_modules\@anthropic-ai\claude-code"
    } else {
        Write-Err "Claude Code install failed (exit code: $LASTEXITCODE)"
    }
}

# ============================================================
#  Environment Config — write to Git Bash .bashrc
# ============================================================
function Initialize-Bashrc {
    $bashrc = $Global:Config.BashrcPath
    if (-not (Test-Path $bashrc)) { New-Item -ItemType File -Path $bashrc -Force | Out-Null }

    $content = Get-Content $bashrc -Raw -ErrorAction SilentlyContinue
    if (-not $content) { $content = "" }

    # Remove old config block
    if ($content -match [regex]::Escape($MARKER)) {
        $content = $content -replace "(?s)$MARKER.*$ENDMARKER", ""
    }

    # Build new config block
    $lines = @()
    $lines += ""
    $lines += $MARKER
    $lines += "# Auto-generated by dev-setup on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $lines += ""

    # npm global path
    $lines += 'export PATH="$HOME/.npm-global:$HOME/.npm-global/bin:$PATH"'
    $lines += ""

    # Conda
    $condaPaths = @("$env:USERPROFILE\Miniconda3", "$env:USERPROFILE\anaconda3")
    foreach ($cp in $condaPaths) {
        if (Test-Path "$cp\Scripts\conda.exe") {
            $unixPath = $cp -replace '\\', '/' -replace '^C:', '/c'
            $lines += "# Conda"
            $lines += "export CONDA_ROOT=`"$unixPath`""
            $lines += 'export PATH="$CONDA_ROOT:$CONDA_ROOT/Scripts:$CONDA_ROOT/Library/bin:$PATH"'
            $lines += ""
            break
        }
    }

    # Node.js
    $nodePath = (Get-Command node.exe -ErrorAction SilentlyContinue).Source
    if ($nodePath) {
        $nodeDir = (Split-Path -Parent $nodePath) -replace '\\', '/' -replace '^C:', '/c'
        $lines += "# Node.js"
        $lines += "export NODE_HOME=`"$nodeDir`""
        $lines += 'export PATH="$NODE_HOME:$PATH"'
        $lines += ""
    }

    # Proxy
    if ($Global:Config.ProxyUrl) {
        $lines += "# Proxy / VPN"
        $lines += "export HTTP_PROXY=`"$($Global:Config.ProxyUrl)`""
        $lines += "export HTTPS_PROXY=`"$($Global:Config.ProxyUrl)`""
        $lines += "export http_proxy=`"$($Global:Config.ProxyUrl)`""
        $lines += "export https_proxy=`"$($Global:Config.ProxyUrl)`""
        $lines += 'export NO_PROXY="localhost,127.0.0.1,.local"'
        $lines += ""
    }

    # AI Backend (Claude Code)
    if ($Global:Config.ApiBaseUrl) {
        $lines += "# AI Backend (Claude Code)"
        $lines += "export ANTHROPIC_BASE_URL=`"$($Global:Config.ApiBaseUrl)`""
        $lines += "export ANTHROPIC_API_KEY=`"$($Global:Config.ApiKey)`""
        if ($Global:Config.ApiModel) {
            $lines += "export CLAUDE_MODEL=`"$($Global:Config.ApiModel)`""
        }
        $lines += ""
    }

    # Claude Code alias
    $lines += "alias claude=`"claude.cmd`""
    $lines += ""

    $lines += $ENDMARKER
    $lines += ""

    $newBlock = $lines -join "`r`n"
    Set-Content -Path $bashrc -Value ($content.TrimEnd() + "`r`n" + $newBlock) -Encoding UTF8

    Write-OK ".bashrc updated: $bashrc"
}

function Initialize-GitConfig {
    Write-Step "Configuring Git global settings..."

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
        Write-OK "git proxy set: $($Global:Config.ProxyUrl)"
    }
    git config --global init.defaultBranch main
    Write-OK "git default branch: main"
}

function Initialize-CondaConfig {
    if (-not (Test-Command conda.exe)) { return }
    Write-Step "Configuring Conda..."

    if ($Global:Config.ProxyUrl) {
        conda config --set proxy_servers.http $Global:Config.ProxyUrl
        conda config --set proxy_servers.https $Global:Config.ProxyUrl
        Write-OK "conda proxy set"
    }
}

# ============================================================
#  Save Config File
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
        components    = @{
            git        = $Global:Config.HasGit
            conda      = (Test-Command conda.exe)
            node       = (Test-Command node.exe)
            claudeCode = (Test-Command claude.exe)
        }
    }
    $safeConfig | ConvertTo-Json -Depth 3 | Set-Content -Path $configPath -Encoding UTF8
    Write-OK "Config saved: $configPath"
}

# ============================================================
#  Web Dashboard
# ============================================================
function Start-Dashboard {
    Write-Step "Starting Web Dashboard..."

    $frontendDir = Join-Path $ScriptDir "frontend"
    $serverScript = Join-Path $ScriptDir "scripts\server.py"

    # Generate Python server script
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
        pass

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

    # Find Python
    $pythonCmd = $null
    if (Test-Command python.exe) {
        $pythonCmd = (Get-Command python.exe).Source
    } elseif (Test-Path "$env:USERPROFILE\Miniconda3\python.exe") {
        $pythonCmd = "$env:USERPROFILE\Miniconda3\python.exe"
    } elseif (Test-Path "$env:USERPROFILE\anaconda3\python.exe") {
        $pythonCmd = "$env:USERPROFILE\anaconda3\python.exe"
    }

    if (-not $pythonCmd) {
        Write-Warn "Python not found, skipping dashboard"
        return
    }

    $proc = Start-Process -FilePath $pythonCmd -ArgumentList $serverScript -PassThru -WindowStyle Hidden -RedirectStandardOutput "$env:TEMP\dashboard_stdout.txt"

    # Wait for server ready
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
        Write-OK "Dashboard ready: $url"
        Start-Process $url
    } else {
        Write-Warn "Dashboard start timeout. Run manually: python `"$serverScript`""
    }
}

# ============================================================
#  Install Report
# ============================================================
function Write-InstallReport {
    Write-Host "`n" -NoNewline
    Write-Host "  ============================================================" -ForegroundColor Green
    Write-Host "    Installation Complete!" -ForegroundColor Green
    Write-Host "  ============================================================" -ForegroundColor Green
    Write-Host ""

    Write-Host "  Installed components:" -ForegroundColor Yellow
    Write-Host "    Git Bash:    $(if ($Global:Config.GitBashPath) { 'ready' } else { 'not installed' })"
    Write-Host "    Miniconda:   $(if (Test-Command conda.exe) { 'ready' } else { 'not installed' })"
    Write-Host "    Node.js:     $(if (Test-Command node.exe) { (node --version 2>&1).Trim() } else { 'not installed' })"
    Write-Host "    npm:         $(if (Test-Command npm.exe) { (npm --version 2>&1).Trim() } else { 'not installed' })"
    Write-Host "    Claude Code: $(if (Test-Command claude.exe) { (claude --version 2>&1).Trim() } else { 'not installed' })"

    Write-Host ""
    Write-Host "  Configuration files:" -ForegroundColor Yellow
    Write-Host "    .bashrc:     $($Global:Config.BashrcPath)"
    Write-Host "    Setup cfg:   $(Join-Path $ScriptDir 'config\config.local.json')"

    Write-Host ""
    Write-Host "  Open Git Bash and run:" -ForegroundColor Yellow
    Write-Host "    claude      Launch Claude Code"
    Write-Host "    conda       Manage Python environments"
    Write-Host "    git         Version control"
}

# ============================================================
#  Main
# ============================================================
function Main {
    Write-Host "`n  Dev Environment One-Click Setup" -ForegroundColor Magenta
    Write-Host "  Target: Git Bash + Miniconda + Node.js + Claude Code" -ForegroundColor Gray
    Write-Host ""

    try {
        Detect-Environment
        Invoke-ConfigWizard
        Install-GitForWindows
        Install-Miniconda
        Install-NodeJS
        Install-ClaudeCode
        Initialize-GitConfig
        Initialize-CondaConfig
        Initialize-Bashrc
        Save-ConfigFile
        Start-Dashboard
        Write-InstallReport
    }
    catch {
        Write-Err "Install error: $_"
        Write-Host $_.ScriptStackTrace
        pause
        exit 1
    }
}

Main

