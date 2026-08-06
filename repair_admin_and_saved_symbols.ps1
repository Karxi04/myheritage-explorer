$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SeedFolder = Join-Path $ProjectRoot "firestore_seed"

if (-not (Test-Path (Join-Path $SeedFolder "serviceAccountKey.json"))) {
    throw "Missing firestore_seed\serviceAccountKey.json"
}

Write-Host ""
Write-Host "Repair Admin profile and saved itinerary symbols" -ForegroundColor Cyan
Write-Host ""

$AdminEmail = Read-Host "Admin login email (leave blank to only repair existing role=admin profiles)"
$env:MYHERITAGE_ADMIN_EMAIL = $AdminEmail

Push-Location $SeedFolder
try {
    npm install
    npm run repair-symbols-admin
}
finally {
    Pop-Location
}
