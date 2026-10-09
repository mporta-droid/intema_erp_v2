$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$backendPath = Join-Path $projectRoot "backend"
$pythonPath = Join-Path $projectRoot ".venv\Scripts\python.exe"

Set-Location $backendPath
& $pythonPath -m uvicorn app.main:app --host 0.0.0.0 --port 8000
