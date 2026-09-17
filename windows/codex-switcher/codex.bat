@echo off
setlocal EnableExtensions

REM ==========================================
REM Codex Switcher Windows Launcher
REM NOTE: Keep this file pure ASCII (no Chinese).
REM cmd.exe mis-parses batch files that contain multibyte
REM characters after chcp; all Chinese output is produced by
REM the PowerShell core script instead.
REM ==========================================

chcp 65001 >nul
title Codex Switcher

REM ==========================================
REM Config
REM ==========================================

set "PS1_URL=https://raw.githubusercontent.com/Xioaruan912/Xcript/main/windows/codex-switcher/codex-switcher.ps1"
set "MIRROR_PREFIX=https://ghfast.top/"

set "WORK_DIR=%LOCALAPPDATA%\Xcript\Codex-Switcher"
set "PS1_FILE=%WORK_DIR%\codex-switcher.ps1"
set "PS1_TEMP=%WORK_DIR%\codex-switcher.download.ps1"

REM Cache lifetime in hours
set "CACHE_HOURS=24"

set "NEED_DOWNLOAD=0"
set "CACHE_VALID=0"
set "FORCE=0"

REM ==========================================
REM Parse arguments
REM ==========================================

:PARSE_ARGS
if "%~1"=="" goto ARGS_DONE
if /i "%~1"=="-force"  set "FORCE=1"
if /i "%~1"=="--force" set "FORCE=1"
if /i "%~1"=="/force"  set "FORCE=1"
if /i "%~1"=="-h"      goto USAGE
if /i "%~1"=="--help"  goto USAGE
if /i "%~1"=="/?"      goto USAGE
shift
goto PARSE_ARGS

:ARGS_DONE

REM ==========================================
REM Banner
REM ==========================================

cls
echo.
echo ==========================================
echo          Codex Switcher Launcher
echo ==========================================
echo.
echo Work dir : %WORK_DIR%
echo Script   : %PS1_FILE%
echo Cache TTL: %CACHE_HOURS% hours
echo.

REM ==========================================
REM Create work dir
REM ==========================================

if not exist "%WORK_DIR%" mkdir "%WORK_DIR%" >nul 2>&1
if not exist "%WORK_DIR%" goto DIR_FAILED

REM ==========================================
REM Check Windows PowerShell
REM ==========================================

where powershell.exe >nul 2>&1
if errorlevel 1 goto POWERSHELL_MISSING

REM ==========================================
REM Force refresh
REM ==========================================

if "%FORCE%"=="1" (
    echo [cache] -force specified, refreshing from GitHub.
    echo.
    set "NEED_DOWNLOAD=1"
    if exist "%PS1_FILE%" set "CACHE_VALID=1"
    goto CACHE_DONE
)

REM ==========================================
REM Cache check
REM 0 = stale, 1 = fresh, 2 = invalid
REM ==========================================

if not exist "%PS1_FILE%" goto CACHE_MISSING

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try { $item=Get-Item -LiteralPath $env:PS1_FILE; if ($item.Length -lt 10) { exit 2 }; $age=((Get-Date)-$item.LastWriteTime).TotalHours; if ($age -ge [double]$env:CACHE_HOURS) { exit 0 } else { exit 1 } } catch { exit 2 }"

set "CACHE_STATE=%ERRORLEVEL%"

if "%CACHE_STATE%"=="1" goto CACHE_FRESH
if "%CACHE_STATE%"=="0" goto CACHE_STALE
goto CACHE_INVALID

:CACHE_MISSING
echo [cache] No local copy yet, first run needs download.
echo.
set "NEED_DOWNLOAD=1"
goto CACHE_DONE

:CACHE_FRESH
set "CACHE_VALID=1"
echo [cache] Using local cached copy.
echo [cache] GitHub will not be contacted this time.
echo.
goto CACHE_DONE

:CACHE_STALE
set "CACHE_VALID=1"
set "NEED_DOWNLOAD=1"
echo [cache] Local copy is older than %CACHE_HOURS% hours.
echo [cache] Will try to fetch the latest version.
echo.
goto CACHE_DONE

:CACHE_INVALID
set "NEED_DOWNLOAD=1"
echo [cache] Local copy is invalid or unreadable.
echo [cache] Will try to download again.
echo.
goto CACHE_DONE

:CACHE_DONE
if "%NEED_DOWNLOAD%"=="1" goto DOWNLOAD
goto RUN

REM ==========================================
REM Download (GitHub, then mirror fallback)
REM ==========================================

:DOWNLOAD
if exist "%PS1_TEMP%" del /f /q "%PS1_TEMP%" >nul 2>&1

echo Fetching latest version, please wait...
echo.

call :DOWNLOAD_ONE "%PS1_URL%"
if not errorlevel 1 goto DOWNLOAD_OK

echo [info] GitHub direct failed, trying mirror...
echo.
call :DOWNLOAD_ONE "%MIRROR_PREFIX%%PS1_URL%"
if not errorlevel 1 goto DOWNLOAD_OK

goto DOWNLOAD_FAILED

:DOWNLOAD_ONE
REM arg %1 = full URL
set "PS1_URL_ONE=%~1"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri $env:PS1_URL_ONE -OutFile $env:PS1_TEMP; if ((Get-Item -LiteralPath $env:PS1_TEMP).Length -lt 10) { throw 'Downloaded script is empty' }" 1>nul 2>nul
exit /b %ERRORLEVEL%

:DOWNLOAD_OK
move /y "%PS1_TEMP%" "%PS1_FILE%" >nul 2>&1
if errorlevel 1 goto SAVE_FAILED
if not exist "%PS1_FILE%" goto SAVE_FAILED

set "CACHE_VALID=1"
echo [ok] Latest version downloaded and cached.
echo [cache] No download again for the next %CACHE_HOURS% hours.
echo.
goto RUN

:DOWNLOAD_FAILED
if exist "%PS1_TEMP%" del /f /q "%PS1_TEMP%" >nul 2>&1

if "%CACHE_VALID%"=="1" (
    if exist "%PS1_FILE%" goto DOWNLOAD_FALLBACK
)

echo.
echo ==========================================
echo [error] Download failed
echo ==========================================
echo.
echo No usable local copy is available.
echo.
echo Possible causes:
echo   - Cannot reach GitHub or its mirror
echo   - Network / proxy problem
echo   - Script path changed in the repository
echo.
echo URL: %PS1_URL%
echo.
echo Press any key to close.
echo.
pause >nul
endlocal
exit 1

:DOWNLOAD_FALLBACK
echo.
echo [warn] Latest download failed; using existing cached copy.
echo [cache] %PS1_FILE%
echo.
goto RUN

:SAVE_FAILED
if exist "%PS1_TEMP%" del /f /q "%PS1_TEMP%" >nul 2>&1

if "%CACHE_VALID%"=="1" (
    if exist "%PS1_FILE%" goto SAVE_FALLBACK
)

echo.
echo ==========================================
echo [error] Cannot save Codex Switcher
echo ==========================================
echo.
echo Downloaded, but failed to save into the work dir:
echo %WORK_DIR%
echo.
echo Press any key to close.
echo.
pause >nul
endlocal
exit 1

:SAVE_FALLBACK
echo.
echo [warn] Cannot replace cached file; using existing copy.
echo [cache] %PS1_FILE%
echo.
goto RUN

REM ==========================================
REM Run core script
REM ==========================================

:RUN
echo ==========================================
echo Starting Codex Switcher ...
echo ==========================================
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PS1_FILE%"
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" goto RUN_FAILED

echo.
echo ==========================================
echo Codex Switcher finished
echo ==========================================
echo.
echo Window closes in 5 seconds (any key closes now).
echo.

timeout /t 5 >nul
endlocal
exit 0

:RUN_FAILED
echo.
echo ==========================================
echo Codex Switcher failed
echo ==========================================
echo.
echo Exit code: %EXIT_CODE%
echo.
echo Press any key to close.
echo.
pause >nul
endlocal & exit %EXIT_CODE%

REM ==========================================
REM Usage
REM ==========================================

:USAGE
echo.
echo Usage: codex.bat [-force]
echo.
echo   -force    Ignore cache TTL and fetch the latest version
echo   -h        Show this help
echo.
endlocal
exit 0

REM ==========================================
REM Cannot create work dir
REM ==========================================

:DIR_FAILED
echo.
echo [error] Cannot create work dir: %WORK_DIR%
echo.
echo Press any key to close.
echo.
pause >nul
endlocal
exit 1

REM ==========================================
REM PowerShell missing
REM ==========================================

:POWERSHELL_MISSING
echo.
echo [error] Windows PowerShell not found.
echo Requires Windows 10 or Windows 11.
echo.
echo Press any key to close.
echo.
pause >nul
endlocal
exit 1
