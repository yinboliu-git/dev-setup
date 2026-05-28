@echo off
chcp 65001 >nul
title 开发环境一键安装 - Dev Environment Setup

:: ============================================================
::  开发环境一键安装工具
::  安装: Git Bash + Miniconda + Node.js + Claude Code + Web 仪表盘
:: ============================================================

echo.
echo  ╔══════════════════════════════════════════════════════════╗
echo  ║     开发环境一键安装工具 v1.0                            ║
echo  ║     Git Bash ^| Miniconda ^| Node.js ^| Claude Code       ║
echo  ╚══════════════════════════════════════════════════════════╝
echo.

:: 检查管理员权限
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [提示] 需要管理员权限来安装软件
    echo 正在请求管理员权限...
    powershell -Command "Start-Process '%~f0' -Verb RunAs -WorkingDirectory '%~dp0'"
    exit /b
)

:: 已获取管理员权限，启动 PowerShell 安装脚本
echo [启动] 正在启动安装程序...
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0setup.ps1"
pause
