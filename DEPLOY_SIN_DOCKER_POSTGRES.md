# INTEMA ERP/MES - Produccion sin Docker, con PostgreSQL

Esta opcion usa:

- PostgreSQL instalado directo en el servidor.
- Python/FastAPI instalado directo en el servidor.
- La app Windows `.exe` en las PCs cliente.

Docker ya no se usa.

## 1. Instalar en el servidor

Instalar:

- PostgreSQL 16 o superior.
- Python 3.12.

Durante la instalacion de PostgreSQL, guardar la clave del usuario `postgres`.

## 2. Crear base de datos y usuario

Abrir `SQL Shell (psql)` o pgAdmin y ejecutar:

```sql
CREATE USER intema_app WITH PASSWORD 'cambiar_esta_clave_segura';
CREATE DATABASE intema_erp OWNER intema_app;
GRANT ALL PRIVILEGES ON DATABASE intema_erp TO intema_app;
```

Guardar la clave usada para `intema_app`.

## 3. Copiar el proyecto al servidor

Copiar por USB esta carpeta completa:

```text
intema_erp_v2
```

Por ejemplo dejarla en:

```text
C:\INTEMA_ERP\intema_erp_v2
```

## 4. Configurar `.env`

Abrir:

```text
C:\INTEMA_ERP\intema_erp_v2\.env
```

Ajustar estos valores:

```env
ENVIRONMENT=production
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=intema_erp
POSTGRES_USER=intema_app
POSTGRES_PASSWORD=cambiar_esta_clave_segura
DATABASE_URL=postgresql+psycopg://intema_app:cambiar_esta_clave_segura@localhost:5432/intema_erp
JWT_SECRET_KEY=poner_una_clave_larga_y_dificil
ACCESS_TOKEN_EXPIRE_MINUTES=480
REFRESH_TOKEN_EXPIRE_MINUTES=720
ADMIN_USERNAME=admin
ADMIN_PASSWORD=Cambiar123!
```

`480` minutos equivale a 8 horas.

## 5. Crear entorno Python e instalar dependencias

Abrir PowerShell:

```powershell
cd C:\INTEMA_ERP\intema_erp_v2
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r backend\requirements.txt
```

## 6. Preparar la base de datos

En el mismo PowerShell:

```powershell
cd C:\INTEMA_ERP\intema_erp_v2\backend
..\ .venv\Scripts\Activate.ps1
alembic upgrade head
python -m app.db.init_db
```

Si PowerShell no acepta la linea de activar, usar:

```powershell
C:\INTEMA_ERP\intema_erp_v2\.venv\Scripts\python.exe -m alembic upgrade head
C:\INTEMA_ERP\intema_erp_v2\.venv\Scripts\python.exe -m app.db.init_db
```

## 7. Encender la API

Ejecutar:

```powershell
cd C:\INTEMA_ERP\intema_erp_v2\backend
C:\INTEMA_ERP\intema_erp_v2\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Debe aparecer:

```text
Uvicorn running on http://0.0.0.0:8000
```

## 8. Probar en el servidor

Abrir:

```text
http://localhost:8000/api/v1
```

Tambien:

```text
http://localhost:8000/docs
```

## 9. Probar desde otra PC

En el servidor obtener el IP:

```powershell
ipconfig
```

Desde otra PC abrir:

```text
http://IP_DEL_SERVIDOR:8000/api/v1
```

Si no abre, permitir el puerto `8000` en Firewall de Windows del servidor.

## 10. App Windows para las PCs

En la laptop de desarrollo compilar:

```powershell
cd C:\Users\MARTIN\Documents\Codex\2026-08-10\corregir-5\intema_erp_v2\frontend
flutter build windows --release --dart-define=API_BASE_URL=http://IP_DEL_SERVIDOR:8000/api/v1
```

Copiar a cada PC la carpeta:

```text
frontend\build\windows\x64\runner\Release
```

Abrir:

```text
intema_erp_frontend.exe
```

## 11. Respaldo

Ejemplo con `pg_dump`:

```powershell
pg_dump -h localhost -U intema_app -Fc intema_erp > C:\INTEMA_ERP\backups\intema_erp.dump
```

Ese archivo es el respaldo de datos.

