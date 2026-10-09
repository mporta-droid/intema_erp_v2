# INTEMA ERP/MES - Puesta en produccion por USB

Esta guia separa el sistema en dos partes:

- Servidor: Docker, PostgreSQL y API.
- PCs cliente: app Windows de Flutter apuntando al IP del servidor.

## 1. Preparar el servidor

En el servidor debe estar Docker Desktop con `Engine running`.

Verificar en PowerShell:

```powershell
docker --version
docker compose version
docker info
```

Tambien obtener el IP del servidor:

```powershell
ipconfig
```

Buscar `Direccion IPv4`. Ejemplo:

```text
192.168.1.50
```

Ese IP debe ser fijo o reservado en el router para que las PCs siempre encuentren el ERP.

## 2. Copiar el proyecto al servidor

Copiar por USB esta carpeta completa:

```text
intema_erp_v2
```

Por ejemplo dejarla en:

```text
C:\INTEMA_ERP\intema_erp_v2
```

## 3. Ajustar claves de produccion

En el servidor abrir:

```text
C:\INTEMA_ERP\intema_erp_v2\.env
```

Cambiar como minimo:

```env
ENVIRONMENT=production
POSTGRES_PASSWORD=una_clave_fuerte
JWT_SECRET_KEY=una_clave_larga_y_dificil
ADMIN_PASSWORD=una_clave_temporal_para_admin
ACCESS_TOKEN_EXPIRE_MINUTES=480
REFRESH_TOKEN_EXPIRE_MINUTES=720
```

`480` minutos equivale a 8 horas.

## 4. Levantar el ERP en el servidor

Abrir PowerShell en el servidor:

```powershell
cd C:\INTEMA_ERP\intema_erp_v2
docker compose -f docker-compose.prod.yml up --build -d
```

Verificar que este corriendo:

```powershell
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs api
```

Debe aparecer algo parecido a:

```text
Uvicorn running on http://0.0.0.0:8000
```

## 5. Probar desde el servidor

Abrir en el navegador del servidor:

```text
http://localhost:8000/api/v1
```

O:

```text
http://localhost:8000/docs
```

## 6. Probar desde otra PC de la red

Desde otra computadora conectada a la misma red:

```text
http://IP_DEL_SERVIDOR:8000/api/v1
```

Ejemplo:

```text
http://192.168.1.50:8000/api/v1
```

Si no abre, revisar Firewall de Windows del servidor y permitir el puerto `8000`.

## 7. Crear la app Windows para las PCs

En la laptop de desarrollo, compilar la app apuntando al IP del servidor:

```powershell
cd C:\Users\MARTIN\Documents\Codex\2026-08-10\corregir-5\intema_erp_v2\frontend
flutter build windows --release --dart-define=API_BASE_URL=http://IP_DEL_SERVIDOR:8000/api/v1
```

Ejemplo:

```powershell
flutter build windows --release --dart-define=API_BASE_URL=http://192.168.1.50:8000/api/v1
```

Luego copiar por USB esta carpeta a cada PC:

```text
frontend\build\windows\x64\runner\Release
```

La app se abre con:

```text
intema_erp_frontend.exe
```

## 8. Comandos utiles del servidor

Apagar el ERP:

```powershell
cd C:\INTEMA_ERP\intema_erp_v2
docker compose -f docker-compose.prod.yml down
```

Encenderlo otra vez:

```powershell
cd C:\INTEMA_ERP\intema_erp_v2
docker compose -f docker-compose.prod.yml up -d
```

Ver logs:

```powershell
cd C:\INTEMA_ERP\intema_erp_v2
docker compose -f docker-compose.prod.yml logs -f api
```

## 9. Respaldo basico de datos

Crear una carpeta:

```text
C:\INTEMA_ERP\backups
```

Ejecutar:

```powershell
docker exec intema_erp_postgres pg_dump -U intema_app -Fc intema_erp > C:\INTEMA_ERP\backups\intema_erp.dump
```

Ese archivo es el respaldo de la base de datos.

## Nota importante

No borrar el volumen de Docker `intema_postgres_data` cuando ya se use en produccion, porque ahi vive la base de datos.
