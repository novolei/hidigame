param(
    [string]$CompareRoot = ".codex_compare\polygon_apocalypse",
    [string]$VisualComparePath = ".codex_compare\polygon_apocalypse\visual_compare_unity_godot_final.png",
    [string[]]$Maps = @(
        "building_interior_dressing",
        "bunker",
        "city_standard",
        "city_urp"
    ),
    [string[]]$DirectionLabels = @("pp"),
    [int]$Threshold = 15
)

Add-Type -AssemblyName System.Drawing

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public sealed class PolygonApocalypseVisualMetricsResult
{
    public double MaskIou { get; set; }
    public double ColorDelta { get; set; }
    public int UnityForegroundPixels { get; set; }
    public int GodotForegroundPixels { get; set; }
}

public static class PolygonApocalypseVisualMetrics
{
    public static PolygonApocalypseVisualMetricsResult Measure(string unityPath, string godotPath, string diffPath, int threshold)
    {
        using (var unitySource = new Bitmap(unityPath))
        using (var godotSource = new Bitmap(godotPath))
        using (var unity = unitySource.Clone(new Rectangle(0, 0, unitySource.Width, unitySource.Height), PixelFormat.Format32bppArgb))
        using (var godot = godotSource.Clone(new Rectangle(0, 0, godotSource.Width, godotSource.Height), PixelFormat.Format32bppArgb))
        using (var diff = new Bitmap(Math.Min(unity.Width, godot.Width), Math.Min(unity.Height, godot.Height), PixelFormat.Format32bppArgb))
        {
            int width = diff.Width;
            int height = diff.Height;
            Rectangle rect = new Rectangle(0, 0, width, height);
            BitmapData unityData = unity.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            BitmapData godotData = godot.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            BitmapData diffData = diff.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);

            try
            {
                int unityStride = unityData.Stride;
                int godotStride = godotData.Stride;
                int diffStride = diffData.Stride;
                byte[] unityBytes = new byte[Math.Abs(unityStride) * height];
                byte[] godotBytes = new byte[Math.Abs(godotStride) * height];
                byte[] diffBytes = new byte[Math.Abs(diffStride) * height];
                Marshal.Copy(unityData.Scan0, unityBytes, 0, unityBytes.Length);
                Marshal.Copy(godotData.Scan0, godotBytes, 0, godotBytes.Length);

                byte unityBgB = unityBytes[0];
                byte unityBgG = unityBytes[1];
                byte unityBgR = unityBytes[2];
                byte godotBgB = godotBytes[0];
                byte godotBgG = godotBytes[1];
                byte godotBgR = godotBytes[2];
                int thresholdSquared = threshold * threshold;

                int unityForeground = 0;
                int godotForeground = 0;
                int intersection = 0;
                int union = 0;
                double colorDeltaSum = 0.0;

                for (int y = 0; y < height; y++)
                {
                    int unityRow = y * Math.Abs(unityStride);
                    int godotRow = y * Math.Abs(godotStride);
                    int diffRow = y * Math.Abs(diffStride);
                    for (int x = 0; x < width; x++)
                    {
                        int unityIndex = unityRow + x * 4;
                        int godotIndex = godotRow + x * 4;
                        int diffIndex = diffRow + x * 4;

                        int unityDb = unityBytes[unityIndex] - unityBgB;
                        int unityDg = unityBytes[unityIndex + 1] - unityBgG;
                        int unityDr = unityBytes[unityIndex + 2] - unityBgR;
                        int godotDb = godotBytes[godotIndex] - godotBgB;
                        int godotDg = godotBytes[godotIndex + 1] - godotBgG;
                        int godotDr = godotBytes[godotIndex + 2] - godotBgR;
                        bool unityMask = (unityDb * unityDb + unityDg * unityDg + unityDr * unityDr) > thresholdSquared;
                        bool godotMask = (godotDb * godotDb + godotDg * godotDg + godotDr * godotDr) > thresholdSquared;

                        if (unityMask) unityForeground++;
                        if (godotMask) godotForeground++;
                        if (unityMask || godotMask) union++;

                        byte r;
                        byte g;
                        byte b;
                        if (unityMask && godotMask)
                        {
                            intersection++;
                            double averageDelta = (
                                Math.Abs(unityBytes[unityIndex + 2] - godotBytes[godotIndex + 2]) +
                                Math.Abs(unityBytes[unityIndex + 1] - godotBytes[godotIndex + 1]) +
                                Math.Abs(unityBytes[unityIndex] - godotBytes[godotIndex])
                            ) / 3.0;
                            colorDeltaSum += averageDelta;
                            byte heat = ClampByte(averageDelta * 4.0);
                            r = heat;
                            g = ClampByte(heat * 0.7);
                            b = 0;
                        }
                        else if (unityMask)
                        {
                            r = 64;
                            g = 128;
                            b = 255;
                        }
                        else if (godotMask)
                        {
                            r = 255;
                            g = 96;
                            b = 64;
                        }
                        else
                        {
                            r = 48;
                            g = 48;
                            b = 48;
                        }

                        diffBytes[diffIndex] = b;
                        diffBytes[diffIndex + 1] = g;
                        diffBytes[diffIndex + 2] = r;
                        diffBytes[diffIndex + 3] = 255;
                    }
                }

                Marshal.Copy(diffBytes, 0, diffData.Scan0, diffBytes.Length);
                diff.UnlockBits(diffData);
                diffData = null;
                diff.Save(diffPath, ImageFormat.Png);

                return new PolygonApocalypseVisualMetricsResult
                {
                    MaskIou = union == 0 ? 1.0 : Math.Round(intersection / (double)union, 4),
                    ColorDelta = Math.Round(colorDeltaSum / Math.Max(1, intersection), 2),
                    UnityForegroundPixels = unityForeground,
                    GodotForegroundPixels = godotForeground
                };
            }
            finally
            {
                unity.UnlockBits(unityData);
                godot.UnlockBits(godotData);
                if (diffData != null)
                {
                    diff.UnlockBits(diffData);
                }
            }
        }
    }

    private static byte ClampByte(double value)
    {
        return (byte)Math.Max(0, Math.Min(255, (int)Math.Round(value)));
    }
}
'@

function New-VisualCompareImage {
    param(
        [string]$Root,
        [string]$OutputPath,
        [string[]]$MapIds
    )

    $cellWidth = 426
    $cellHeight = 240
    $labelHeight = 30
    $columns = @("Unity", "Godot", "Diff")
    $canvasWidth = $cellWidth * $columns.Count
    $canvasHeight = ($cellHeight + $labelHeight) * ($MapIds.Count + 1)
    $canvas = New-Object System.Drawing.Bitmap($canvasWidth, $canvasHeight)
    $graphics = [System.Drawing.Graphics]::FromImage($canvas)
    $graphics.Clear([System.Drawing.Color]::FromArgb(28, 28, 28))
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Regular)
    $titleFont = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $mutedBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(210, 210, 210))
    $borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70, 70, 70), 1)
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center

    try {
        for ($column = 0; $column -lt $columns.Count; $column++) {
            $rect = New-Object System.Drawing.RectangleF(($column * $cellWidth), 0, $cellWidth, $labelHeight)
            $graphics.DrawString($columns[$column], $titleFont, $brush, $rect, $format)
        }

        for ($row = 0; $row -lt $MapIds.Count; $row++) {
            $map = $MapIds[$row]
            $top = ($row + 1) * ($cellHeight + $labelHeight)
            $rowLabel = $map.Replace("_", " ")
            $labelRect = New-Object System.Drawing.RectangleF(0, ($top - $labelHeight), $canvasWidth, $labelHeight)
            $graphics.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(38, 38, 38))), $labelRect)
            $graphics.DrawString($rowLabel, $titleFont, $mutedBrush, $labelRect, $format)

            $unityPreviewPath = Join-Path $Root "unity\$map.png"
            if (!(Test-Path -LiteralPath $unityPreviewPath)) {
                $unityPreviewPath = Join-Path $Root "unity\${map}_pp.png"
            }
            $paths = @(
                $unityPreviewPath,
                (Join-Path $Root "final_captures\${map}_pp.png"),
                (Join-Path $Root "visual_diffs\${map}_diff.png")
            )
            for ($column = 0; $column -lt $paths.Count; $column++) {
                $dest = New-Object System.Drawing.Rectangle(($column * $cellWidth), $top, $cellWidth, $cellHeight)
                $graphics.DrawRectangle($borderPen, $dest)
                if (Test-Path -LiteralPath $paths[$column]) {
                    $image = [System.Drawing.Image]::FromFile($paths[$column])
                    try {
                        $scale = [Math]::Min($cellWidth / [double]$image.Width, $cellHeight / [double]$image.Height)
                        $drawWidth = [int][Math]::Round($image.Width * $scale)
                        $drawHeight = [int][Math]::Round($image.Height * $scale)
                        $drawRect = New-Object System.Drawing.Rectangle(
                            ($dest.X + [int](($cellWidth - $drawWidth) / 2)),
                            ($dest.Y + [int](($cellHeight - $drawHeight) / 2)),
                            $drawWidth,
                            $drawHeight
                        )
                        $graphics.DrawImage($image, $drawRect)
                    } finally {
                        $image.Dispose()
                    }
                } else {
                    $missingRect = New-Object System.Drawing.RectangleF($dest.X, $dest.Y, $dest.Width, $dest.Height)
                    $graphics.DrawString("missing", $font, $mutedBrush, $missingRect, $format)
                }
            }
        }

        $outputFullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outputFullPath) | Out-Null
        $canvas.Save($outputFullPath, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $format.Dispose()
        $borderPen.Dispose()
        $mutedBrush.Dispose()
        $brush.Dispose()
        $titleFont.Dispose()
        $font.Dispose()
        $graphics.Dispose()
        $canvas.Dispose()
    }
}

$DirectionLabels = @(
    $DirectionLabels |
        ForEach-Object { [string]$_ -split "," } |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_.Length -gt 0 }
)
if ($DirectionLabels.Count -eq 0) {
    throw "At least one visual direction label is required."
}

$results = [ordered]@{}
$diffRoot = Join-Path $CompareRoot "visual_diffs"
New-Item -ItemType Directory -Force -Path $diffRoot | Out-Null

foreach ($map in $Maps) {
    $directionResults = [ordered]@{}
    foreach ($direction in $DirectionLabels) {
        $unityPath = Join-Path $CompareRoot "unity\${map}_${direction}.png"
        if ($direction -eq "pp" -and !(Test-Path -LiteralPath $unityPath)) {
            $unityPath = Join-Path $CompareRoot "unity\$map.png"
        }
        $godotPath = Join-Path $CompareRoot "final_captures\${map}_${direction}.png"
        if (!(Test-Path -LiteralPath $unityPath) -or !(Test-Path -LiteralPath $godotPath)) {
            Write-Warning "Skipping $map direction $direction because a matching Unity/Godot visual input is missing."
            continue
        }

        $diffName = if ($direction -eq "pp") { "${map}_diff.png" } else { "${map}_${direction}_diff.png" }
        $diffPath = Join-Path $diffRoot $diffName
        $measurement = [PolygonApocalypseVisualMetrics]::Measure($unityPath, $godotPath, $diffPath, $Threshold)
        $directionResults[$direction] = [ordered]@{
            mask_iou = $measurement.MaskIou
            color_delta = $measurement.ColorDelta
            unity_foreground_pixels = $measurement.UnityForegroundPixels
            godot_foreground_pixels = $measurement.GodotForegroundPixels
            diff_heatmap = (Resolve-Path -LiteralPath $diffPath).Path.Replace("\", "/")
        }
    }
    if ($directionResults.Count -eq 0) {
        throw "Missing all visual inputs for $map"
    }

    $primaryDirection = if ($directionResults.Contains("pp")) { "pp" } else { [string]@($directionResults.Keys)[0] }
    $primary = $directionResults[$primaryDirection]
    $results[$map] = [ordered]@{
        mask_iou = $primary.mask_iou
        color_delta = $primary.color_delta
        unity_foreground_pixels = $primary.unity_foreground_pixels
        godot_foreground_pixels = $primary.godot_foreground_pixels
        diff_heatmap = $primary.diff_heatmap
        directions = $directionResults
    }
}

$jsonPath = Join-Path $CompareRoot "visual_iou_latest.json"
$results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
New-VisualCompareImage -Root $CompareRoot -OutputPath $VisualComparePath -MapIds $Maps
$results | ConvertTo-Json -Depth 5
