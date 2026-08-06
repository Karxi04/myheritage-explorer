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
Write-Host "MyHeritage three-role migration" -ForegroundColor Cyan
Write-Host ""
Write-Host "Final collections:"
Write-Host "  admins"
Write-Host "  travelers"
Write-Host "  vendors"
Write-Host ""
Write-Host "A JSON backup will be created."

$Confirmation = Read-Host "Type SEPARATE to continue"
if ($Confirmation -ne "SEPARATE") {
    Write-Host "Migration cancelled."
    exit 0
}

Push-Location $SeedFolder
try {
    npm install
    npm run migrate-three-roles
}
finally {
    Pop-Location
}
