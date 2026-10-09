# INTEMA ERP/MES v2

Proyecto nuevo y limpio para INTEMA S.A.C. Fase 1 implementada con FastAPI, PostgreSQL, SQLAlchemy, Alembic y Flutter.

## Árbol principal

```text
intema_erp_v2/
  backend/
    app/
      api/v1/endpoints/
      core/
      db/
      models/
      schemas/
      services/
      tests/
      main.py
    alembic/
    alembic.ini
    Dockerfile
    pyproject.toml
  frontend/
    lib/
      core/
      features/auth/
      features/dashboard/
      features/shell/
      features/users/
      shared/widgets/
      main.dart
    assets/images/intema_logo.png
    pubspec.yaml
  docker-compose.yml
  .env.example
  README.md
```

## Arquitectura

- Flutter no se conecta a PostgreSQL; consume la API REST de FastAPI.
- FastAPI valida JWT, permisos efectivos y reglas de acceso en cada endpoint protegido.
- PostgreSQL es la base central para LAN.
- SQLAlchemy modela datos y Alembic gestiona migraciones.
- Docker Compose levanta PostgreSQL y API; también se puede instalar sin Docker en Windows.
- Las credenciales y hosts viven en `.env`; no hay contraseñas reales en el código.

## Tablas iniciales

- `users`: usuarios activos/inactivos, credenciales hasheadas, último acceso y creador.
- `roles`: roles base editables.
- `permissions`: catálogo módulo + acción.
- `user_roles`: roles asignados a cada usuario.
- `role_permissions`: permisos incluidos en cada rol.
- `user_permissions`: excepciones individuales para conceder o denegar permisos.
- `audit_logs`: inicios de sesión, creación/edición y cambios de permisos.

## Fase 1 incluida

- Login JWT con access token y refresh token.
- Hash de contraseñas con bcrypt.
- Seed de permisos, roles base y usuario administrador.
- Menú Flutter filtrado por permisos.
- Pantalla `Usuarios y permisos` para crear usuarios, asignar roles, cambiar permisos por rol y definir excepciones individuales.
- Auditoría de login, creación/edición de usuarios y cambios de permisos.
- Pruebas unitarias para seguridad/permisos y prueba de integración contra PostgreSQL.

## Ejecutar con Docker

```powershell
copy .env.example .env
# Editar .env y cambiar POSTGRES_PASSWORD, JWT_SECRET_KEY y ADMIN_PASSWORD
docker compose up --build
```

API: http://localhost:8000/docs

## Ejecutar en Windows sin Docker

1. Instalar PostgreSQL 16.
2. Crear base y usuario:

```sql
CREATE USER intema_app WITH PASSWORD 'cambiar_esta_clave';
CREATE DATABASE intema_erp OWNER intema_app;
```

3. Copiar `.env.example` como `.env` y ajustar `DATABASE_URL`.
4. En `backend/` instalar dependencias y preparar base:

```powershell
pip install -r requirements-dev.txt
alembic upgrade head
python -m app.db.init_db
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

5. En `frontend/` ejecutar Flutter:

```powershell
flutter create --platforms=windows,android .
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

Para celulares en LAN, reemplazar `localhost` por la IP de la PC servidor.

## Respaldo PostgreSQL

```powershell
pg_dump -h localhost -U intema_app -Fc intema_erp > backups/intema_erp.dump
```

## Restauración PostgreSQL

```powershell
createdb -h localhost -U intema_app intema_erp_restaurado
pg_restore -h localhost -U intema_app -d intema_erp_restaurado backups/intema_erp.dump
```

## Fases siguientes

- Fase 2: clientes, proveedores, productos, categorías, unidades, ubicaciones, movimientos y kardex.
- Fase 3: cotizaciones y conversión a OIT.
- Fase 4: diseño, producción, tiempos, calidad, adjuntos y reprocesos.
- Fase 5: dashboard operativo, exportación Excel/PDF y reportes.

## Despliegue de API web (Supabase + Render)

El archivo `render.yaml` define el servicio Docker de FastAPI en Render. Este archivo no crea el proyecto Supabase ni configura secretos por sí solo.

1. Crea un proyecto PostgreSQL en Supabase y espera a que la base esté lista.
2. En Supabase, abre **Connect** y copia la cadena de conexión para la API. Usa el modo compatible con tu proveedor y red; el backend usa SQLAlchemy con psycopg 3, por lo que la URL debe comenzar con `postgresql+psycopg://`. Si Supabase entrega `postgresql://`, cambia únicamente el prefijo a `postgresql+psycopg://`. Mantén la contraseña codificada correctamente si contiene caracteres especiales.
3. En Render, crea un **Blueprint** desde este repositorio y revisa el servicio definido en `render.yaml`. Configura las variables solicitadas antes de exponer la API.
4. En Render, define `DATABASE_URL` con la cadena de Supabase, `BACKEND_CORS_ORIGINS` con el origen exacto de Vercel (por ejemplo `https://tu-proyecto.vercel.app`), y `ADMIN_PASSWORD` con una contraseña única y fuerte. Render genera `JWT_SECRET_KEY` automáticamente.
5. El contenedor ejecuta `alembic upgrade head` y `python -m app.db.init_db` al iniciar. Revisa los logs del primer despliegue; no des por hecho que la migración terminó correctamente hasta ver el servicio saludable.
6. Comprueba `https://TU-API.onrender.com/api/v1/health` y `https://TU-API.onrender.com/docs`.
7. En el proyecto Vercel del frontend, configura `NEXT_PUBLIC_API_BASE_URL=https://TU-API.onrender.com/api/v1` y vuelve a desplegar.

**Seguridad:** no publiques archivos `.env`, contraseñas, URLs con credenciales ni claves de Supabase en GitHub o en variables `NEXT_PUBLIC_*`. Cambia la contraseña inicial de administrador antes de usar datos reales. El plan gratuito de un proveedor puede suspender servicios inactivos o tener límites; verifica precios y disponibilidad antes de elegirlo para operación empresarial.
