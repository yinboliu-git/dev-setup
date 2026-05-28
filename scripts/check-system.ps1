# ============================================================
#  check-system.ps1 — 系统环境检测
# ============================================================
param([switch]$Json)

function Test-Command { param($cmd) return (Get-Command $cmd -ErrorAction SilentlyContinue) -ne $null }

$info = [PSCustomObject]@{
    os          = [Environment]::OSVersion.VersionString
    build       = [Environment]::OSVersion.Version.Build
    isWin11     = [Environment]::OSVersion.Version.Build -ge 22000
    isAdmin     = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    hasWinget   = Test-Command winget.exe
    hasGit      = Test-Command git.exe
    hasConda    = Test-Command conda.exe
    hasNode     = Test-Command node.exe
    hasNpm      = Test-Command npm.exe
    hasClaude   = Test-Command claude.exe
    hasPython   = Test-Command python.exe
    gitVersion  = if (Test-Command git.exe) { (git --version 2>&1).Trim() } else { $null }
    nodeVersion = if (Test-Command node.exe) { (node --version 2>&1).Trim() } else { $null }
    npmVersion  = if (Test-Command npm.exe) { (npm --version 2>&1).Trim() } else { $null }
    condaVersion= if (Test-Command conda.exe) { (conda --version 2>&1).Trim() } else { $null }
    pipVersion  = if (Test-Command pip.exe) { (pip --version 2>&1).Trim() } else { $null }
    diskFree    = [math]::Round((Get-PSDrive C).Free / 1GB, 1)
}

if ($Json) {
    $info | ConvertTo-Json -Depth 2
} else {
    Write-Host "操作系统:   $($info.os) (Build $($info.build))"
    Write-Host "Windows 11: $($info.isWin11)"
    Write-Host "管理员:     $($info.isAdmin)"
    Write-Host "winget:     $($info.hasWinget)"
    Write-Host "Git:        $($info.gitVersion)"
    Write-Host "Conda:      $($info.condaVersion)"
    Write-Host "Node.js:    $($info.nodeVersion)"
    Write-Host "npm:        $($info.npmVersion)"
    Write-Host "Claude:     $(if ($info.hasClaude) { (claude --version 2>&1).Trim() } else { '未安装' })"
    Write-Host "可用磁盘:   $($info.diskFree) GB"
}
