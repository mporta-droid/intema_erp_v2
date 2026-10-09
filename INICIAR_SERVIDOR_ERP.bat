@echo off
setlocal
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -NoProfile -File ".\scripts\start_api_windows.ps1"
pause
