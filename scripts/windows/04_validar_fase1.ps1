$ErrorActionPreference = "Stop"

param(
    [string]$TestDatabaseUrl = $env:TEST_DATABASE_URL
)

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Backend = Join-Path $ProjectRoot "backend"
$Frontend = Join-Path $ProjectRoot "frontend"

Set-Location $Backend
python -m pytest app/tests/test_security.py app/tests/test_permission_resolution.py -q

if ($TestDatabaseUrl) {
    $env:TEST_DATABASE_URL = $TestDatabaseUrl
    python -m pytest app/tests/test_postgres_api_flow.py -q
} else {
    Write-Host "TEST_DATABASE_URL no definido: se omite integración PostgreSQL." -ForegroundColor Yellow
}

Set-Location $Frontend
flutter analyze
flutter test
Write-Host "Validación Fase 1 terminada." -ForegroundColor Green