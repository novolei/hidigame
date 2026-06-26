param(
    [string]$GodotExe = "godot",
    [string]$Preset = "Windows Desktop",
    [string]$OutputPath = "newrelease\maomao_server.pck",
    [int]$SmokePort = 18080,
    [int]$SmokeSeconds = 14,
    [switch]$SkipSmokeTest,
    [switch]$SmokeOnly
)

$ErrorActionPreference = "Stop"

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$projectFile = Join-Path $repo "project.godot"
$backupFile = Join-Path $repo ("project.godot.server-export-backup-{0}" -f (Get-Date -Format "yyyyMMddHHmmssfff"))
$outputAbs = Join-Path $repo $OutputPath
$outputDir = Split-Path -Parent $outputAbs
$smokeLog = Join-Path $repo "newrelease\maomao_server_smoke.log"
$smokeErr = Join-Path $repo "newrelease\maomao_server_smoke.err.log"

$serverExcludedAutoloads = @(
    "SimpleGrass",
    "BootSplashPlus",
    "_fennara_game_capture",
    "AmbientCG",
    "_mcp_game_helper"
)

function Invoke-External {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList
    )

    Write-Host ("$FilePath " + ($ArgumentList -join " "))
    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $FilePath"
    }
}

function Read-TextFile {
    param([string]$Path)
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        try {
            return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
        } catch [System.IO.IOException] {
            Start-Sleep -Milliseconds 250
        }
    }
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-TextFile {
    param(
        [string]$Path,
        [string]$Content
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Remove-ServerExcludedAutoloads {
    param([string]$Content)

    $removed = New-Object System.Collections.Generic.List[string]
    $outLines = New-Object System.Collections.Generic.List[string]
    $inAutoload = $false
    $inEditorPlugins = $false
    $disabledEditorPlugins = $false
    $lines = [System.Text.RegularExpressions.Regex]::Split($Content, "\r?\n")

    foreach ($line in $lines) {
        if ($line -match "^\[(.+)\]\s*$") {
            $inAutoload = ($Matches[1] -eq "autoload")
            $inEditorPlugins = ($Matches[1] -eq "editor_plugins")
            $outLines.Add($line)
            continue
        }

        if ($inAutoload -and $line -match "^([^=]+)=") {
            $key = $Matches[1].Trim()
            if ($serverExcludedAutoloads -contains $key) {
                $removed.Add($key)
                continue
            }
        }

        if ($inEditorPlugins -and $line -match "^enabled=") {
            $outLines.Add("enabled=PackedStringArray()")
            $disabledEditorPlugins = $true
            continue
        }

        $outLines.Add($line)
    }

    $uniqueRemoved = $removed | Sort-Object -Unique
    if ($uniqueRemoved.Count -eq 0) {
        Write-Warning "No server-excluded autoloads were removed. Check project.godot format."
    } else {
        Write-Host ("Removed server-only autoload references: " + ($uniqueRemoved -join ", ")) -ForegroundColor Cyan
    }
    if ($disabledEditorPlugins) {
        Write-Host "Disabled editor plugins for this server export." -ForegroundColor Cyan
    } else {
        Write-Warning "Editor plugin list was not found. Export may still run editor plugin startup hooks."
    }

    return ($outLines -join "`r`n")
}

function Stop-SmokeProcess {
    param([AllowNull()][System.Diagnostics.Process]$Process)

    if ($Process -and !$Process.HasExited) {
        taskkill.exe /PID $Process.Id /T /F | Out-Null
        for ($attempt = 0; $attempt -lt 20; $attempt++) {
            if (!(Get-Process -Id $Process.Id -ErrorAction SilentlyContinue)) {
                break
            }
            Start-Sleep -Milliseconds 250
        }
    }
    Start-Sleep -Milliseconds 500
}

function Assert-SmokeLog {
    param([string]$LogPath, [string]$ErrPath)

    $combined = ""
    if (Test-Path -LiteralPath $LogPath) {
        $combined += Read-TextFile $LogPath
    }
    if (Test-Path -LiteralPath $ErrPath) {
        $combined += "`n"
        $combined += Read-TextFile $ErrPath
    }

    $forbidden = @(
        "addons/fennara/runtime/game_capture_helper.gd",
        "addons/godot_ai/runtime/game_helper.gd",
        "uid://cnxneyd8ilml2",
        "SteamAPI_Init",
        "steamclient.so"
    )
    foreach ($needle in $forbidden) {
        if ($combined.Contains($needle)) {
            throw "Smoke log still contains server-excluded startup noise: $needle"
        }
    }

    if (!$combined.Contains("[Perf] role=public_lobby")) {
        throw "Smoke log did not show public lobby performance telemetry."
    }
}

function Invoke-SmokeTest {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $smokeLog) | Out-Null
    Remove-Item -LiteralPath $smokeLog, $smokeErr -Force -ErrorAction SilentlyContinue

    $previousPublicServer = $env:MAOMAO_PUBLIC_SERVER
    $previousPublicPort = $env:MAOMAO_PUBLIC_PORT
    $previousPublicAddress = $env:MAOMAO_PUBLIC_ADDRESS
    $previousPerfLog = $env:MAOMAO_PERF_LOG
    $previousDebugLog = $env:MAOMAO_DEBUG_LOG

    $env:MAOMAO_PUBLIC_SERVER = "1"
    $env:MAOMAO_PUBLIC_PORT = [string]$SmokePort
    $env:MAOMAO_PUBLIC_ADDRESS = "127.0.0.1"
    $env:MAOMAO_PERF_LOG = "1"
    $env:MAOMAO_DEBUG_LOG = "0"

    $process = $null
    try {
        $args = @(
            "--headless",
            "--main-pack",
            $outputAbs,
            "--",
            "--maomao-public-server",
            "--public-address",
            "127.0.0.1"
        )
        Write-Host ("Smoke test port: " + $SmokePort) -ForegroundColor Cyan
        $process = Start-Process -FilePath $GodotExe -ArgumentList $args -WorkingDirectory $repo -PassThru -WindowStyle Hidden -RedirectStandardOutput $smokeLog -RedirectStandardError $smokeErr
        Start-Sleep -Seconds $SmokeSeconds
        if ($process.HasExited) {
            throw "Smoke server exited early with code $($process.ExitCode). See $smokeLog and $smokeErr."
        }
        Stop-SmokeProcess -Process $process
        Assert-SmokeLog -LogPath $smokeLog -ErrPath $smokeErr
        Write-Host "Smoke test passed." -ForegroundColor Green
    } finally {
        Stop-SmokeProcess -Process $process
        $env:MAOMAO_PUBLIC_SERVER = $previousPublicServer
        $env:MAOMAO_PUBLIC_PORT = $previousPublicPort
        $env:MAOMAO_PUBLIC_ADDRESS = $previousPublicAddress
        $env:MAOMAO_PERF_LOG = $previousPerfLog
        $env:MAOMAO_DEBUG_LOG = $previousDebugLog
    }
}

if (!(Test-Path -LiteralPath $projectFile)) {
    throw "project.godot not found: $projectFile"
}

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

Copy-Item -LiteralPath $projectFile -Destination $backupFile -Force
if (!$SmokeOnly) {
    try {
        $originalProject = Read-TextFile $projectFile
        $serverProject = Remove-ServerExcludedAutoloads -Content $originalProject
        Write-TextFile -Path $projectFile -Content $serverProject

        Invoke-External $GodotExe @(
            "--headless",
            "--path",
            $repo,
            "--export-pack",
            $Preset,
            $outputAbs
        )
    } finally {
        Copy-Item -LiteralPath $backupFile -Destination $projectFile -Force
        Remove-Item -LiteralPath $backupFile -Force -ErrorAction SilentlyContinue
    }
} else {
    Remove-Item -LiteralPath $backupFile -Force -ErrorAction SilentlyContinue
    Write-Host "SmokeOnly set; reusing existing server pack." -ForegroundColor Cyan
}

if (!(Test-Path -LiteralPath $outputAbs)) {
    throw "Export did not create pack: $outputAbs"
}

Get-Item -LiteralPath $outputAbs | Select-Object FullName, Length, LastWriteTime | Format-List
Get-FileHash -Algorithm SHA256 -LiteralPath $outputAbs | Format-List

if (!$SkipSmokeTest) {
    Invoke-SmokeTest
}

Write-Host "Public server pack export finished." -ForegroundColor Green
