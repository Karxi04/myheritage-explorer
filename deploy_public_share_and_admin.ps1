$ErrorActionPreference = "Stop"

Write-Host "MyHeritage public itinerary + admin web deployment" -ForegroundColor Cyan
Write-Host "Firebase project: myheritage-4fe2f"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

Write-Host "Building Flutter Web admin portal..." -ForegroundColor Yellow
flutter build web

$shareSource = Join-Path $projectRoot "web_share\index.html"
$shareTargetDirectory = Join-Path $projectRoot "build\web\share"
$shareTarget = Join-Path $shareTargetDirectory "index.html"
New-Item -ItemType Directory -Force -Path $shareTargetDirectory | Out-Null
Copy-Item $shareSource $shareTarget -Force

$firebaseJsonPath = Join-Path $projectRoot "firebase.json"
if (Test-Path $firebaseJsonPath) {
  $config = Get-Content $firebaseJsonPath -Raw | ConvertFrom-Json
} else {
  $config = [PSCustomObject]@{}
}

$hosting = [PSCustomObject]@{
  public = "build/web"
  ignore = @("firebase.json", "**/.*", "**/node_modules/**")
  rewrites = @(
    [PSCustomObject]@{ source = "/share/**"; destination = "/share/index.html" },
    [PSCustomObject]@{ source = "**"; destination = "/index.html" }
  )
}

if ($config.PSObject.Properties.Name -contains "hosting") {
  $config.hosting = $hosting
} else {
  $config | Add-Member -MemberType NoteProperty -Name "hosting" -Value $hosting
}
$config | ConvertTo-Json -Depth 20 | Set-Content $firebaseJsonPath -Encoding UTF8

firebase use myheritage-4fe2f
firebase deploy --only hosting

Write-Host "" 
Write-Host "Deployment completed." -ForegroundColor Green
Write-Host "Admin portal: https://myheritage-4fe2f.web.app/"
Write-Host "Public itinerary links: https://myheritage-4fe2f.web.app/share/?id=XXXXXXXXX"
