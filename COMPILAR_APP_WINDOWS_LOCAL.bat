@echo off
setlocal
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -NoProfile -File ".\scripts\build_app_windows.ps1" -ApiBaseUrl "http://localhost:8000/api/v1"
pause
