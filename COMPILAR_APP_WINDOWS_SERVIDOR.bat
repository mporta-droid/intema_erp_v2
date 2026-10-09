@echo off
setlocal
set /p SERVER_HOST=Escribe la IP o nombre del servidor ERP [SERVIDOR]: 
if "%SERVER_HOST%"=="" set "SERVER_HOST=SERVIDOR"
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -NoProfile -File ".\scripts\build_app_windows.ps1" -ApiBaseUrl "http://%SERVER_HOST%:8000/api/v1"
pause
