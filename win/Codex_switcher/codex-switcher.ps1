# Codex 配置切换器已迁移到 windows/codex-switcher/。
# 本文件仅用于兼容旧链接，会自动下载并运行新版本。
$ErrorActionPreference = 'Stop'
$newUrl = 'https://raw.githubusercontent.com/Xioaruan912/Xcript/main/windows/codex-switcher/codex-switcher.ps1'
$tmp = Join-Path $env:TEMP 'codex-switcher-latest.ps1'
Write-Host '[*] 脚本已迁移，正在获取新版本...' -ForegroundColor Yellow
Invoke-WebRequest -UseBasicParsing -Uri $newUrl -OutFile $tmp
& $tmp @args
