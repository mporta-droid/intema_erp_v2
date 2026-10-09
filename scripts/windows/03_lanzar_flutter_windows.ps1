$ErrorActionPreference = "Stop"

param(
    [string]$ApiBaseUrl = "http://localhost:8000/api/v1"
)

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Frontend = Join-Path $ProjectRoot "frontend"
Set-Location $Frontend
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=$ApiBaseUrl