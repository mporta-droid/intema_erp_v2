param(
  [string]$ApiBaseUrl = "http://SERVIDOR:8000/api/v1"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$frontendPath = Join-Path $projectRoot "frontend"
$releasePath = Join-Path $frontendPath "build\windows\x64\runner\Release"
$distRoot = Join-Path $projectRoot "outputs\INTEMA_ERP_WINDOWS"

Write-Host "Compilando app Windows con API: $ApiBaseUrl"
Set-Location $frontendPath
flutter pub get
flutter build windows --release --dart-define=API_BASE_URL=$ApiBaseUrl

if (Test-Path $distRoot) {
  Remove-Item -LiteralPath $distRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $distRoot | Out-Null
Copy-Item -Path (Join-Path $releasePath "*") -Destination $distRoot -Recurse -Force

Write-Host ""
Write-Host "Listo. Copia esta carpeta a las PCs:"
Write-Host $distRoot
