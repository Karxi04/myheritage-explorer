$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ProjectRoot

Write-Host ""
Write-Host "Building MyHeritage Admin Web..." -ForegroundColor Cyan

flutter clean
flutter pub get
flutter build web --release

$WebShare = Join-Path $ProjectRoot "web_share"
$BuildShare = Join-Path $ProjectRoot "build\web\share"

if (Test-Path $WebShare) {
    New-Item -ItemType Directory -Path $BuildShare -Force | Out-Null
    Copy-Item (Join-Path $WebShare "*") $BuildShare -Recurse -Force
    Write-Host "Public share page copied to build\web\share"
}

firebase use myheritage-4fe2f
firebase deploy --only hosting

Write-Host ""
Write-Host "Admin web deployed:" -ForegroundColor Green
Write-Host "https://myheritage-4fe2f.web.app/"
