<#
.SYNOPSIS
    Configure and switch Codex between Official OpenAI and OpenCode Go.

.DESCRIPTION
    Supports both:
      1) First-time OpenCode Go setup.
      2) Existing systems where config.toml was already replaced by OpenCode Go.

    The script keeps two reusable templates:
      - %USERPROFILE%\.codex\config.openai.toml
      - %USERPROFILE%\.codex\config.go.toml

    It switches the active Codex config by copying one of those templates to:
      - %USERPROFILE%\.codex\config.toml

    Before every active-config overwrite, it creates a timestamped backup.

    Recovery behavior:
      - If current config.toml is Official/OpenAI, preserve it as config.openai.toml.
      - If current config.toml is OpenCode Go, preserve it as config.go.toml.
      - If config.openai.toml is missing, scan historical backups for the newest
        non-OpenCode-Go config and recover it.
      - If no official backup exists, create a minimal built-in OpenAI config.
      - If config.go.toml is missing, scan historical backups for the newest
        OpenCode Go config and recover it.
      - You can configure/update OpenCode Go at any time from the menu.

    After switching providers, the script attempts to restart ChatGPT Desktop.

.PARAMETER ApiKey
    Optional OpenCode Go API key used during configure/update.

.PARAMETER Model
    Optional OpenCode Go model name used during configure/update.

.EXAMPLE
    .\codex-switcher.ps1

.EXAMPLE
    .\codex-switcher.ps1 -ApiKey sk-xxxx -Model deepseek-v4-flash
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ApiKey,

    [Parameter(Position = 1)]
    [string]$Model
)

$ErrorActionPreference = 'Stop'

# -----------------------------
# Paths
# -----------------------------
$CodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
$ActiveConfig = Join-Path $CodexHome 'config.toml'
$OpenAIConfig = Join-Path $CodexHome 'config.openai.toml'
$GoConfig = Join-Path $CodexHome 'config.go.toml'

New-Item -ItemType Directory -Path $CodexHome -Force | Out-Null

# -----------------------------
# Helpers
# -----------------------------
function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Test-IsOpenCodeGoConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    return [bool](Select-String `
        -LiteralPath $Path `
        -SimpleMatch 'opencode.ai/zen/go' `
        -Quiet `
        -ErrorAction SilentlyContinue)
}

function Backup-ActiveConfig {
    if (-not (Test-Path -LiteralPath $ActiveConfig)) {
        return $null
    }

    $backup = "$ActiveConfig.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
    Copy-Item -LiteralPath $ActiveConfig -Destination $backup -Force
    return $backup
}

function Get-CandidateBackups {
    $patterns = @(
        'config.toml.bak.*',
        'config.backup.toml',
        'config.toml.bak',
        'config.last.toml'
    )

    $all = @()

    foreach ($pattern in $patterns) {
        $all += Get-ChildItem `
            -LiteralPath $CodexHome `
            -Filter $pattern `
            -File `
            -ErrorAction SilentlyContinue
    }

    return $all |
        Sort-Object LastWriteTime -Descending -Unique
}

function Recover-OfficialConfig {
    if (Test-Path -LiteralPath $OpenAIConfig) {
        return $true
    }

    # If the currently active config is not OpenCode Go, preserve it as official.
    if ((Test-Path -LiteralPath $ActiveConfig) -and
        (-not (Test-IsOpenCodeGoConfig -Path $ActiveConfig))) {

        Copy-Item `
            -LiteralPath $ActiveConfig `
            -Destination $OpenAIConfig `
            -Force

        Write-Host "Saved current Official Codex config -> $OpenAIConfig" -ForegroundColor Green
        return $true
    }

    # Otherwise recover newest historical config that is NOT OpenCode Go.
    $candidate = Get-CandidateBackups |
        Where-Object { -not (Test-IsOpenCodeGoConfig -Path $_.FullName) } |
        Select-Object -First 1

    if ($candidate) {
        Copy-Item `
            -LiteralPath $candidate.FullName `
            -Destination $OpenAIConfig `
            -Force

        Write-Host "Recovered Official Codex config from -> $($candidate.Name)" -ForegroundColor Green
        return $true
    }

    # Last-resort clean official config.
    $minimal = @'
model_provider = "openai"
'@

    Write-Utf8NoBom -Path $OpenAIConfig -Content $minimal
    Write-Host "No historical Official config found." -ForegroundColor Yellow
    Write-Host "Created minimal Official Codex config -> $OpenAIConfig" -ForegroundColor Yellow
    return $true
}

function Recover-GoConfig {
    if (Test-Path -LiteralPath $GoConfig) {
        return $true
    }

    # If current active config is OpenCode Go, preserve it.
    if ((Test-Path -LiteralPath $ActiveConfig) -and
        (Test-IsOpenCodeGoConfig -Path $ActiveConfig)) {

        Copy-Item `
            -LiteralPath $ActiveConfig `
            -Destination $GoConfig `
            -Force

        Write-Host "Saved current OpenCode Go config -> $GoConfig" -ForegroundColor Green
        return $true
    }

    # Otherwise recover newest OpenCode Go backup.
    $candidate = Get-CandidateBackups |
        Where-Object { Test-IsOpenCodeGoConfig -Path $_.FullName } |
        Select-Object -First 1

    if ($candidate) {
        Copy-Item `
            -LiteralPath $candidate.FullName `
            -Destination $GoConfig `
            -Force

        Write-Host "Recovered OpenCode Go config from -> $($candidate.Name)" -ForegroundColor Green
        return $true
    }

    return $false
}

function Get-GoModelFromConfig {
    if (-not (Test-Path -LiteralPath $GoConfig)) {
        return $null
    }

    $line = Get-Content -LiteralPath $GoConfig |
        Where-Object { $_ -match '^\s*model\s*=' } |
        Select-Object -First 1

    if (-not $line) {
        return $null
    }

    if ($line -match '^\s*model\s*=\s*"([^"]+)"') {
        return $Matches[1]
    }

    return $null
}

function Configure-OpenCodeGo {
    param(
        [string]$InitialApiKey,
        [string]$InitialModel
    )

    $key = $InitialApiKey
    $selectedModel = $InitialModel

    if (-not $key) {
        $key = $env:OPENCODE_GO_API_KEY
    }

    if (-not $selectedModel) {
        $selectedModel = $env:OPENCODE_MODEL
    }

    if (-not $selectedModel) {
        $existingModel = Get-GoModelFromConfig
        if ($existingModel) {
            $selectedModel = $existingModel
        }
    }

    if (-not $key) {
        $secureKey = Read-Host "Enter your OpenCode Go API key (sk-...)" -AsSecureString
        $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)

        try {
            $key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        }
        finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        }

        if ($key) {
            $key = $key.Trim()
        }
    }

    if (-not $key) {
        Write-Host "No API key provided. OpenCode Go config was not changed." -ForegroundColor Red
        return $false
    }

    if (-not $selectedModel) {
        $selectedModel = Read-Host "Enter model name (Enter = deepseek-v4-flash)"
        if ($selectedModel) {
            $selectedModel = $selectedModel.Trim()
        }
    }

    if (-not $selectedModel) {
        $selectedModel = 'deepseek-v4-flash'
    }

    # Preserve prior Go template before updating it.
    if (Test-Path -LiteralPath $GoConfig) {
        $goBackup = "$GoConfig.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Copy-Item -LiteralPath $GoConfig -Destination $goBackup -Force
        Write-Host "Backed up old OpenCode Go template -> $goBackup"
    }

    $content = @"
model = "$selectedModel"
model_provider = "opencode"

[model_providers.opencode]
name = "OpenCode Go"
base_url = "https://opencode.ai/zen/go/v1"
wire_api = "responses"
experimental_bearer_token = "$key"
"@

    Write-Utf8NoBom -Path $GoConfig -Content $content

    Write-Host ""
    Write-Host "OpenCode Go template updated:" -ForegroundColor Green
    Write-Host "  $GoConfig"
    Write-Host "  Model: $selectedModel"
    Write-Host ""

    # Best-effort TOML validation with Python 3.11+.
    if (Get-Command python -ErrorAction SilentlyContinue) {
        try {
            & python -c "import tomllib; tomllib.load(open(r'$GoConfig','rb')); print('TOML syntax check: OK')" 2>$null
        }
        catch {
            Write-Host "(TOML validation skipped.)" -ForegroundColor DarkYellow
        }
    }

    return $true
}

function Restart-ChatGPTDesktop {
    Write-Host ""
    Write-Host "Restarting ChatGPT Desktop..." -ForegroundColor Cyan

    $processes = Get-Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.ProcessName -match '^(ChatGPT|OpenAI\.ChatGPT)$' -or
            $_.ProcessName -like '*ChatGPT*'
        }

    if ($processes) {
        $processes | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 1500
    }

    # Prefer Windows Start Apps registration.
    $app = Get-StartApps -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'ChatGPT' } |
        Select-Object -First 1

    if ($app) {
        try {
            Start-Process ("shell:AppsFolder\" + $app.AppID)
            Write-Host "ChatGPT Desktop restarted." -ForegroundColor Green
            return
        }
        catch {
            # Continue to executable-path fallback.
        }
    }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\ChatGPT\ChatGPT.exe'),
        (Join-Path $env:LOCALAPPDATA 'ChatGPT\ChatGPT.exe'),
        (Join-Path $env:ProgramFiles 'ChatGPT\ChatGPT.exe')
    )

    $exe = $candidates |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-Object -First 1

    if ($exe) {
        Start-Process $exe
        Write-Host "ChatGPT Desktop restarted." -ForegroundColor Green
        return
    }

    Write-Host "Config switch succeeded, but ChatGPT Desktop could not be auto-started." -ForegroundColor Yellow
    Write-Host "Please start ChatGPT Desktop manually." -ForegroundColor Yellow
}

function Switch-ToOfficial {
    if (-not (Recover-OfficialConfig)) {
        Write-Host "Unable to prepare Official Codex config." -ForegroundColor Red
        return
    }

    $backup = Backup-ActiveConfig
    if ($backup) {
        Write-Host "Backed up active config -> $backup"
    }

    Copy-Item -LiteralPath $OpenAIConfig -Destination $ActiveConfig -Force

    Write-Host ""
    Write-Host "Switched to: Official Codex / OpenAI" -ForegroundColor Green
    Write-Host "Active config: $ActiveConfig"

    Restart-ChatGPTDesktop
}

function Switch-ToGo {
    if (-not (Recover-GoConfig)) {
        Write-Host ""
        Write-Host "OpenCode Go is not configured yet." -ForegroundColor Yellow
        Write-Host "Starting OpenCode Go setup..."
        Write-Host ""

        if (-not (Configure-OpenCodeGo -InitialApiKey $ApiKey -InitialModel $Model)) {
            return
        }
    }

    $backup = Backup-ActiveConfig
    if ($backup) {
        Write-Host "Backed up active config -> $backup"
    }

    Copy-Item -LiteralPath $GoConfig -Destination $ActiveConfig -Force

    $modelName = Get-GoModelFromConfig

    Write-Host ""
    Write-Host "Switched to: OpenCode Go" -ForegroundColor Green
    if ($modelName) {
        Write-Host "Model: $modelName"
    }
    Write-Host "Active config: $ActiveConfig"

    Restart-ChatGPTDesktop
}

function Show-Status {
    Write-Host ""
    Write-Host "================ Current Status ================" -ForegroundColor Cyan
    Write-Host "Codex home : $CodexHome"
    Write-Host "Active     : $ActiveConfig"
    Write-Host ""

    if (-not (Test-Path -LiteralPath $ActiveConfig)) {
        Write-Host "Current provider: No config.toml found" -ForegroundColor Yellow
    }
    elseif (Test-IsOpenCodeGoConfig -Path $ActiveConfig) {
        Write-Host "Current provider: OpenCode Go" -ForegroundColor Green

        $modelName = Get-GoModelFromConfig
        if ($modelName) {
            Write-Host "Current model   : $modelName"
        }
    }
    else {
        Write-Host "Current provider: Official Codex / OpenAI (or other non-Go provider)" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Templates:"
    Write-Host ("  Official : " + $(if (Test-Path -LiteralPath $OpenAIConfig) { '[OK]' } else { '[MISSING]' }) + " $OpenAIConfig")
    Write-Host ("  Go       : " + $(if (Test-Path -LiteralPath $GoConfig) { '[OK]' } else { '[MISSING]' }) + " $GoConfig")

    if (Test-Path -LiteralPath $GoConfig) {
        $goModel = Get-GoModelFromConfig
        if ($goModel) {
            Write-Host "  Go model : $goModel"
        }
    }

    Write-Host "================================================"
    Write-Host ""
}

function Initialize-Templates {
    # Important ordering:
    # 1) Preserve/recover official config.
    # 2) Preserve/recover Go config.
    #
    # This supports both untouched first-time systems and systems where
    # OpenCode Go already replaced config.toml.
    [void](Recover-OfficialConfig)
    [void](Recover-GoConfig)
}

# -----------------------------
# Initialization
# -----------------------------
Initialize-Templates

# -----------------------------
# Interactive menu
# -----------------------------
while ($true) {
    Clear-Host

    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "          Codex Config Switcher"
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " [1] Official Codex / OpenAI"
    Write-Host " [2] OpenCode Go"
    Write-Host " [3] Configure / Update OpenCode Go"
    Write-Host " [4] Show current status"
    Write-Host " [0] Exit"
    Write-Host ""

    $choice = Read-Host "Select [1/2/3/4/0]"

    switch ($choice.Trim()) {
        '1' {
            Switch-ToOfficial
            Write-Host ""
            Read-Host "Press Enter to continue" | Out-Null
        }

        '2' {
            Switch-ToGo
            Write-Host ""
            Read-Host "Press Enter to continue" | Out-Null
        }

        '3' {
            # Make sure Official config has been preserved before any Go changes.
            [void](Recover-OfficialConfig)

            if (Configure-OpenCodeGo -InitialApiKey $ApiKey -InitialModel $Model) {
                Write-Host ""
                $activate = Read-Host "Switch to this OpenCode Go config now? [Y/n]"

                if (-not $activate -or $activate.Trim().ToLowerInvariant() -eq 'y') {
                    Switch-ToGo
                }
            }

            Write-Host ""
            Read-Host "Press Enter to continue" | Out-Null
        }

        '4' {
            Show-Status
            Read-Host "Press Enter to continue" | Out-Null
        }

        '0' {
            break
        }

        default {
            Write-Host "Invalid selection." -ForegroundColor Yellow
            Start-Sleep -Milliseconds 700
        }
    }
}
