$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Backend = Join-Path $ProjectRoot "backend"
Set-Location $Backend
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload