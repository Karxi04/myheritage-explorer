$ErrorActionPreference = "Stop"

$ProjectRoot =
    Split-Path -Parent $MyInvocation.MyCommand.Path
$SeedFolder =
    Join-Path $ProjectRoot "firestore_seed"

if (-not (
    Test-Path (
      Join-Path $SeedFolder "serviceAccountKey.json"
    )
)) {
    throw "Missing firestore_seed\serviceAccountKey.json"
}

Write-Host ""
Write-Host "Repair vendor names, itinerary symbols and Admin profile" `
    -ForegroundColor Cyan
Write-Host ""

$AdminEmail = Read-Host `
    "Enter the Admin website login email"

if ([string]::IsNullOrWhiteSpace($AdminEmail)) {
    throw "The Admin email is required."
}

$env:MYHERITAGE_ADMIN_EMAIL =
    $AdminEmail.Trim().ToLower()

Push-Location $SeedFolder
try {
    npm install
    npm run repair-vendor-symbol-admin
}
finally {
    Pop-Location
}
