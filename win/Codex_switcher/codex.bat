@echo off
REM Codex Switcher has moved to windows/codex-switcher/.
REM This file only forwards old links to the new launcher.
set "NEW_URL=https://raw.githubusercontent.com/Xioaruan912/Xcript/main/windows/codex-switcher/codex.bat"
set "TMP_BAT=%TEMP%\codex-switcher-latest.bat"
echo [*] Script moved, fetching latest launcher...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri $env:NEW_URL -OutFile $env:TMP_BAT"
if not exist "%TMP_BAT%" (
    echo [error] Download failed. Please get it from:
    echo   %NEW_URL%
    pause
    exit /b 1
)
call "%TMP_BAT%"
