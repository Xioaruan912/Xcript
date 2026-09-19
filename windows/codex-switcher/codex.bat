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

REM Launcher version (keep in sync with version.txt bat=)
set "LOCAL_BAT_VERSION=1.5.2"

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
set "NO_PROXY=0"
set "PROXY_PORT="

REM ==========================================
REM Parse arguments
REM ==========================================

:PARSE_ARGS
if "%~1"=="" goto ARGS_DONE
if /i "%~1"=="-force"   set "FORCE=1"
if /i "%~1"=="--force"  set "FORCE=1"
if /i "%~1"=="/force"   set "FORCE=1"
if /i "%~1"=="-noproxy" set "NO_PROXY=1"
if /i "%~1"=="--no-proxy" set "NO_PROXY=1"
if /i "%~1"=="/noproxy" set "NO_PROXY=1"
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
echo Version  : %LOCAL_BAT_VERSION%
echo Work dir : %WORK_DIR%
echo Script   : %PS1_FILE%
echo Cache TTL: %CACHE_HOURS% hours
echo.

REM ==========================================
REM Create work dir
REM ==========================================

if not exist "%WORK_DIR%" mkdir "%WORK_DIR%" >nul 2>&1
if not exist "%WORK_DIR%" goto DIR_FAILED

REM Record launcher version so the core script can detect updates
> "%WORK_DIR%\bat.version" echo %LOCAL_BAT_VERSION%

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

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try { $item=Get-Item -LiteralPath $env:PS1_FILE; if ($item.Length -lt 200) { exit 2 }; $c=Get-Content -LiteralPath $env:PS1_FILE -Raw; if ($c -notmatch 'Invoke-Main') { exit 2 }; $age=((Get-Date)-$item.LastWriteTime).TotalHours; if ($age -ge [double]$env:CACHE_HOURS) { exit 0 } else { exit 1 } } catch { exit 2 }"

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

REM Quick version compare: if the cached core script is older than the
REM remote version.txt, refresh it. Any network failure keeps the cache.
echo [cache] Verifying cached version (quick) ...
call :READ_LOCAL_PS1_VER
set "REMOTE_VER_FILE=%TEMP%\codex-switcher-remote-ver.txt"
if exist "%REMOTE_VER_FILE%" del /f /q "%REMOTE_VER_FILE%" >nul 2>&1
call :FETCH_REMOTE_VER

if not "%LOCAL_PS1_VER%"=="" (
    if not "%REMOTE_PS1_VER%"=="" (
        if not "%LOCAL_PS1_VER%"=="%REMOTE_PS1_VER%" (
            echo [cache] Cached script %LOCAL_PS1_VER% is older than remote %REMOTE_PS1_VER%, refreshing.
            echo.
            set "NEED_DOWNLOAD=1"
            goto CACHE_DONE
        )
    )
)

echo [cache] Using local cached copy.
echo.
goto CACHE_DONE

REM ==========================================
REM Read version from cached core script
REM ==========================================

:READ_LOCAL_PS1_VER
set "LOCAL_PS1_VER="
for /f "tokens=2 delims='" %%a in ('findstr /c:"script:Version" "%PS1_FILE%"') do (
    if not defined LOCAL_PS1_VER set "LOCAL_PS1_VER=%%a"
)
exit /b 0

REM ==========================================
REM Fetch remote version.txt (proxy first, then direct, then mirror)
REM Sets REMOTE_PS1_VER from the "ps1=" line.
REM ==========================================

:FETCH_REMOTE_VER
set "REMOTE_PS1_VER="
set "VER_URL_BASE=https://raw.githubusercontent.com/Xioaruan912/Xcript/main/windows/codex-switcher/version.txt"

REM Try local proxy if the port is listening (no full detection here, keep it fast)
for %%P in (7897 7890) do (
    if not defined REMOTE_PS1_VER call :FETCH_REMOTE_ONE "http://127.0.0.1:%%P"
)
if not defined REMOTE_PS1_VER call :FETCH_REMOTE_ONE ""
if not defined REMOTE_PS1_VER call :FETCH_REMOTE_ONE "https://ghfast.top/"
if exist "%REMOTE_VER_FILE%" del /f /q "%REMOTE_VER_FILE%" >nul 2>&1
exit /b 0

:FETCH_REMOTE_ONE
REM %1 = proxy URL (empty = direct). ghfast is passed as the download prefix.
set "DL_PROXY=%~1"
if /i "%DL_PROXY%"=="https://ghfast.top/" (
    set "DL_URL=https://ghfast.top/%VER_URL_BASE%"
    set "DL_PROXY="
) else (
    set "DL_URL=%VER_URL_BASE%"
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; $ProgressPreference='SilentlyContinue'; $a=@{UseBasicParsing=$true;Uri=$env:DL_URL;OutFile=$env:REMOTE_VER_FILE;TimeoutSec=6}; if($env:DL_PROXY){$a.Proxy=$env:DL_PROXY}; Invoke-WebRequest @a" >nul 2>nul
if not exist "%REMOTE_VER_FILE%" exit /b 0
for /f "tokens=1,2 delims==" %%a in ('findstr /b /c:"ps1=" "%REMOTE_VER_FILE%"') do (
    if not defined REMOTE_PS1_VER set "REMOTE_PS1_VER=%%b"
)
exit /b 0

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
if "%NEED_DOWNLOAD%"=="1" goto DETECT_PROXY
goto RUN

REM ==========================================
REM Detect local proxy (read-only, writes nothing)
REM
REM Order: env PROXY_PORT > Clash Verge config > common ports
REM Uses GitHub reachability to validate a candidate, then asks
REM the user if nothing was found (only when a download is needed).
REM ==========================================

:DETECT_PROXY
if "%NO_PROXY%"=="1" (
    echo [proxy] -noproxy specified, skipping detection.
    echo.
    goto DOWNLOAD
)

echo [proxy] detecting local proxy ...
set "PROXY_RESULT=%TEMP%\codex-switcher-proxy.result"
if exist "%PROXY_RESULT%" del /f /q "%PROXY_RESULT%" >nul 2>&1
set "CODE_SWITCHER_PROXY_PORT=%PROXY_PORT%"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; $ProgressPreference='SilentlyContinue'; function Test-Tcp([int]$p){ if($p -lt 1 -or $p -gt 65535){return $false}; try{ $c=New-Object Net.Sockets.TcpClient; $iar=$c.BeginConnect('127.0.0.1',$p,$null,$null); if($iar.AsyncWaitHandle.WaitOne(300)){ $c.EndConnect($iar); $c.Close(); return $true }; $c.Close() }catch{}; return $false }; function Test-Gh([int]$p){ if(-not (Test-Tcp $p)){return $false}; try{ $r=Invoke-WebRequest -UseBasicParsing -Method Head -Uri 'https://raw.githubusercontent.com/Xioaruan912/Xcript/main/windows/codex-switcher/version.txt' -Proxy ('http://127.0.0.1:'+$p) -TimeoutSec 15; return ($r.StatusCode -ge 200 -and $r.StatusCode -lt 400) }catch{ return $false } }; $found=0; if($env:CODE_SWITCHER_PROXY_PORT -and (Test-Gh ([int]$env:CODE_SWITCHER_PROXY_PORT))){ Write-Host ('[proxy] using 127.0.0.1:'+$env:CODE_SWITCHER_PROXY_PORT+' (from PROXY_PORT)'); $found=[int]$env:CODE_SWITCHER_PROXY_PORT } ; if(-not $found){ $pairs=@(@{p=(Join-Path $env:APPDATA 'io.github.clash-verge-rev.clash-verge-rev\verge.yaml');r='(?m)^\s*verge_mixed_port:\s*(\d+)'},@{p=(Join-Path $env:APPDATA 'clash-verge\verge.yaml');r='(?m)^\s*verge_mixed_port:\s*(\d+)'},@{p=(Join-Path $env:APPDATA 'io.github.clash-verge-rev.clash-verge-rev\clash-verge.yaml');r='(?m)^\s*mixed-port:\s*(\d+)'},@{p=(Join-Path $env:APPDATA 'clash-verge\clash-verge.yaml');r='(?m)^\s*mixed-port:\s*(\d+)'}); foreach($e in $pairs){ if(Test-Path -LiteralPath $e.p){ $raw=Get-Content -LiteralPath $e.p -Raw; if($raw -match $e.r){ $cand=[int]$Matches[1]; if(Test-Gh $cand){ Write-Host ('[proxy] using 127.0.0.1:'+$cand+' (from Clash config)'); $found=$cand; break } else { Write-Host ('[proxy] Clash config port '+$cand+' not usable for GitHub') } } } } } ; if(-not $found){ Write-Host '[proxy] scanning common ports:'; foreach($cand in @(7897,7890,10809,10808,1080,2080,8889,8080)){ if(Test-Gh $cand){ Write-Host ('[proxy]   127.0.0.1:'+$cand+' ok'); Write-Host ('[proxy] using 127.0.0.1:'+$cand+' (from scan)'); $found=$cand; break } elseif(Test-Tcp $cand){ Write-Host ('[proxy]   127.0.0.1:'+$cand+' open but cannot reach GitHub') } else { Write-Host ('[proxy]   127.0.0.1:'+$cand+' not listening') } } } ; if($found){ Set-Content -LiteralPath $env:PROXY_RESULT -Value $found -Encoding ASCII } else { Set-Content -LiteralPath $env:PROXY_RESULT -Value '' -Encoding ASCII }"

if not exist "%PROXY_RESULT%" (
    set "PROXY_PORT="
    goto ASK_PROXY
)
set /p PROXY_PORT=<"%PROXY_RESULT%"
if exist "%PROXY_RESULT%" del /f /q "%PROXY_RESULT%" >nul 2>&1

if "%PROXY_PORT%"=="" (
    goto ASK_PROXY
)

echo.
goto DOWNLOAD

REM ==========================================
REM Nothing detected: ask the user once (only during a download)
REM ==========================================

:ASK_PROXY
echo.
echo [proxy] no local proxy detected automatically.
echo [proxy] Enter your proxy port (e.g. 7897 / 7890 / 10809),
echo [proxy] or press Enter to download directly / via mirror.
set "USER_PORT="
set /p "USER_PORT=Proxy port: "
if "%USER_PORT%"=="" (
    echo [proxy] no port entered, will download directly.
    echo.
    goto DOWNLOAD
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; $p=[int]$env:USER_PORT; try{ $r=Invoke-WebRequest -UseBasicParsing -Method Head -Uri 'https://raw.githubusercontent.com/Xioaruan912/Xcript/main/windows/codex-switcher/version.txt' -Proxy ('http://127.0.0.1:'+$p) -TimeoutSec 15; if($r.StatusCode -ge 200 -and $r.StatusCode -lt 400){ exit 0 } else { exit 3 } }catch{ exit 3 }"
if errorlevel 1 (
    echo [proxy] port %USER_PORT% cannot reach GitHub through the proxy.
    echo [proxy] will download directly.
    echo.
    goto DOWNLOAD
)
set "PROXY_PORT=%USER_PORT%"
echo [proxy] using 127.0.0.1:%PROXY_PORT% (from user input)
echo.
goto DOWNLOAD

REM ==========================================
REM Download (proxy if available, then GitHub direct, then mirror)
REM ==========================================

:DOWNLOAD
if exist "%PS1_TEMP%" del /f /q "%PS1_TEMP%" >nul 2>&1

echo Fetching latest version, please wait...
echo.

if not "%PROXY_PORT%"=="" (
    echo [proxy] trying download via 127.0.0.1:%PROXY_PORT% ...
    call :DOWNLOAD_ONE "%PS1_URL%" "%PROXY_PORT%"
    if not errorlevel 1 goto DOWNLOAD_OK
    echo [proxy] proxy download failed, falling back.
    echo.
)

call :DOWNLOAD_ONE "%PS1_URL%" ""
if not errorlevel 1 goto DOWNLOAD_OK

echo [info] GitHub direct failed, trying mirror...
echo.
call :DOWNLOAD_ONE "%MIRROR_PREFIX%%PS1_URL%" ""
if not errorlevel 1 goto DOWNLOAD_OK

goto DOWNLOAD_FAILED

:DOWNLOAD_ONE
REM arg %1 = full URL, arg %2 = proxy port (empty = direct)
set "PS1_URL_ONE=%~1"
set "PS1_PROXY_ONE=%~2"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $args=@{UseBasicParsing=$true;Uri=$env:PS1_URL_ONE;OutFile=$env:PS1_TEMP}; if($env:PS1_PROXY_ONE){ $args.Proxy='http://127.0.0.1:'+$env:PS1_PROXY_ONE }; Invoke-WebRequest @args; if ((Get-Item -LiteralPath $env:PS1_TEMP).Length -lt 200) { throw 'Downloaded script is too small' }; $c=Get-Content -LiteralPath $env:PS1_TEMP -Raw; if ($c -notmatch 'Invoke-Main') { throw 'Downloaded file is not the Codex Switcher core script' }" 1>nul 2>nul
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
echo Usage: codex.bat [-force] [-noproxy]
echo.
echo   -force    Ignore cache TTL and fetch the latest version
echo   -noproxy  Skip local proxy detection, download directly
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
