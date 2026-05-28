# ============================================================
#  setup.ps1 — Dev Environment One-Click Setup v2.0
#  Interactive menu-driven installer for Windows
# ============================================================
param()

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ---- Constants ----
$MINICONDA_URL = "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe"
$NODE_URL      = "https://nodejs.org/dist/v20.18.0/node-v20.18.0-x64.msi"
$GIT_URL       = "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.1/Git-2.47.1-64-bit.exe"
$MARKER        = "# >>> dev-setup auto config >>>"
$ENDMARKER     = "# <<< dev-setup auto config <<<"

# ---- Global state ----
$Global:Detected = @{}
$Global:Settings = @{
    GitUser       = ""
    GitEmail      = ""
    Proxy         = ""   # host:port or empty
    BackendChoice = "1"
    BackendName   = "DeepSeek"
    BackendUrl    = "https://api.deepseek.com/anthropic"
    ApiKey        = ""
    Model         = "deepseek-v4-pro"
    ClaudeVersion = "2.1.150"
}

# ---- Helper functions ----
function Write-Step { param($msg) Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow }
function Write-Err  { param($msg) Write-Host "  [ERR] $msg" -ForegroundColor Red }

function Test-Command { param($cmd) return (Get-Command $cmd -ErrorAction SilentlyContinue) -ne $null }

function Press-AnyKey {
    Write-Host ""
    Read-Host "Press Enter to continue"
}

# ============================================================
#  Environment Detection
# ============================================================
function Detect-Environment {
    Write-Step "Detecting environment..."

    $Global:Detected.IsWin11   = [Environment]::OSVersion.Version.Build -ge 22000
    $Global:Detected.HasWinget = Test-Command winget.exe
    $Global:Detected.HasGit    = Test-Command git.exe
    $Global:Detected.HasConda  = Test-Command conda.exe
    $Global:Detected.HasNode   = Test-Command node.exe
    $Global:Detected.HasNpm    = Test-Command npm.exe
    $Global:Detected.HasClaude = Test-Command claude.exe

    $Global:Detected.GitVersion = if ($Global:Detected.HasGit) { (git --version 2>&1).Trim() } else { "" }
    $Global:Detected.NodeVersion= if ($Global:Detected.HasNode) { (node --version 2>&1).Trim() } else { "" }
    $Global:Detected.CondaVersion=if ($Global:Detected.HasConda) { (conda --version 2>&1).Trim() } else { "" }
    $Global:Detected.ClaudeVer  = if ($Global:Detected.HasClaude) { (claude --version 2>&1).Trim() } else { "" }

    # Git Bash path
    $Global:Detected.GitBashPath = ""
    if ($Global:Detected.HasGit) {
        $gitPath = (Get-Command git.exe).Source
        $gitDir  = Split-Path -Parent (Split-Path -Parent $gitPath)
        $bashPath = Join-Path $gitDir "bin\bash.exe"
        if (Test-Path $bashPath) { $Global:Detected.GitBashPath = $bashPath }
    }

    $Global:Detected.BashrcPath = "$env:USERPROFILE\.bashrc"

    Write-OK "Detection complete"
}

function Get-StatusSymbol($installed) {
    if ($installed) { return "[installed]" } else { return "[missing]" }
}

function Show-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host "    Dev Environment Setup v2.0" -ForegroundColor White
    Write-Host "    Git Bash + Miniconda + Node.js + Claude Code" -ForegroundColor Gray
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Detected:" -ForegroundColor Yellow
    Write-Host "    Git Bash    $(Get-StatusSymbol $Global:Detected.HasGit) $($Global:Detected.GitVersion)"
    Write-Host "    Conda       $(Get-StatusSymbol $Global:Detected.HasConda) $($Global:Detected.CondaVersion)"
    Write-Host "    Node.js     $(Get-StatusSymbol $Global:Detected.HasNode) $($Global:Detected.NodeVersion)"
    Write-Host "    npm         $(Get-StatusSymbol $Global:Detected.HasNpm)"
    Write-Host "    Claude Code $(Get-StatusSymbol $Global:Detected.HasClaude) $(if ($Global:Detected.HasClaude) { "v$($Global:Detected.ClaudeVer)" } else { "" })"
    Write-Host ""
}

# ============================================================
#  Sub-menus
# ============================================================

# --- Git ---
function Invoke-GitSetup {
    Clear-Host
    Write-Host ""
    Write-Host "  --- Git Configuration ---" -ForegroundColor Yellow
    Write-Host "  (Used for git commit author identity)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Current: $(
        if ($Global:Settings.GitUser) {
            "$($Global:Settings.GitUser) <$($Global:Settings.GitEmail)>"
        } else {
            '(not set)'
        }
    )"
    Write-Host ""
    Write-Host "  [1] Set name & email"
    Write-Host "  [2] Clear"
    Write-Host "  [0] Back"
    Write-Host ""
    $c = Read-Host "  Choice"
    switch ($c) {
        "1" {
            $Global:Settings.GitUser  = Read-Host "  Git user name"
            $Global:Settings.GitEmail = Read-Host "  Git email"
            Write-OK "Git identity: $($Global:Settings.GitUser) <$($Global:Settings.GitEmail)>"
            Press-AnyKey
        }
        "2" {
            $Global:Settings.GitUser  = ""
            $Global:Settings.GitEmail = ""
            Write-OK "Git identity cleared"
            Press-AnyKey
        }
    }
}

# --- Proxy ---
function Invoke-ProxySetup {
    Clear-Host
    Write-Host ""
    Write-Host "  --- Proxy / VPN Setup ---" -ForegroundColor Yellow
    Write-Host "  (For users behind a VPN or proxy to reach external APIs)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Current: $(
        if ($Global:Settings.Proxy) {
            "http://$($Global:Settings.Proxy)"
        } else {
            '(not set)'
        }
    )"
    Write-Host ""
    Write-Host "  [1] Set proxy (host:port)"
    Write-Host "  [2] Clear proxy"
    Write-Host "  [0] Back"
    Write-Host ""
    $c = Read-Host "  Choice"
    switch ($c) {
        "1" {
            Write-Host ""
            $input = Read-Host "  Proxy address (e.g. 127.0.0.1:7890)"
            if (-not $input) {
                Write-OK "No proxy set"
                Press-AnyKey
                return
            }
            # Parse host:port or just host
            if ($input -match '^(.+):(\d{2,5})$') {
                $hostPart = $Matches[1].Trim()
                $portPart = $Matches[2]
                # Validate: if hostPart is purely numeric without dots, it might be a port
                if ($hostPart -match '^\d+$' -and $hostPart -notmatch '\.') {
                    Write-Warn "\"$hostPart\" looks like a port number, not a host address"
                    Write-Host "  Did you mean: $hostPart`:$portPart ?"
                    Write-Host "  [1] Yes, treat \"$hostPart\" as the host"
                    Write-Host "  [2] No, let me re-enter"
                    $fix = Read-Host "  Choice"
                    if ($fix -eq "2") {
                        $input = Read-Host "  Proxy address (e.g. 127.0.0.1:7890)"
                        if ($input -match '^(.+):(\d{2,5})$') {
                            $hostPart = $Matches[1].Trim()
                            $portPart = $Matches[2]
                        }
                    }
                }
                # Validate port range
                if ([int]$portPart -gt 65535) {
                    Write-Warn "Port $portPart is out of range (0-65535)"
                    Press-AnyKey
                    return
                }
                $Global:Settings.Proxy = "$hostPart`:$portPart"
                Write-OK "Proxy set: http://$hostPart`:$portPart"
            } else {
                # Just a host, ask for port
                $Global:Settings.Proxy = $input.Trim()
                Write-OK "Proxy host set (no port): $($Global:Settings.Proxy)"
            }
            Press-AnyKey
        }
        "2" {
            $Global:Settings.Proxy = ""
            Write-OK "Proxy cleared"
            Press-AnyKey
        }
    }
}

# --- AI Backend ---
function Invoke-BackendSetup {
    Clear-Host
    Write-Host ""
    Write-Host "  --- AI Backend Setup ---" -ForegroundColor Yellow
    Write-Host "  (Configure which AI API Claude Code connects to)" -ForegroundColor Gray
    Write-Host ""

    $choice = $Global:Settings.BackendChoice
    $labels = @{
        "1" = "DeepSeek        (https://api.deepseek.com/anthropic)"
        "2" = "OpenAI          (https://api.openai.com/v1)"
        "3" = "Custom backend  (enter your own URL)"
    }
    if ($choice -and $labels.ContainsKey($choice)) {
        Write-Host "  Current backend: $($labels[$choice])" -ForegroundColor Green
    }
    Write-Host "  Current model:   $($Global:Settings.Model)" -ForegroundColor Green
    Write-Host "  Current API Key: $(if ($Global:Settings.ApiKey) { '**** (set)' } else { '(not set)' })" -ForegroundColor Green
    Write-Host ""

    Write-Host "  [1] DeepSeek"
    Write-Host "  [2] OpenAI"
    Write-Host "  [3] Custom backend"
    Write-Host "  [4] Set API Key"
    Write-Host "  [5] Set Model name"
    Write-Host "  [0] Back"
    Write-Host ""

    $c = Read-Host "  Choice"
    switch ($c) {
        "1" {
            $Global:Settings.BackendChoice = "1"
            $Global:Settings.BackendName   = "DeepSeek"
            $Global:Settings.BackendUrl    = "https://api.deepseek.com/anthropic"
            if (-not $Global:Settings.Model) { $Global:Settings.Model = "deepseek-v4-pro" }
            Write-OK "Backend: DeepSeek"
            Press-AnyKey
        }
        "2" {
            $Global:Settings.BackendChoice = "2"
            $Global:Settings.BackendName   = "OpenAI"
            $Global:Settings.BackendUrl    = "https://api.openai.com/v1"
            if (-not $Global:Settings.Model) { $Global:Settings.Model = "gpt-4o" }
            Write-OK "Backend: OpenAI"
            Press-AnyKey
        }
        "3" {
            $Global:Settings.BackendChoice = "3"
            $Global:Settings.BackendName   = "Custom"
            $input = Read-Host "  Backend URL"
            if ($input) { $Global:Settings.BackendUrl = $input }
            Write-OK "Backend: Custom ($($Global:Settings.BackendUrl))"
            Press-AnyKey
        }
        "4" {
            $Global:Settings.ApiKey = Read-Host "  API Key"
            Write-OK "API Key: $(if ($Global:Settings.ApiKey) { '**** (set)' } else { '(cleared)' })"
            Press-AnyKey
        }
        "5" {
            $input = Read-Host "  Model name (current: $($Global:Settings.Model))"
            if ($input) { $Global:Settings.Model = $input }
            Write-OK "Model: $($Global:Settings.Model)"
            Press-AnyKey
        }
    }
}

# --- Claude Code version ---
function Invoke-ClaudeVersionSetup {
    Clear-Host
    Write-Host ""
    Write-Host "  --- Claude Code Version ---" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Current: $($Global:Settings.ClaudeVersion)"
    Write-Host ""
    Write-Host "  [1] Use default (2.1.150)"
    Write-Host "  [2] Enter custom version"
    Write-Host "  [3] Skip Claude Code installation"
    Write-Host "  [0] Back"
    Write-Host ""
    $c = Read-Host "  Choice"
    switch ($c) {
        "1" { $Global:Settings.ClaudeVersion = "2.1.150"; Write-OK "Version: 2.1.150"; Press-AnyKey }
        "2" {
            $input = Read-Host "  Version (e.g. 2.1.150)"
            if ($input) { $Global:Settings.ClaudeVersion = $input }
            Write-OK "Version: $($Global:Settings.ClaudeVersion)"
            Press-AnyKey
        }
        "3" { $Global:Settings.ClaudeVersion = "skip"; Write-OK "Claude Code will be skipped"; Press-AnyKey }
    }
}

# --- Review & Confirm ---
function Invoke-Review {
    Clear-Host
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host "    Review & Confirm" -ForegroundColor White
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host ""

    # Installation plan
    Write-Host "  Installation plan:" -ForegroundColor Yellow
    $plan = @(
        @{Name="Git for Windows"; Skip=$Global:Detected.HasGit; Detail=$(if ($Global:Detected.HasGit) { $Global:Detected.GitVersion } else { "will install" })},
        @{Name="Miniconda";       Skip=$Global:Detected.HasConda; Detail=$(if ($Global:Detected.HasConda) { $Global:Detected.CondaVersion } else { "will install" })},
        @{Name="Node.js";         Skip=$Global:Detected.HasNode; Detail=$(if ($Global:Detected.HasNode) { $Global:Detected.NodeVersion } else { "will install" })},
        @{Name="Claude Code";     Skip=($Global:Detected.HasClaude -or $Global:Settings.ClaudeVersion -eq "skip"); Detail=$(if ($Global:Settings.ClaudeVersion -eq "skip") { "skipped by user" } elseif ($Global:Detected.HasClaude) { $Global:Detected.ClaudeVer } else { "will install v$($Global:Settings.ClaudeVersion)" })}
    )
    foreach ($p in $plan) {
        $status = if ($p.Skip) { "(skip)" } else { "(install)" }
        Write-Host "    $($p.Name.PadRight(15)) $($status.PadRight(10)) $($p.Detail)"
    }

    # Settings summary
    Write-Host ""
    Write-Host "  Configuration:" -ForegroundColor Yellow
    Write-Host "    Git identity: $(
        if ($Global:Settings.GitUser) { "$($Global:Settings.GitUser) <$($Global:Settings.GitEmail)>" } else { '(not set)' }
    )"
    Write-Host "    Proxy/VPN:    $(
        if ($Global:Settings.Proxy) { "http://$($Global:Settings.Proxy)" } else { '(not set)' }
    )"
    Write-Host "    Backend:      $($Global:Settings.BackendName) — $($Global:Settings.BackendUrl)"
    Write-Host "    Model:        $(if ($Global:Settings.Model) { $Global:Settings.Model } else { '(not set)' })"
    Write-Host "    API Key:      $(if ($Global:Settings.ApiKey) { '**** (set)' } else { '(not set)' })"
    Write-Host ""

    Write-Host "  [1] START INSTALLATION" -ForegroundColor Green
    Write-Host "  [2] Back to menu (change settings)"
    Write-Host "  [0] Exit"
    Write-Host ""

    $c = Read-Host "  Choice"
    switch ($c) {
        "1" { return $true }
        "0" { Write-Host "`n  Exiting..."; exit 0 }
        default { return $false }
    }
}

# ============================================================
#  Main Menu Loop
# ============================================================
function Show-MainMenu {
    while ($true) {
        Show-Header

        $proxyDisplay = if ($Global:Settings.Proxy) { $Global:Settings.Proxy } else { '(not set)' }
        $gitDisplay   = if ($Global:Settings.GitUser) { "$($Global:Settings.GitUser)" } else { '(not set)' }
        $backendDisplay = "$($Global:Settings.BackendName) / $($Global:Settings.Model)"
        $claudeDisplay  = if ($Global:Settings.ClaudeVersion -eq "skip") { "(skip)" } else { $Global:Settings.ClaudeVersion }

        Write-Host "  Settings:" -ForegroundColor Yellow
        Write-Host "    [1] Git identity  $gitDisplay"
        Write-Host "    [2] Proxy/VPN     $proxyDisplay"
        Write-Host "    [3] AI Backend    $backendDisplay"
        Write-Host "    [4] Claude Code   $claudeDisplay"
        Write-Host ""
        Write-Host "    [5] Review & Install" -ForegroundColor Green
        Write-Host "    [0] Exit"
        Write-Host ""

        $choice = Read-Host "  Enter your choice"
        switch ($choice) {
            "1" { Invoke-GitSetup }
            "2" { Invoke-ProxySetup }
            "3" { Invoke-BackendSetup }
            "4" { Invoke-ClaudeVersionSetup }
            "5" {
                $confirmed = Invoke-Review
                if ($confirmed) { return }  # proceed to install
            }
            "0" {
                Write-Host "`n  Exiting..."
                exit 0
            }
        }
    }
}

# ============================================================
#  Install Functions (same logic, adapted for new config format)
# ============================================================
function Install-GitForWindows {
    if ($Global:Detected.HasGit) {
        Write-Step "Git already installed, skipping"
        return
    }
    Write-Step "Installing Git for Windows..."

    if ($Global:Detected.HasWinget) {
        winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) { Write-OK "Git installed (winget)"; return }
    }

    $installer = "$env:TEMP\Git-Installer.exe"
    Write-OK "Downloading Git for Windows..."
    Invoke-WebRequest -Uri $GIT_URL -OutFile $installer -UseBasicParsing
    Start-Process -FilePath $installer -ArgumentList '/VERYSILENT','/NORESTART','/NOCANCEL','/SP-','/CLOSEAPPLICATIONS','/RESTARTAPPLICATIONS' -Wait
    Remove-Item $installer -Force
    Write-OK "Git installed (direct download)"
}

function Install-Miniconda {
    if ($Global:Detected.HasConda) {
        Write-Step "Conda already installed, skipping"
        return
    }
    Write-Step "Installing Miniconda..."

    $installer = "$env:TEMP\Miniconda3-Installer.exe"
    Write-OK "Downloading Miniconda..."
    Invoke-WebRequest -Uri $MINICONDA_URL -OutFile $installer -UseBasicParsing

    $installPath = "$env:USERPROFILE\Miniconda3"
    Start-Process -FilePath $installer -ArgumentList "/S","/InstallationType=JustMe","/RegisterPython=0","/AddToPath=0","/D=$installPath" -Wait
    Remove-Item $installer -Force

    $env:Path = "$installPath;$installPath\Scripts;$installPath\Library\bin;$env:Path"
    Write-OK "Miniconda installed: $installPath"
}

function Find-npmPath {
    # Actively search for npm.cmd in common Node.js install locations
    $candidates = @(
        "$env:ProgramFiles\nodejs\npm.cmd",
        "${env:ProgramFiles(x86)}\nodejs\npm.cmd",
        "$env:LOCALAPPDATA\Programs\nodejs\npm.cmd",
        "$env:APPDATA\npm\npm.cmd"
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    # Fallback: check PATH
    $fromPath = (Get-Command npm.cmd -ErrorAction SilentlyContinue).Source
    if ($fromPath) { return $fromPath }
    return $null
}

function Find-PythonPath {
    $candidates = @(
        "$env:USERPROFILE\anaconda3\python.exe",
        "$env:USERPROFILE\Miniconda3\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
        "$env:ProgramFiles\Python313\python.exe",
        "$env:ProgramFiles\Python312\python.exe",
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\python.exe"
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    $fromPath = (Get-Command python.exe -ErrorAction SilentlyContinue).Source
    if ($fromPath) { return $fromPath }
    return $null
}

function Install-NodeJS {
    if ($Global:Detected.HasNode -and $Global:Detected.HasNpm) {
        Write-Step "Node.js already installed, skipping"
        return
    }
    Write-Step "Installing Node.js..."

    # Try winget first
    $wingetOk = $false
    if ($Global:Detected.HasWinget) {
        winget install --id OpenJS.NodeJS.LTS -e --source winget --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) { $wingetOk = $true }
    }

    if (-not $wingetOk) {
        $installer = "$env:TEMP\NodeJS-Installer.msi"
        Write-OK "Downloading Node.js LTS..."
        Invoke-WebRequest -Uri $NODE_URL -OutFile $installer -UseBasicParsing
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i","`"$installer`"","/qn","/norestart" -Wait
        Remove-Item $installer -Force
    }

    # Force-refresh PATH from registry (with delay for winget to finish writing)
    Start-Sleep -Seconds 2
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path","Machine")
    $userPath    = [System.Environment]::GetEnvironmentVariable("Path","User")
    $env:Path = "$machinePath;$userPath;$env:Path"

    # Actively find npm
    $npmFound = Find-npmPath
    if ($npmFound) {
        # Prepend its directory to PATH so it takes priority
        $npmDir = Split-Path -Parent $npmFound
        $env:Path = "$npmDir;$env:Path"
        $Global:Detected.HasNpm = $true
        $Global:Detected.NpmPath = $npmFound
        Write-OK "Node.js installed, npm found at: $npmFound"
    } else {
        Write-OK "Node.js installed, but npm not found on PATH yet"
        Write-Warn "You may need to restart your terminal, then re-run this installer"
    }
}

function Install-ClaudeCode {
    if ($Global:Settings.ClaudeVersion -eq "skip") {
        Write-Step "Claude Code skipped by user"
        return
    }
    if ($Global:Detected.HasClaude) {
        Write-Step "Claude Code already installed ($($Global:Detected.ClaudeVer)), skipping"
        return
    }
    Write-Step "Installing Claude Code v$($Global:Settings.ClaudeVersion)..."

    # Resolve npm path: use found path from Node.js install, or search again
    $npmExe = $Global:Detected.NpmPath
    if (-not $npmExe) { $npmExe = Find-npmPath }
    if (-not $npmExe) {
        Write-Err "npm not found. Please install Node.js first, then re-run this installer."
        Write-Err "If Node.js was just installed, restart your terminal and try again."
        return
    }
    Write-OK "Using npm: $npmExe"

    $npmPrefix = "$env:USERPROFILE\.npm-global"
    if (-not (Test-Path $npmPrefix)) { New-Item -ItemType Directory -Path $npmPrefix -Force | Out-Null }
    & $npmExe config set prefix $npmPrefix

    if ($Global:Settings.Proxy) {
        $proxyUrl = "http://$($Global:Settings.Proxy)"
        & $npmExe config set proxy $proxyUrl
        & $npmExe config set https-proxy $proxyUrl
    }

    $package = "@anthropic-ai/claude-code@$($Global:Settings.ClaudeVersion)"
    & $npmExe install -g $package
    if ($LASTEXITCODE -eq 0) {
        Write-OK "Claude Code v$($Global:Settings.ClaudeVersion) installed"
        $Global:Detected.HasClaude = $true
    } else {
        Write-Err "Claude Code install failed (exit code: $LASTEXITCODE)"
    }
}

# ============================================================
#  Post-install Configuration
# ============================================================
function Initialize-Bashrc {
    Write-Step "Writing Git Bash environment config..."

    $bashrc = $Global:Detected.BashrcPath
    if (-not (Test-Path $bashrc)) { New-Item -ItemType File -Path $bashrc -Force | Out-Null }

    $content = Get-Content $bashrc -Raw -ErrorAction SilentlyContinue
    if (-not $content) { $content = "" }

    if ($content -match [regex]::Escape($MARKER)) {
        $content = $content -replace "(?s)$MARKER.*$ENDMARKER", ""
    }

    $lines = @()
    $lines += ""
    $lines += $MARKER
    $lines += "# Auto-generated by dev-setup on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $lines += ""

    $lines += 'export PATH="$HOME/.npm-global:$HOME/.npm-global/bin:$PATH"'
    $lines += ""

    # Conda
    $condaPaths = @("$env:USERPROFILE\Miniconda3", "$env:USERPROFILE\anaconda3")
    foreach ($cp in $condaPaths) {
        if (Test-Path "$cp\Scripts\conda.exe") {
            $unix = $cp -replace '\\', '/' -replace '^C:', '/c'
            $lines += "export CONDA_ROOT=`"$unix`""
            $lines += 'export PATH="$CONDA_ROOT:$CONDA_ROOT/Scripts:$CONDA_ROOT/Library/bin:$PATH"'
            $lines += ""
            break
        }
    }

    # Proxy
    if ($Global:Settings.Proxy) {
        $proxyUrl = "http://$($Global:Settings.Proxy)"
        $lines += "export HTTP_PROXY=`"$proxyUrl`""
        $lines += "export HTTPS_PROXY=`"$proxyUrl`""
        $lines += "export http_proxy=`"$proxyUrl`""
        $lines += "export https_proxy=`"$proxyUrl`""
        $lines += 'export NO_PROXY="localhost,127.0.0.1,.local"'
        $lines += ""
    }

    # AI Backend
    if ($Global:Settings.BackendUrl -and $Global:Settings.ApiKey) {
        $lines += "export ANTHROPIC_BASE_URL=`"$($Global:Settings.BackendUrl)`""
        $lines += "export ANTHROPIC_API_KEY=`"$($Global:Settings.ApiKey)`""
        if ($Global:Settings.Model) {
            $lines += "export CLAUDE_MODEL=`"$($Global:Settings.Model)`""
        }
        $lines += ""
    }

    $lines += "alias claude=`"claude.cmd`""
    $lines += ""
    $lines += $ENDMARKER
    $lines += ""

    Set-Content -Path $bashrc -Value ($content.TrimEnd() + "`r`n" + ($lines -join "`r`n")) -Encoding UTF8
    Write-OK ".bashrc updated: $bashrc"
}

function Initialize-GitConfig {
    if (-not $Global:Settings.GitUser) { return }
    Write-Step "Configuring Git..."

    git config --global user.name $Global:Settings.GitUser
    git config --global user.email $Global:Settings.GitEmail
    Write-OK "git user: $($Global:Settings.GitUser)"

    if ($Global:Settings.Proxy) {
        $proxyUrl = "http://$($Global:Settings.Proxy)"
        git config --global http.proxy $proxyUrl
        git config --global https.proxy $proxyUrl
        Write-OK "git proxy: $proxyUrl"
    }
    git config --global init.defaultBranch main
}

function Initialize-CondaConfig {
    if (-not (Test-Command conda.exe)) { return }
    if (-not $Global:Settings.Proxy) { return }
    Write-Step "Configuring Conda proxy..."

    $proxyUrl = "http://$($Global:Settings.Proxy)"
    conda config --set proxy_servers.http $proxyUrl
    conda config --set proxy_servers.https $proxyUrl
    Write-OK "conda proxy set"
}

function Save-ConfigFile {
    $configDir = Join-Path $ScriptDir "config"
    if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }

    $safeConfig = @{
        installedAt   = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        gitUser       = $Global:Settings.GitUser
        gitEmail      = $Global:Settings.GitEmail
        proxy         = $Global:Settings.Proxy
        backendName   = $Global:Settings.BackendName
        backendUrl    = $Global:Settings.BackendUrl
        model         = $Global:Settings.Model
        claudeVersion = $Global:Settings.ClaudeVersion
    }
    $safeConfig | ConvertTo-Json -Depth 3 | Set-Content -Path "$configDir\config.local.json" -Encoding UTF8
    Write-OK "Config saved to config\config.local.json"
}

# ============================================================
#  Web Dashboard
# ============================================================
function Start-Dashboard {
    Write-Step "Starting Web Dashboard..."

    $frontendDir = Join-Path $ScriptDir "frontend"
    $serverScript = Join-Path $ScriptDir "scripts\server.py"

    if (-not (Test-Path $frontendDir)) {
        Write-Warn "frontend/ not found, skipping dashboard"
        return
    }

    # Python server script
    $pyScript = @'
import http.server, json, os, sys, socket
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
            cp = os.path.join(CONFIG_DIR, "config.local.json")
            if os.path.exists(cp):
                with open(cp, "r", encoding="utf-8") as f:
                    self.wfile.write(f.read().encode("utf-8"))
            else:
                self.wfile.write(b"{}")
            return
        super().do_GET()
    def log_message(self, f, *a): pass

if __name__ == "__main__":
    os.chdir(FRONTEND_DIR)
    server = http.server.HTTPServer(("127.0.0.1", PORT), Handler)
    print(f"DASHBOARD_READY:{PORT}")
    server.serve_forever()
'@
    $pyScript = $pyScript -replace '{FRONTEND_DIR}', ($frontendDir -replace '\\', '\\')
    $pyScript = $pyScript -replace '{CONFIG_DIR}', ((Join-Path $ScriptDir "config") -replace '\\', '\\')
    Set-Content -Path $serverScript -Value $pyScript -Encoding UTF8

    # Find Python (search known locations, not just PATH)
    $pythonCmd = Find-PythonPath
    if (-not $pythonCmd) {
        Write-Warn "Python not found, skipping dashboard"
        return
    }
    Write-OK "Using Python: $pythonCmd"

    Start-Process -FilePath $pythonCmd -ArgumentList $serverScript -WindowStyle Hidden -RedirectStandardOutput "$env:TEMP\dashboard_stdout.txt"

    $ready = $false; $port = 18888
    for ($i = 0; $i -lt 10; $i++) {
        Start-Sleep 1
        if (Test-Path "$env:TEMP\dashboard_stdout.txt") {
            $out = Get-Content "$env:TEMP\dashboard_stdout.txt" -Raw
            if ($out -match "DASHBOARD_READY:(\d+)") { $port = $Matches[1]; $ready = $true; break }
        }
    }

    if ($ready) {
        Write-OK "Dashboard: http://127.0.0.1:$port"
        Start-Process "http://127.0.0.1:$port"
    } else {
        Write-Warn "Dashboard start timeout"
    }
}

# ============================================================
#  Final Report
# ============================================================
function Write-InstallReport {
    Write-Host "`n"
    Write-Host "  ============================================================" -ForegroundColor Green
    Write-Host "    Installation Complete!" -ForegroundColor Green
    Write-Host "  ============================================================" -ForegroundColor Green
    Write-Host ""

    Write-Host "  Components:" -ForegroundColor Yellow
    Write-Host "    Git Bash:    $(if ($Global:Detected.GitBashPath) { 'ready' } else { 'not found' })"
    Write-Host "    Miniconda:   $(if (Test-Command conda.exe) { 'ready' } else { 'not found' })"
    Write-Host "    Node.js:     $(if (Test-Command node.exe) { (node --version 2>&1).Trim() } else { 'not found' })"
    Write-Host "    npm:         $(if (Test-Command npm.exe) { (npm --version 2>&1).Trim() } else { 'not found' })"
    Write-Host "    Claude Code: $(if (Test-Command claude.exe) { (claude --version 2>&1).Trim() } else { 'not found' })"
    Write-Host ""

    if ($Global:Settings.ApiKey) {
        Write-Host "  Open Git Bash and run: claude" -ForegroundColor Green
    } else {
        Write-Host "  Set API Key in .bashrc to start using Claude Code" -ForegroundColor Yellow
    }
    Write-Host ""
}

# ============================================================
#  Main
# ============================================================
function Main {
    try {
        Detect-Environment
        Show-MainMenu

        # ---- Install phase ----
        Write-Host "`n  Starting installation..." -ForegroundColor Magenta
        Install-GitForWindows
        Install-Miniconda
        Install-NodeJS
        Install-ClaudeCode

        # ---- Configure ----
        Initialize-GitConfig
        Initialize-CondaConfig
        Initialize-Bashrc
        Save-ConfigFile

        # ---- Dashboard ----
        Start-Dashboard

        # ---- Done ----
        Write-InstallReport
    }
    catch {
        Write-Err "Install error: $_"
        Write-Host $_.ScriptStackTrace
    }
    finally {
        Write-Host "  Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

Main


