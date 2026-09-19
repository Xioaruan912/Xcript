@echo off
rem ============================================================================
rem  ChatGPT per-process proxy launcher  -  portable, single file
rem  --------------------------------------------------------------------------
rem  Double-click to launch.  Everything is embedded below the payload marker.
rem  No external files, no install, no admin rights required.
rem
rem  HOW TO CUSTOMIZE (edit the four lines below):
rem    APP_PKG_MATCH : regex matched against Get-AppxPackage Name
rem    APP_PROC      : process name to close before launch (empty = auto from manifest)
rem    PROXY_PORT    : local mixed-proxy port (empty = auto from Clash Verge config)
rem    PROXY_BYPASS  : Chromium --proxy-bypass-list value
rem
rem  ARGS:  direct | env | port=7897 | aumid=<AUMID> | make-shortcut | help
rem      direct        launch the exe directly (loses MSIX identity) - fallback
rem      env           also write user-level HTTP_PROXY/HTTPS_PROXY/NO_PROXY
rem      make-shortcut create a desktop shortcut (with app icon, hidden window)
rem ============================================================================
set "APP_PKG_MATCH=OpenAI|ChatGPT"
set "APP_PROC="
set "PROXY_PORT="
set "PROXY_BYPASS=localhost;127.0.0.1"

setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
set "SELF=%~f0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false);$t=[IO.File]::ReadAllText($env:SELF,[Text.Encoding]::UTF8);$m='#__PS_PAYLOAD__'+'#';$i=$t.IndexOf($m);if($i -lt 0){Write-Error 'payload marker not found';exit 9};$sb=$t.Substring($i+$m.Length);& ([ScriptBlock]::Create($sb)) @args" %*
set "rc=%ERRORLEVEL%"
if not "%rc%"=="0" (
    echo.
    echo [!] Launcher exited with code %rc%.  Run "%~nx0 help" for options.
    pause
)
exit /b %rc%
#__PS_PAYLOAD__#
$ErrorActionPreference = 'Stop'
$Marker = '#__PS_PAYLOAD__' + '#'

$PackageMatch = if ($env:APP_PKG_MATCH) { $env:APP_PKG_MATCH } else { 'OpenAI|ChatGPT' }
$BypassList   = if ($env:PROXY_BYPASS)  { $env:PROXY_BYPASS }  else { 'localhost;127.0.0.1' }
$Port = $null
if ($env:PROXY_PORT) { $Port = [int]$env:PROXY_PORT }
$Aumid = $null
$SetUserEnv = $false
$DirectFallback = $false
$MakeShortcut = $false

function Show([string]$m) { Write-Host "[ChatGPT-Proxy] $m" }

foreach ($a in $args) {
    if     ($a -match '(?i)^direct$')        { $DirectFallback = $true }
    elseif ($a -match '(?i)^env$')           { $SetUserEnv = $true }
    elseif ($a -match '(?i)^make-shortcut$') { $MakeShortcut = $true }
    elseif ($a -match '(?i)^port=(\d+)$')    { $Port = [int]$Matches[1] }
    elseif ($a -match '(?i)^aumid=(.+)$')    { $Aumid = $Matches[1] }
    elseif ($a -match '(?i)^(-h|help|/\?)$') {
        Write-Host '用法: 双击直接启动，或带参数运行：'
        Write-Host '  direct        直连 exe（放弃 MSIX 包身份），仅当 AUMID 激活丢弃参数时的回退'
        Write-Host '  env           为非 Chromium 子进程写入用户级 HTTP_PROXY/HTTPS_PROXY/NO_PROXY'
        Write-Host '  port=NNNN     指定本地混合代理端口（默认自动探测，探测不到会询问）'
        Write-Host '  aumid=...     指定 AUMID（默认自动从 Get-StartApps 解析）'
        Write-Host '  make-shortcut 在桌面创建带应用图标的快捷方式（隐藏窗口启动）'
        exit 0
    }
}

# ---- 1. 定位已安装的 MSIX 包（不硬编码版本号路径）
$pkg = Get-AppxPackage | Where-Object { $_.Name -match $PackageMatch } | Select-Object -First 1
if (-not $pkg) { throw "未找到匹配 '$PackageMatch' 的 MSIX 包，请确认应用已安装。" }
$InstallLocation = $pkg.InstallLocation

# ---- 2. 进程名：优先环境变量，否则从 AppxManifest 的 Executable 自动推导
$ProcessName = $env:APP_PROC
if (-not $ProcessName) {
    try {
        $mf = Join-Path $InstallLocation 'AppxManifest.xml'
        if (Test-Path -LiteralPath $mf) {
            $xml = Get-Content -LiteralPath $mf -Raw
            if ($xml -match 'Executable="([^"]+\.exe)"') {
                $ProcessName = [IO.Path]::GetFileNameWithoutExtension($Matches[1])
            }
        }
    } catch { }
    if (-not $ProcessName) { $ProcessName = 'ChatGPT' }
}

# ---- 3. AUMID：优先参数，否则按 PackageFamilyName 从 Get-StartApps 解析
if (-not $Aumid) {
    $start = Get-StartApps | Where-Object { $_.AppID -like "$($pkg.PackageFamilyName)!*" } | Select-Object -First 1
    if ($start) { $Aumid = $start.AppID } else { $Aumid = "$($pkg.PackageFamilyName)!App" }
}

# ---- 4. 代理端口：命令行 > 环境变量 > Clash 配置 > 扫描常见端口 > 询问用户
#      全程只读，不写入任何配置文件。

function Test-PortOpen([int]$p) {
    if ($p -lt 1 -or $p -gt 65535) { return $false }
    try {
        $t = New-Object Net.Sockets.TcpClient
        $iar = $t.BeginConnect('127.0.0.1', $p, $null, $null)
        if ($iar.AsyncWaitHandle.WaitOne(300)) { $t.EndConnect($iar); $t.Close(); return $true }
        $t.Close(); return $false
    } catch { return $false }
}

function Test-ProxyPort([int]$p) {
    if (-not (Test-PortOpen $p)) { return $false }
    try {
        $r = Invoke-RestMethod -Uri 'https://ipinfo.io/json' -Proxy "http://127.0.0.1:$p" -TimeoutSec 12 -ErrorAction Stop
        return [bool]$r.ip
    } catch { return $false }
}

Show "代理端口探测："

# 4a. 命令行 / 环境变量（用户显式指定）
if ($Port) {
    Show "  来源：命令行 port=$Port"
}

# 4b. 读取 Clash Verge 配置
if (-not $Port) {
    $pairs = @(
        @{ p = (Join-Path $env:APPDATA 'io.github.clash-verge-rev.clash-verge-rev\verge.yaml');       r = '(?m)^\s*verge_mixed_port:\s*(\d+)' },
        @{ p = (Join-Path $env:APPDATA 'clash-verge\verge.yaml');                                   r = '(?m)^\s*verge_mixed_port:\s*(\d+)' },
        @{ p = (Join-Path $env:APPDATA 'io.github.clash-verge-rev.clash-verge-rev\clash-verge.yaml'); r = '(?m)^\s*mixed-port:\s*(\d+)' },
        @{ p = (Join-Path $env:APPDATA 'clash-verge\clash-verge.yaml');                             r = '(?m)^\s*mixed-port:\s*(\d+)' }
    )
    foreach ($e in $pairs) {
        if (Test-Path -LiteralPath $e.p) {
            $raw = Get-Content -LiteralPath $e.p -Raw
            if ($raw -match $e.r) {
                $cand = [int]$Matches[1]
                if (Test-PortOpen $cand) {
                    $Port = $cand
                    Show "  Clash 配置 $($e.p)：端口 $cand（已监听）"
                    break
                } else {
                    Show "  Clash 配置 $($e.p)：端口 $cand（未监听，跳过）"
                }
            }
        }
    }
    if (-not $Port) { Show "  未从 Clash 配置读到可用端口。" }
}

# 4c. 扫描本机常见代理端口，挑一个真正能代理的（打印每个尝试结果）
if (-not $Port) {
    Show "  正在扫描本机常见代理端口："
    foreach ($cand in @(7897, 7890, 10809, 10808, 1080, 2080, 8889, 8080)) {
        if (Test-PortOpen $cand) {
            if (Test-ProxyPort $cand) {
                $Port = $cand
                Show "    127.0.0.1:$cand 可用（已命中）"
                break
            } else {
                Show "    127.0.0.1:$cand 端口通，但无法代理访问网络"
            }
        } else {
            Show "    127.0.0.1:$cand 未监听"
        }
    }
}

# 4d. 仍然没有：询问用户
if (-not $Port) {
    Write-Host ''
    Write-Host '[ChatGPT-Proxy] 未能自动检测到本地代理端口。' -ForegroundColor Yellow
    Write-Host '请输入你的代理混合端口（http 代理），例如 7897 / 7890 / 10809。' -ForegroundColor Yellow
    if ($env:SELF -and [Console]::IsInputRedirected) {
        throw '非交互环境且未提供端口，请使用 port=NNNN 参数指定。'
    }
    for ($try = 0; $try -lt 3; $try++) {
        $ans = Read-Host '代理端口'
        if ($ans -match '^\d+$') {
            $cand = [int]$ans
            if (Test-ProxyPort $cand) { $Port = $cand; Show "  使用手动输入端口：$cand"; break }
            Write-Host "[ChatGPT-Proxy] 端口 $cand 未能通过代理访问网络，请确认代理已开启。" -ForegroundColor Yellow
        } else {
            Write-Host '[ChatGPT-Proxy] 请输入纯数字端口。' -ForegroundColor Yellow
        }
    }
    if (-not $Port) { throw '未获得可用的代理端口，已退出。' }
}

$ProxyServer = "http://127.0.0.1:$Port"

Show "包     : $($pkg.PackageFullName)"
Show "进程   : $ProcessName"
Show "AUMID  : $Aumid"
Show "代理   : $ProxyServer"

# ---- 5. 可选：生成桌面快捷方式（路径运行时解析，快捷方式可随本文件一起迁移）
if ($MakeShortcut) {
    if (-not $env:SELF) { throw 'make-shortcut 需要通过 .bat 运行（找不到 SELF 路径）。' }
    $exe = Join-Path $InstallLocation 'app\ChatGPT.exe'
    if (-not (Test-Path -LiteralPath $exe)) {
        $exe = (Get-ChildItem -LiteralPath (Join-Path $InstallLocation 'app') -Filter *.exe -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notmatch 'chrome_|elevation|notification|tracing|wer|pwa' } |
                Sort-Object Length -Descending | Select-Object -First 1).FullName
    }
    $self = $env:SELF.Replace("'", "''")
    $cmd = '$t=[IO.File]::ReadAllText(''' + $self + ''',[Text.Encoding]::UTF8);$m=''' + $Marker + ''';$i=$t.IndexOf($m);& ([ScriptBlock]::Create($t.Substring($i+$m.Length)))'
    $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'ChatGPT (代理).lnk'
    $ws = New-Object -ComObject WScript.Shell
    $s = $ws.CreateShortcut($lnk)
    $s.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $s.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "' + $cmd + '"'
    $s.WorkingDirectory = Split-Path -Parent $env:SELF
    # 图标直接用应用 exe，不额外落地 .ico 文件
    if ($exe -and (Test-Path -LiteralPath $exe)) { $s.IconLocation = "$exe,0" }
    $s.Description = 'ChatGPT 按进程代理启动（保留 MSIX 包身份）'
    $s.Save()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($ws) | Out-Null
    Show "快捷方式已创建: $lnk"
    exit 0
}

# ---- 6. 结束旧实例（Electron 单实例：旧实例会吞掉新参数）
Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process -Name 'codex' -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -and $_.Path -like "$InstallLocation\*" } |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 800

# ---- 7. 可选：为独立网络栈子进程设置用户级代理环境变量
if ($SetUserEnv) {
    [Environment]::SetEnvironmentVariable('HTTP_PROXY',  $ProxyServer, 'User')
    [Environment]::SetEnvironmentVariable('HTTPS_PROXY', $ProxyServer, 'User')
    [Environment]::SetEnvironmentVariable('NO_PROXY',    ($BypassList -replace ';', ','), 'User')
    Show '已写入用户级 HTTP_PROXY / HTTPS_PROXY / NO_PROXY'
}

# ---- 8. C# 互操作：IApplicationActivationManager（保留包身份 + 传参）
if (-not ('ShellActivation' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class ShellActivation
{
    [ComImport, Guid("2e941141-7f97-4756-ba1d-9decde894a3d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IApplicationActivationManager
    {
        [PreserveSig]
        int ActivateApplication([In] string appUserModelId, [In] string arguments, [In] int options, [Out] out uint processId);
    }

    [ComImport, Guid("45BA127D-10A8-46EA-8AB7-56EA9078943C")]
    private class ApplicationActivationManager { }

    public static uint Activate(string aumid, string arguments)
    {
        var mgr = (IApplicationActivationManager)new ApplicationActivationManager();
        uint pid;
        int hr = mgr.ActivateApplication(aumid, arguments, 0, out pid);
        if (hr < 0) throw new COMException("ActivateApplication failed (hr=0x" + hr.ToString("X8") + ")", hr);
        return pid;
    }
}
'@
}

$arguments = '--proxy-server="{0}" --proxy-bypass-list="{1}"' -f $ProxyServer, $BypassList
Show "参数   : $arguments"

# ---- 9. 启动
if ($DirectFallback) {
    $exe = Join-Path $InstallLocation 'app\ChatGPT.exe'
    Show "回退：直接运行 exe（丢失包身份）: $exe"
    $appPid = (Start-Process -FilePath $exe -ArgumentList $arguments -PassThru).Id
} else {
    $appPid = [ShellActivation]::Activate($Aumid, $arguments)
}
Show "PID    : $appPid"

# ---- 10. 验证：必须出现到 127.0.0.1:<port> 的 Established
Show '验证到本地代理的连接...'
$deadline = (Get-Date).AddSeconds(25)
$hit = $null
do {
    Start-Sleep -Milliseconds 500
    foreach ($pr in (Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)) {
        $hit = Get-NetTCPConnection -OwningProcess $pr.Id -ErrorAction SilentlyContinue |
               Where-Object { $_.State -eq 'Established' -and $_.RemoteAddress -eq '127.0.0.1' -and $_.RemotePort -eq $Port } |
               Select-Object -First 1
        if ($hit) { break }
    }
} while (-not $hit -and (Get-Date) -lt $deadline)

if ($hit) {
    Write-Host ''
    Write-Host ("SUCCESS / 成功 : PID {0} -> {1}:{2} established" -f $hit.OwningProcess, $hit.RemoteAddress, $hit.RemotePort) -ForegroundColor Green
    Write-Host 'App traffic is now going through the local proxy (DNS resolved remotely).' -ForegroundColor Green
    Write-Host '应用流量已走本地代理，DNS 由代理远端解析。' -ForegroundColor Green
    exit 0
} else {
    Write-Host ''
    Write-Host 'FAILED / 失败 : no Established connection to the local proxy.' -ForegroundColor Red
    Write-Host 'The main process likely discarded the unknown argv (未发现到本地代理的连接).' -ForegroundColor Red
    Write-Host 'Fallback 1 / 回退1 : ChatGPT-Proxy.bat direct' -ForegroundColor Yellow
    Write-Host ("Fallback 2 / 回退2 : Proxifier/Netch/Proxinject rule  {0}.exe -> HTTPS 127.0.0.1:{1}" -f $ProcessName, $Port) -ForegroundColor Yellow
    exit 1
}
