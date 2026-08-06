$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SeedFolder = Join-Path $ProjectRoot "firestore_seed"

if (-not (Test-Path (Join-Path $SeedFolder "serviceAccountKey.json"))) {
    throw "Missing firestore_seed\serviceAccountKey.json"
}

Write-Host ""
Write-Host "Repairing voucher costs and cultural-task categories..." -ForegroundColor Cyan

Push-Location $SeedFolder
try {
    npm install
    npm run repair-vouchers-tasks
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "Repair completed." -ForegroundColor Green
Write-Host "Now run:"
Write-Host "flutter clean"
Write-Host "flutter pub get"
Write-Host "flutter analyze"
Write-Host "flutter run"
