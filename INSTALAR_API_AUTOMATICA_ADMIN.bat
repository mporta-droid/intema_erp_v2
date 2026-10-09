@echo off
setlocal
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -NoProfile -File ".\scripts\install_api_startup_task.ps1"
pause
