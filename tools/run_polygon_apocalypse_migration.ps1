param(
    [string]$UnitySource = "H:\3D Resource\effect\Party Monster Rumble PBR v1.0\New Unity Project\Assets\PolygonApocalypse",
    [string]$UnityExe = "C:\Program Files\Unity\Hub\Editor\6000.6.0a7\Editor\Unity.exe",
    [string]$GodotExe = "godot",
    [switch]$SkipUnityAudit,
    [switch]$SkipConversion,
    [switch]$SkipGodotImport,
    [switch]$SkipCapture,
    [switch]$HeadlessCapture,
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"

$repo = (Resolve-Path -LiteralPath ".").Path
$compareRoot = Join-Path $repo ".codex_compare\polygon_apocalypse"
$unityAuditPath = Join-Path $compareRoot "unity\unity_audit.json"
$boundsRoot = Join-Path $compareRoot "godot_bounds"
$capturesRoot = Join-Path $compareRoot "final_captures"
$captureDirections = "pp,np,pn,nn"

$mapScenes = [ordered]@{
    building_interior_dressing = "res://scenes/level/maps/polygon_apocalypse_building_interior_dressing.tscn"
    bunker = "res://scenes/level/maps/polygon_apocalypse_bunker.tscn"
    city_standard = "res://scenes/level/maps/polygon_apocalypse_city_standard.tscn"
    city_urp = "res://scenes/level/maps/polygon_apocalypse_city_urp.tscn"
}

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Action
    )

    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan
    & $Action
}

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

if (!(Test-Path -LiteralPath $UnitySource)) {
    throw "Unity Polygon Apocalypse source folder is missing: $UnitySource"
}

New-Item -ItemType Directory -Force -Path $compareRoot, $boundsRoot, $capturesRoot | Out-Null

$previousSource = $env:POLYGON_APOCALYPSE_SOURCE
$env:POLYGON_APOCALYPSE_SOURCE = $UnitySource
try {
    Invoke-Step "Check migration scripts" {
        Invoke-External "node" @("--check", "tools\build_polygon_apocalypse_layouts.js")
        Invoke-External "node" @("--check", "tools\convert_polygon_apocalypse_models.js")
        Invoke-External "node" @("--check", "tools\compare_polygon_apocalypse_migration.js")
    }

    if (!$SkipUnityAudit) {
        if (!(Test-Path -LiteralPath $UnityExe)) {
            throw "Unity executable is missing: $UnityExe"
        }
        $unityProjectRoot = Split-Path -Parent (Split-Path -Parent $UnitySource)
        Invoke-Step "Export Unity audit screenshots and renderer bounds" {
            Invoke-External $UnityExe @(
                "-batchmode",
                "-projectPath",
                $unityProjectRoot,
                "-executeMethod",
                "PolygonApocalypseAuditExporter.Export",
                "-logFile",
                (Join-Path $compareRoot "unity_batch_export.log")
            )
        }
    }

    Invoke-Step "Build Unity scene layouts and material map" {
        Invoke-External "node" @("tools\build_polygon_apocalypse_layouts.js")
    }

    if (!$SkipConversion) {
        Invoke-Step "Convert referenced FBX models to GLB" {
            Invoke-External "node" @("tools\convert_polygon_apocalypse_models.js")
        }
    }

    if (!$SkipGodotImport) {
        Invoke-Step "Refresh Godot imports" {
            Invoke-External $GodotExe @("--headless", "--path", ".", "--import")
        }
    }

    Invoke-Step "Export generated Godot renderer bounds" {
        foreach ($mapId in $mapScenes.Keys) {
            $outPath = Join-Path $boundsRoot "$mapId.json"
            Invoke-External $GodotExe @(
                "--headless",
                "--path",
                ".",
                "--script",
                "tools/export_polygon_apocalypse_godot_bounds.gd",
                "--",
                "--scene=$($mapScenes[$mapId])",
                "--out=$outPath"
            )
        }
    }

    if (!$SkipCapture) {
        if (!(Test-Path -LiteralPath $unityAuditPath)) {
            throw "Unity audit evidence is missing: $unityAuditPath. Generate Unity audit screenshots before running visual capture."
        }
        Invoke-Step "Capture Godot audit screenshots" {
            foreach ($mapId in $mapScenes.Keys) {
                $captureArgs = @(
                    "--path",
                    ".",
                    "--script",
                    "tools/capture_polygon_apocalypse_views.gd",
                    "--",
                    "--scene=$($mapScenes[$mapId])",
                    "--out=$capturesRoot",
                    "--directions=$captureDirections",
                    "--prefix=$mapId",
                    "--map-id=$mapId",
                    "--unity-audit=$unityAuditPath",
                    "--flip-x-output"
                )
                if ($HeadlessCapture) {
                    $captureArgs = @("--headless") + $captureArgs
                }
                Invoke-External $GodotExe $captureArgs
            }
        }
    }

    Invoke-Step "Measure visual parity and rebuild comparison image" {
        Invoke-External "powershell" @(
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            "tools\measure_polygon_apocalypse_visuals.ps1",
            "-CompareRoot",
            $compareRoot,
            "-DirectionLabels",
            $captureDirections
        )
    }

    Invoke-Step "Write migration audit report" {
        Invoke-External "node" @("tools\compare_polygon_apocalypse_migration.js")
    }

    if (!$SkipTests) {
        Invoke-Step "Run Godot migration test scene" {
            Invoke-External $GodotExe @("--headless", "--path", ".", "--scene", "res://tests/polygon_apocalypse_maps_test.tscn")
        }
    }

    Write-Host ""
    Write-Host "Polygon Apocalypse migration flow finished." -ForegroundColor Green
    Write-Host "Report: $compareRoot\static_audit.md"
    Write-Host "Visual compare: $compareRoot\visual_compare_unity_godot_final.png"
    Write-Host "Visual metrics: $compareRoot\visual_iou_latest.json"
} finally {
    $env:POLYGON_APOCALYPSE_SOURCE = $previousSource
}
