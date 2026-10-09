# Frontend Flutter INTEMA ERP/MES v2

App Flutter de la Fase 1 para Windows y Android. Incluye login, sesión JWT, menú lateral por permisos y gestión de usuarios/roles/permisos.

## Preparación

El código de aplicación está en `lib/` y el logo está en `assets/images/intema_logo.png`.

Si los runners de plataforma no existen, generarlos desde esta carpeta:

```powershell
flutter create --platforms=windows,android .
flutter pub get
```

## Ejecutar

Windows local:

```powershell
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

Android en red LAN:

```powershell
flutter run -d android --dart-define=API_BASE_URL=http://IP_DEL_SERVIDOR:8000/api/v1
```

Android emulator apuntando a API en la misma PC:

```powershell
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```
