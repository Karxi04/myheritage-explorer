$ErrorActionPreference = "Stop"

$ProjectRoot =
    Split-Path -Parent $MyInvocation.MyCommand.Path

Set-Location $ProjectRoot

Write-Host ""
Write-Host "Preparing Firebase Hosting configuration..." `
    -ForegroundColor Cyan

$FirebaseJson =
    Join-Path $ProjectRoot "firebase.json"

if (-not (Test-Path $FirebaseJson)) {
@'
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
'@ | Set-Content $FirebaseJson -Encoding UTF8
}
else {
    $Configuration =
        Get-Content $FirebaseJson -Raw |
        ConvertFrom-Json

    if ($null -eq $Configuration.hosting) {
        $Configuration |
            Add-Member `
                -MemberType NoteProperty `
                -Name hosting `
                -Value ([pscustomobject]@{})
    }

    $Configuration.hosting.public = "build/web"
    $Configuration.hosting.ignore = @(
        "firebase.json",
        "**/.*",
        "**/node_modules/**"
    )
    $Configuration.hosting.rewrites = @(
        [pscustomobject]@{
            source = "**"
            destination = "/index.html"
        }
    )

    $Configuration |
        ConvertTo-Json -Depth 20 |
        Set-Content $FirebaseJson -Encoding UTF8
}

Write-Host "Building current Flutter Web application..."

flutter clean
flutter pub get
flutter build web --release

$WebShare =
    Join-Path $ProjectRoot "web_share"
$BuildShare =
    Join-Path $ProjectRoot "build\web\share"

if (Test-Path $WebShare) {
    New-Item `
        -ItemType Directory `
        -Path $BuildShare `
        -Force |
        Out-Null

    Copy-Item `
        (Join-Path $WebShare "*") `
        $BuildShare `
        -Recurse `
        -Force
}

firebase use myheritage-4fe2f
firebase deploy --only hosting

Write-Host ""
Write-Host "Deployment completed." -ForegroundColor Green
Write-Host "Open an Incognito window:"
Write-Host "https://myheritage-4fe2f.web.app/"
