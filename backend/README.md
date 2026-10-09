# Backend INTEMA ERP/MES v2

Backend FastAPI de la Fase 1: autenticación JWT, usuarios, roles, permisos y auditoría.

## Ejecutar localmente

1. Crear y activar un entorno Python 3.11+.
2. Instalar dependencias:

```powershell
pip install -r requirements-dev.txt
```

3. Configurar `.env` en la raíz del proyecto usando `.env.example`.
4. Ejecutar migraciones y seed inicial:

```powershell
alembic upgrade head
python -m app.db.init_db
```

5. Levantar API:

```powershell
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Credenciales iniciales de ejemplo: `admin` / `Cambiar123!`. Cambiar la contraseña antes de producción.

## Pruebas

```powershell
pytest
```

Las pruebas de integración usan PostgreSQL real. Para ejecutarlas:

```powershell
$env:TEST_DATABASE_URL="postgresql+psycopg://intema_app:cambiar_esta_clave@localhost:5432/intema_erp_test"
pytest app/tests/test_postgres_api_flow.py
```
