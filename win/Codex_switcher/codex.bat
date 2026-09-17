@echo off
setlocal EnableExtensions

REM ==========================================
REM Codex Switcher Windows Launcher
REM ==========================================

REM 使用 UTF-8，支持中文
chcp 65001 >nul
title Codex Switcher

set "PS1_URL=https://raw.githubusercontent.com/Xioaruan912/Xcript/HEAD/win/Codex_switcher/codex-switcher.ps1"
set "WORK_DIR=%TEMP%\Xcript-Codex-Switcher"
set "PS1_FILE=%WORK_DIR%\codex-switcher.ps1"
set "PS1_TEMP=%WORK_DIR%\codex-switcher.download.ps1"

cls
echo.
echo ==========================================
echo          Codex Switcher 启动器
echo ==========================================
echo.
echo 正在获取最新版本，请稍候...
echo.

REM 创建临时目录
if not exist "%WORK_DIR%" (
    mkdir "%WORK_DIR%" >nul 2>&1
)

REM 删除上次未完成的临时下载
if exist "%PS1_TEMP%" (
    del /f /q "%PS1_TEMP%" >nul 2>&1
)

REM 检查 Windows PowerShell
where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到 Windows PowerShell。
    echo.
    echo 你的 Windows 环境可能不完整。
    echo 请确认系统为 Windows 10 或 Windows 11。
    echo.
    pause
    exit /b 1
)

REM 下载最新版 PowerShell 脚本
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference='Stop';" ^
    "$ProgressPreference='SilentlyContinue';" ^
    "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
    "Invoke-WebRequest -UseBasicParsing -Uri '%PS1_URL%' -OutFile '%PS1_TEMP%';" ^
    "if ((Get-Item '%PS1_TEMP%').Length -lt 10) { throw '下载的脚本文件为空'; }"

if errorlevel 1 (
    echo.
    echo ==========================================
    echo [错误] Codex Switcher 下载失败
    echo ==========================================
    echo.
    echo 可能原因：
    echo   1. 当前电脑无法访问 GitHub
    echo   2. 网络连接异常
    echo   3. 代理配置存在问题
    echo   4. 仓库中的脚本路径发生变化
    echo.
    echo 下载地址：
    echo %PS1_URL%
    echo.
    pause
    exit /b 1
)

REM 下载完成后再替换正式文件，避免下载中断留下损坏文件
move /y "%PS1_TEMP%" "%PS1_FILE%" >nul 2>&1

if not exist "%PS1_FILE%" (
    echo.
    echo [错误] 脚本下载成功，但无法保存到本地。
    echo.
    pause
    exit /b 1
)

echo [成功] 已获取最新版本。
echo.
echo 正在启动 Codex Switcher...
echo.

REM 执行真正的 PowerShell 脚本
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PS1_FILE%"

set "EXIT_CODE=%ERRORLEVEL%"

echo.

if not "%EXIT_CODE%"=="0" (
    echo ==========================================
    echo Codex Switcher 已退出
    echo 返回代码：%EXIT_CODE%
    echo ==========================================
    echo.
    pause
)

exit /b %EXIT_CODE%