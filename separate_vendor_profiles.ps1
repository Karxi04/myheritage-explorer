$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SeedFolder = Join-Path $ProjectRoot "firestore_seed"

if (-not (Test-Path (Join-Path $SeedFolder "serviceAccountKey.json"))) {
    throw "Missing firestore_seed\serviceAccountKey.json"
}

Push-Location $SeedFolder
try {
    npm install
    npm run separate-roles
}
finally {
    Pop-Location
}
