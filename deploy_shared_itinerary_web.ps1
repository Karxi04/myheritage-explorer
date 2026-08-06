$ErrorActionPreference = "Stop"

Write-Host "MyHeritage shared itinerary web deployment" -ForegroundColor Cyan
Write-Host "Firebase project: myheritage-4fe2f"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

$firebaseJsonPath = Join-Path $projectRoot "firebase.json"
if (Test-Path $firebaseJsonPath) {
  $config = Get-Content $firebaseJsonPath -Raw | ConvertFrom-Json
} else {
  $config = [PSCustomObject]@{}
}

$hosting = [PSCustomObject]@{
  public = "build/web"
  ignore = @(
    "firebase.json",
    "**/.*",
    "**/node_modules/**"
  )
  rewrites = @(
    [PSCustomObject]@{
      source = "**"
      destination = "/index.html"
    }
  )
}

if ($config.PSObject.Properties.Name -contains "hosting") {
  $config.hosting = $hosting
} else {
  $config | Add-Member -MemberType NoteProperty -Name "hosting" -Value $hosting
}

$config | ConvertTo-Json -Depth 20 | Set-Content $firebaseJsonPath -Encoding UTF8

Write-Host "Building Flutter Web..." -ForegroundColor Yellow
flutter build web

Write-Host "Selecting Firebase project..." -ForegroundColor Yellow
firebase use myheritage-4fe2f

Write-Host "Deploying Firebase Hosting..." -ForegroundColor Yellow
firebase deploy --only hosting

Write-Host "" 
Write-Host "Deployment completed." -ForegroundColor Green
Write-Host "Public link base: https://myheritage-4fe2f.web.app/"
Write-Host "The mobile app can now share itinerary links that open in a browser."
