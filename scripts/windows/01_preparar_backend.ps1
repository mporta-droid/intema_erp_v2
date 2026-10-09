$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Backend = Join-Path $ProjectRoot "backend"
$EnvFile = Join-Path $ProjectRoot ".env"
$EnvExample = Join-Path $ProjectRoot ".env.example"

if (-not (Test-Path $EnvFile)) {
    Copy-Item $EnvExample $EnvFile
    Write-Host "Se creó .env desde .env.example. Revisa contraseñas antes de producción." -ForegroundColor Yellow
}

Set-Location $Backend
python -m pip install -r requirements-dev.txt
alembic upgrade head
python -m app.db.init_db
Write-Host "Backend preparado: migraciones aplicadas y seed ejecutado." -ForegroundColor Green