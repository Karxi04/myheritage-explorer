param(
    [string]$ProjectId = "myheritage-4fe2f"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "MyHeritage Daily Planner Google Places setup" -ForegroundColor Cyan
Write-Host "Project: $ProjectId"
Write-Host ""

if (-not (Test-Path ".\firebase.json")) {
    Write-Host "firebase.json was not found in this folder." -ForegroundColor Red
    Write-Host "Run this script from the Flutter project root."
    exit 1
}

$firebaseJson = Get-Content ".\firebase.json" -Raw | ConvertFrom-Json

if ($null -eq $firebaseJson.functions) {
    $firebaseJson | Add-Member -NotePropertyName "functions" -NotePropertyValue @{
        source = "functions"
    }
} elseif ($firebaseJson.functions -is [System.Array]) {
    Write-Host "Existing multiple Firebase function codebases detected." -ForegroundColor Yellow
    Write-Host "The functions folder was not changed automatically."
} else {
    $firebaseJson.functions.source = "functions"
}

$firebaseJson |
    ConvertTo-Json -Depth 20 |
    Set-Content ".\firebase.json" -Encoding UTF8

firebase use $ProjectId

Write-Host ""
Write-Host "Installing Firebase Function packages..." -ForegroundColor Cyan
npm install --prefix functions

Write-Host ""
Write-Host "Paste the Google Places API key when Firebase asks for it." -ForegroundColor Yellow
firebase functions:secrets:set GOOGLE_PLACES_API_KEY

Write-Host ""
Write-Host "Deploying generateDailyItinerary..." -ForegroundColor Cyan
firebase deploy --only functions:generateDailyItinerary

Write-Host ""
Write-Host "Backend deployment completed." -ForegroundColor Green
Write-Host "Now run:"
Write-Host "flutter clean"
Write-Host "flutter pub get"
Write-Host "flutter run"
