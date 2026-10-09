@echo off
setlocal
set APP_PATH=%~dp0outputs\INTEMA_ERP_WINDOWS\intema_erp_frontend.exe

if not exist "%APP_PATH%" (
  echo Todavia no existe la app final.
  echo Primero ejecuta COMPILAR_APP_WINDOWS_LOCAL.bat y deja que termine.
  pause
  exit /b 1
)

start "" "%APP_PATH%"
