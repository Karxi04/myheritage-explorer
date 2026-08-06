$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$TravelerPages = Join-Path $ProjectRoot "lib\traveler\traveler_pages.dart"
$OldModel = Join-Path $ProjectRoot "lib\traveler\daily_planner\review_flag_model.dart"
$NewModel = Join-Path $ProjectRoot "lib\traveler\daily_planner\review_ml_model.dart"

if (-not (Test-Path $TravelerPages)) {
    throw "Missing file: $TravelerPages"
}

if (-not (Test-Path $NewModel)) {
    throw "Missing current NLP model: $NewModel"
}

$BackupTravelerPages = "$TravelerPages.before_review_model_cleanup.bak"
if (-not (Test-Path $BackupTravelerPages)) {
    Copy-Item $TravelerPages $BackupTravelerPages
}

$TravelerText = Get-Content $TravelerPages -Raw

# The current system uses review_ml_model.dart.
# Remove the obsolete old part declaration if it still exists.
$TravelerText = $TravelerText.Replace(
    "part 'daily_planner/review_flag_model.dart';`r`n",
    ""
)
$TravelerText = $TravelerText.Replace(
    "part 'daily_planner/review_flag_model.dart';`n",
    ""
)

# Ensure the current model is included.
if ($TravelerText -notmatch [regex]::Escape(
    "part 'daily_planner/review_ml_model.dart';"
)) {
    $PartMarker = "part 'daily_planner/daily_planner_page.dart';"

    if ($TravelerText.Contains($PartMarker)) {
        $TravelerText = $TravelerText.Replace(
            $PartMarker,
            "$PartMarker`r`npart 'daily_planner/review_ml_model.dart';"
        )
    } else {
        throw "Could not find the Daily Planner part declaration."
    }
}

# review_ml_model.dart uses log(), sqrt() and exp().
# These functions come from dart:math through the parent library.
if ($TravelerText -notmatch "import\s+'dart:math';") {
    $TravelerText = "import 'dart:math';`r`n" + $TravelerText
}

# Remove the alias form to avoid duplicate math imports.
$TravelerText = $TravelerText.Replace(
    "import 'dart:math' as math;`r`n",
    ""
)
$TravelerText = $TravelerText.Replace(
    "import 'dart:math' as math;`n",
    ""
)

Set-Content -Path $TravelerPages -Value $TravelerText -Encoding UTF8

# The old review_flag_model.dart is no longer part of the current system.
# Move it out of the Dart source tree so Flutter Analyzer stops analyzing it.
if (Test-Path $OldModel) {
    $BackupFolder = Join-Path $ProjectRoot "obsolete_code_backup"
    New-Item -ItemType Directory -Path $BackupFolder -Force |
        Out-Null

    $Destination = Join-Path $BackupFolder "review_flag_model.dart.txt"

    if (Test-Path $Destination) {
        Remove-Item $Destination -Force
    }

    Move-Item $OldModel $Destination -Force
}

Write-Host ""
Write-Host "Review model cleanup completed." -ForegroundColor Green
Write-Host ""
Write-Host "Current model:"
Write-Host "  lib\traveler\daily_planner\review_ml_model.dart"
Write-Host ""
Write-Host "Obsolete model moved to:"
Write-Host "  obsolete_code_backup\review_flag_model.dart.txt"
Write-Host ""
Write-Host "Now run:"
Write-Host "  flutter clean"
Write-Host "  flutter pub get"
Write-Host "  flutter analyze"
Write-Host "  flutter run"
