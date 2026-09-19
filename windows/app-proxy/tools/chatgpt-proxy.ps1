<#
.SYNOPSIS
    按进程代理启动器：让 MSIX / Electron 应用（默认 ChatGPT Desktop）单独走本地混合代理。

.DESCRIPTION
    在不修改系统代理、不开启 TUN、不装内核驱动的前提下，只让目标应用进程走
    本地混合代理端口（默认读 Clash Verge 的 mixed-port，通常 7897）。

    实现方式：
      - 用 IApplicationActivationManager 以 AUMID 激活 MSIX 应用，并向其传入
        Chromium 的 --proxy-server / --proxy-bypass-list 参数。
        这样既保留包身份（许可 / 通知 / 更新不受影响），又能让它的流量进代理。

    自动侦察：
      - AUMID：Get-StartApps 按名称匹配（默认 ChatGPT）。
      - 代理端口：依次读 verge.yaml 的 verge_mixed_port、
        clash-verge.yaml / config.yaml 的 mixed-port，回退 7897。
      - 安装目录：由 PackageFamilyName 反查 InstallLocation（不写死版本号路径）。

.PARAMETER AppNameMatch
    Get-StartApps 的名称匹配关键字，默认 ChatGPT。

.PARAMETER Aumid
    直接指定 AUMID（形如 <PackageFamilyName>!App）。指定后跳过自动探测。

.PARAMETER ProcessNames
    启动前要结束的进程名，默认 ChatGPT。

.PARAMETER Port
    本地混合代理端口。默认 0 表示自动读取。

.PARAMETER BypassList
    --proxy-bypass-list 的值，默认 localhost;127.0.0.1。

.PARAMETER AppExeName
    应用主可执行文件名，用于回退直连与快捷方式图标，默认 ChatGPT.exe。

.PARAMETER BypassList
    见上。

.PARAMETER DirectExe
    回退模式：直接运行安装目录下的 exe 并带参数（牺牲 MSIX 包身份）。

.PARAMETER SetChildProxyEnv
    在当前进程设置 HTTP_PROXY / HTTPS_PROXY / NO_PROXY（进程作用域，仅被本次
    启动的进程树继承，不影响系统其他程序）。主要对 DirectExe 回退有效。

.PARAMETER NoKill
    启动前不结束已有同名进程（Electron 单实例时可能导致参数被忽略）。

.PARAMETER Verify
    启动后自动检测该应用是否有到 127.0.0.1:<Port> 的 Established 连接。

.PARAMETER CreateShortcut
    在当前用户桌面创建「<名称> (代理).lnk」，然后退出。

.PARAMETER DryRun
    只打印探测结果，不结束进程、不启动、不建快捷方式。

.EXAMPLE
    .\chatgpt-proxy.ps1
    结束并重新以代理方式启动 ChatGPT。

.EXAMPLE
    .\chatgpt-proxy.ps1 -Verify
    启动并检测是否命中本地代理。

.EXAMPLE
    .\chatgpt-proxy.ps1 -CreateShortcut
    在桌面生成「ChatGPT (代理)」快捷方式。
#>

[CmdletBinding()]
param(
    [string]$AppNameMatch = 'ChatGPT',
    [string]$Aumid,
    [string[]]$ProcessNames = @('ChatGPT'),
    [int]$Port = 0,
    [string]$BypassList = 'localhost;127.0.0.1',
    [string]$AppExeName = 'ChatGPT.exe',
    [string]$ShortcutName,
    [switch]$DirectExe,
    [switch]$SetChildProxyEnv,
    [switch]$NoKill,
    [switch]$Verify,
    [switch]$CreateShortcut,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
try { $OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

function Write-Head    { param([string]$Text) Write-Host ""; Write-Host "==========================================" -ForegroundColor Cyan; Write-Host $Text; Write-Host "==========================================" -ForegroundColor Cyan }
function Write-Ok      { param([string]$Text) Write-Host $Text -ForegroundColor Green }
function Write-Info    { param([string]$Text) Write-Host $Text -ForegroundColor Cyan }
function Write-Dim     { param([string]$Text) Write-Host $Text -ForegroundColor DarkGray }
function Write-Warn    { param([string]$Text) Write-Host $Text -ForegroundColor Yellow }
function Write-Err     { param([string]$Text) Write-Host $Text -ForegroundColor Red }

# ============================================================
# 端口探测：Clash Verge
# ============================================================
function Get-MixedProxyPort {
    $configRoots = @(
        (Join-Path $env:APPDATA 'io.github.clash-verge-rev.clash-verge-rev'),
        (Join-Path $env:LOCALAPPDATA 'io.github.clash-verge-rev.clash-verge-rev'),
        (Join-Path $env:APPDATA 'io.github.clash-verge-rev.clash-verge'),
        (Join-Path $env:APPDATA 'clash-verge'),
        (Join-Path $env:LOCALAPPDATA 'clash-verge')
    )
    $checked = @()
    foreach ($root in $configRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        # 优先 verge.yaml 的 verge_mixed_port
        $verge = Join-Path $root 'verge.yaml'
        if (Test-Path -LiteralPath $verge) {
            $checked += $verge
            $m = Select-String -LiteralPath $verge -Pattern '^\s*verge_mixed_port\s*:\s*(\d+)' -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($m) { return [int]$m.Matches[0].Groups[1].Value }
        }
        foreach ($name in @('clash-verge.yaml', 'config.yaml')) {
            $f = Join-Path $root $name
            if (-not (Test-Path -LiteralPath $f)) { continue }
            $checked += $f
            $m = Select-String -LiteralPath $f -Pattern '^\s*mixed-port\s*:\s*(\d+)' -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($m) { return [int]$m.Matches[0].Groups[1].Value }
        }
    }
    $checked | Select-Object -Unique | ForEach-Object { Write-Dim "  已检查：$_" }
    return $null
}

function Test-ProxyAlive {
    param([int]$ProxyPort)
    try {
        $r = Invoke-RestMethod -Uri 'https://ipinfo.io/json' -Proxy "http://127.0.0.1:$ProxyPort" -TimeoutSec 20
        return $r
    }
    catch {
        return $null
    }
}

# ============================================================
# AUMID / 安装目录
# ============================================================
function Resolve-Aumid {
    if ($Aumid) { return $Aumid.Trim() }
    if (-not (Get-Command Get-StartApps -ErrorAction SilentlyContinue)) {
        throw "系统不支持 Get-StartApps，请用 -Aumid 手动指定。"
    }
    $app = Get-StartApps | Where-Object { $_.Name -match $AppNameMatch } | Select-Object -First 1
    if (-not $app) { throw "未找到匹配 '$AppNameMatch' 的已安装应用，请用 -Aumid 指定。" }
    return $app.AppID
}

function Resolve-InstallLocation {
    param([string]$TargetAumid)
    $pfn = ($TargetAumid -split '!')[0]
    $pkg = Get-AppxPackage | Where-Object { $_.PackageFamilyName -eq $pfn } | Select-Object -First 1
    if (-not $pkg) { return $null }
    return $pkg.InstallLocation
}

# ============================================================
# C# 互操作：IApplicationActivationManager
# ============================================================
function Initialize-ActivationManager {
    $typeName = 'AppProxy.AppActivator'
    if (-not ([System.Management.Automation.PSTypeName]$typeName).Type) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace AppProxy
{
    [ComImport, Guid("2e941141-7f97-4756-ba1d-9decde894a3d"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IApplicationActivationManager
    {
        [PreserveSig]
        int ActivateApplication(
            [In, MarshalAs(UnmanagedType.LPWStr)] string appUserModelId,
            [In, MarshalAs(UnmanagedType.LPWStr)] string arguments,
            [In] int options,
            [Out] out uint processId);

        [PreserveSig]
        int ActivateForFile(
            [In, MarshalAs(UnmanagedType.LPWStr)] string appUserModelId,
            [In] IntPtr itemArray,
            [In, MarshalAs(UnmanagedType.LPWStr)] string verb,
            [Out] out uint processId);

        [PreserveSig]
        int ActivateForProtocol(
            [In, MarshalAs(UnmanagedType.LPWStr)] string appUserModelId,
            [In] IntPtr itemArray,
            [Out] out uint processId);
    }

    [ComImport, Guid("45BA127D-10A8-46EA-8AB7-56EA9078943C")]
    public class ApplicationActivationManager
    {
    }

    public static class AppActivator
    {
        public static uint Activate(string appUserModelId, string arguments)
        {
            Type t = Type.GetTypeFromCLSID(new Guid("45BA127D-10A8-46EA-8AB7-56EA9078943C"));
            IApplicationActivationManager mgr =
                (IApplicationActivationManager)Activator.CreateInstance(t);
            uint pid;
            int hr = mgr.ActivateApplication(appUserModelId, arguments, 0, out pid);
            if (hr < 0) { Marshal.ThrowExceptionForHR(hr); }
            return pid;
        }
    }
}
'@
    }
}

# ============================================================
# 启动 / 结束进程
# ============================================================
function Stop-TargetProcesses {
    $found = @(Get-Process -Name $ProcessNames -ErrorAction SilentlyContinue)
    if ($found.Count -eq 0) { Write-Dim "没有正在运行的 $($ProcessNames -join ', ') 进程。"; return }
    Write-Info "结束 $($found.Count) 个进程：$($found.Id -join ', ')"
    $found | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
}

function Start-ViaActivation {
    param([string]$TargetAumid, [string]$Arguments, [string]$InstallLocation)
    [void](Initialize-ActivationManager)
    $procId = [AppProxy.AppActivator]::Activate($TargetAumid, $Arguments)
    if ($procId -eq 0) { throw "ActivateApplication 返回 PID 0。" }
    return [uint32]$procId
}

function Start-ViaExe {
    param([string]$InstallLocation, [string]$ExeName, [string]$Arguments)
    $sub = Join-Path $InstallLocation 'app'
    $exe = Join-Path $sub $ExeName
    if (-not (Test-Path -LiteralPath $exe)) {
        $exe = Join-Path $InstallLocation $ExeName
    }
    if (-not (Test-Path -LiteralPath $exe)) {
        throw "找不到可执行文件：$ExeName（安装目录 $InstallLocation）"
    }
    if ($SetChildProxyEnv) {
        $env:HTTP_PROXY  = "http://127.0.0.1:$Port"
        $env:HTTPS_PROXY = "http://127.0.0.1:$Port"
        $env:NO_PROXY    = $BypassList.Replace(';', ',')
        Write-Dim "已在当前进程设置 HTTP(S)_PROXY / NO_PROXY（仅本次启动的进程树继承）。"
    }
    $p = Start-Process -FilePath $exe -ArgumentList $Arguments -PassThru
    return [uint32]$p.Id
}

# ============================================================
# 验证：是否有到本地代理的 Established 连接
# ============================================================
function Test-ProxyConnection {
    param([uint32]$MainPid, [int]$ProxyPort)
    $procs = @()
    if ($MainPid) { $procs += [int]$MainPid }
    foreach ($n in $ProcessNames) {
        $procs += @(Get-Process -Name $n -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
    }
    $procs = @($procs | Select-Object -Unique)
    if ($procs.Count -eq 0) { return [pscustomobject]@{ Ok = $false; Procs = @(); Established = @(); SynSent = @() } }

    $conns = @()
    foreach ($id in $procs) {
        $conns += @(Get-NetTCPConnection -OwningProcess $id -ErrorAction SilentlyContinue)
    }

    $est = @($conns | Where-Object {
        $_.State -eq 'Established' -and
        ($_.RemoteAddress -eq '127.0.0.1' -or $_.RemoteAddress -eq '::1') -and
        $_.RemotePort -eq $ProxyPort
    })
    $syn = @($conns | Where-Object {
        $_.State -eq 'SynSent' -and
        $_.RemoteAddress -notmatch '^(127\.|::1|0\.0\.0\.0|::)'
    })

    return [pscustomobject]@{ Ok = ($est.Count -gt 0); Procs = $procs; Established = $est; SynSent = $syn }
}

# ============================================================
# 快捷方式
# ============================================================
function New-ProxyShortcut {
    param([string]$Name, [string]$InstallLocation)
    $desktop = [Environment]::GetFolderPath('Desktop')
    $lnk = Join-Path $desktop ($Name + '.lnk')
    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($lnk)
    $sc.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $sc.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    $sc.WorkingDirectory = Split-Path -Parent $PSCommandPath
    if ($InstallLocation) {
        $icon = Join-Path (Join-Path $InstallLocation 'app') $AppExeName
        if (-not (Test-Path -LiteralPath $icon)) { $icon = Join-Path $InstallLocation $AppExeName }
        if (Test-Path -LiteralPath $icon) { $sc.IconLocation = "$icon,0" }
    }
    $sc.Description = "通过本地代理启动 $AppNameMatch"
    $sc.Save()
    return $lnk
}

# ============================================================
# 主流程
# ============================================================
$resolvedAumid = Resolve-Aumid
$installLocation = Resolve-InstallLocation -TargetAumid $resolvedAumid

if ($Port -le 0) {
    $detected = Get-MixedProxyPort
    if ($detected) { $Port = $detected } else { $Port = 7897 }
}

if (-not $ShortcutName) { $ShortcutName = "$AppNameMatch (代理)" }

Write-Head "按进程代理启动器"
Write-Host "AUMID      : $resolvedAumid"
Write-Host "进程名     : $($ProcessNames -join ', ')"
Write-Host "代理端口   : 127.0.0.1:$Port"
Write-Host "Bypass     : $BypassList"
if ($installLocation) { Write-Host "安装目录   : $installLocation" }

# 代理可用性
$proxyInfo = Test-ProxyAlive -ProxyPort $Port
if ($proxyInfo) {
    Write-Ok "代理可用：出口 $($proxyInfo.ip) / $($proxyInfo.country) $($proxyInfo.city)"
}
else {
    Write-Warn "无法通过 127.0.0.1:$Port 访问 ipinfo.io，请确认代理已开启且端口正确。"
}

if ($DryRun) {
    Write-Info "[DryRun] 探测完成，未做任何改动。"
    return
}

if ($CreateShortcut) {
    $lnk = New-ProxyShortcut -Name $ShortcutName -InstallLocation $installLocation
    Write-Ok "已创建快捷方式：$lnk"
    Write-Dim "以后请从该快捷方式启动；建议关闭应用自身的开机自启 / 托盘常驻。"
    return
}

# 结束旧进程（Electron 单实例会忽略新参数）
if (-not $NoKill) { Stop-TargetProcesses }

$proxyArgs = "--proxy-server=`"http://127.0.0.1:$Port`" --proxy-bypass-list=`"$BypassList`""

if ($DirectExe) {
    Write-Warn "使用直连 exe 回退模式（牺牲 MSIX 包身份，可能影响通知 / 更新）。"
    $launchedPid = Start-ViaExe -InstallLocation $installLocation -ExeName $AppExeName -Arguments $proxyArgs
}
else {
    if ($SetChildProxyEnv) {
        Write-Dim "注意：MSIX 激活方式不保证继承当前进程环境变量，子进程代理建议改用 -DirectExe。"
    }
    try {
        $launchedPid = Start-ViaActivation -TargetAumid $resolvedAumid -Arguments $proxyArgs -InstallLocation $installLocation
    }
    catch {
        Write-Warn "MSIX 激活失败：$($_.Exception.Message)"
        Write-Warn "转入直连 exe 回退模式。"
        $launchedPid = Start-ViaExe -InstallLocation $installLocation -ExeName $AppExeName -Arguments $proxyArgs
    }
}

Write-Ok "已启动，主进程 PID：$launchedPid"

if ($Verify) {
    Write-Info "等待网络栈就绪后检测代理连接（约 5 秒）..."
    Start-Sleep -Seconds 5
    $result = Test-ProxyConnection -MainPid $launchedPid -ProxyPort $Port
    Write-Host ""
    Write-Host "相关进程 PID：$($result.Procs -join ', ')"
    if ($result.Ok) {
        Write-Ok "检测通过：存在到 127.0.0.1:$Port 的 Established 连接。"
        $result.Established | Select-Object -First 8 |
            ForEach-Object { Write-Dim ("  {0}:{1} <- {2}" -f $_.LocalAddress, $_.LocalPort, $_.RemoteAddress + ':' + $_.RemotePort) }
    }
    else {
        Write-Err "未检测到到本地代理的连接。"
        if ($result.SynSent.Count -gt 0) {
            Write-Warn "检测到发往公网地址的 SynSent（疑似未进代理 / DNS 污染）："
            $result.SynSent | Select-Object -First 8 |
                ForEach-Object { Write-Dim ("  -> {0}:{1}" -f $_.RemoteAddress, $_.RemotePort) }
        }
        Write-Warn "该 Electron 主进程可能丢弃了未知 argv，请改用 -DirectExe，或使用按进程代理工具。"
    }
}
else {
    Write-Dim "可用 -Verify 重新启动并检测；或稍后手动查看 Get-NetTCPConnection。"
}
