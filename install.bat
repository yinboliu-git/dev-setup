@echo off
setlocal enabledelayedexpansion

:: ============================================================
::  Dev Environment One-Click Setup
::  Git Bash + Miniconda + Node.js + Claude Code + Web Dashboard
:: ============================================================

echo.
echo   ============================================================
echo     Dev Environment Setup v2.0
echo     Git Bash ^| Miniconda ^| Node.js ^| Claude Code
echo   ============================================================
echo.

:: Check admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Admin privileges required
    echo [INFO] Requesting admin elevation...
    powershell -Command "Start-Process '%~f0' -Verb RunAs -WorkingDirectory '%~dp0'"
    exit /b
)

:: Launch PowerShell installer
echo [INFO] Starting installer...
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0setup.ps1"
pause
