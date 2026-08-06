$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "MyHeritage Penang reviews and itinerary images setup" -ForegroundColor Cyan
Write-Host ""

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$seedFolder = Join-Path $projectRoot "firestore_seed"
$serviceAccount = Join-Path $seedFolder "serviceAccountKey.json"

if (-not (Test-Path $serviceAccount)) {
    Write-Host "Missing: firestore_seed\serviceAccountKey.json" -ForegroundColor Red
    Write-Host "Copy your existing Firebase service-account JSON into that folder and run this script again."
    exit 1
}

Push-Location $seedFolder
try {
    Write-Host "Installing seed packages..."
    npm install

    Write-Host ""
    Write-Host "Creating more Penang reviews and storing place photos..."
    npm run seed-more-reviews

    Write-Host ""
    Write-Host "Repairing old saved and shared itinerary images..."
    npm run repair-itinerary-images
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "Firestore review and image setup completed." -ForegroundColor Green
Write-Host "Now run:"
Write-Host "flutter clean"
Write-Host "flutter pub get"
Write-Host "flutter analyze"
Write-Host "flutter run"
