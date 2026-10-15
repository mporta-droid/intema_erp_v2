# Prueba local del flujo web (Next.js + FastAPI + PostgreSQL)

Este procedimiento prepara un entorno de pruebas local. No despliega a producción y no debe utilizar datos reales de clientes.

## Requisitos

- PostgreSQL 16 instalado y activo.
- Python 3.11.
- Node.js 22 y npm.
- Repositorios `mporta-droid/intema_erp_v2` y `mporta-droid/Intema-web` clonados en la misma PC.
- Acceso a la rama `chore/audit-modular-architecture` de ambos repositorios.

## 1. Crear una base de datos aislada

Desde psql, con un usuario administrador de PostgreSQL:

```sql
CREATE USER intema_app WITH PASSWORD 'REEMPLAZAR_POR_UNA_CLAVE_LOCAL';
CREATE DATABASE intema_erp OWNER intema_app;
```

Si el usuario o la base ya existen, no repitas estos comandos; revisa la configuración existente y utiliza una base de pruebas separada.

## 2. Configurar variables del backend

En la raíz del repositorio `intema_erp_v2`, crea un archivo local `.env` (no lo subas a Git). Define, como mínimo:

```dotenv
ENVIRONMENT=local
DATABASE_URL=postgresql+psycopg://intema_app:REEMPLAZAR_POR_UNA_CLAVE_LOCAL@localhost:5432/intema_erp
JWT_SECRET_KEY=REEMPLAZAR_POR_UN_SECRETO_LOCAL_LARGO_Y_ALEATORIO
ADMIN_USERNAME=admin
ADMIN_PASSWORD=REEMPLAZAR_POR_UNA_CLAVE_ADMIN_LOCAL
BACKEND_CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:3000
```

Usa contraseñas locales únicas. Si la contraseña de PostgreSQL contiene caracteres reservados de URL, codifícalos en la cadena de conexión.

## 3. Instalar e iniciar el backend

Desde PowerShell, en la raíz del repositorio backend:

```powershell
cd backend
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
alembic upgrade head
python -m app.db.init_db
uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Comprueba en el navegador `http://localhost:8000/api/v1/health` y `http://localhost:8000/docs`. Mantén esta terminal abierta.

## 4. Configurar e iniciar el frontend

En otra terminal, desde el repositorio `Intema-web`:

Crea `.env.local` con:

```dotenv
NEXT_PUBLIC_API_BASE_URL=http://localhost:8000/api/v1
```

Después ejecuta:

```powershell
npm install
npm run dev
```

Abre `http://localhost:3000/login`. Inicia sesión con el usuario y la contraseña de administrador definidos para la base local en el paso 2.

## 5. Pruebas de aceptación

1. Iniciar sesión con credenciales válidas.
2. Verificar que credenciales incorrectas no permitan entrar.
3. Abrir el dashboard sin errores de conexión.
4. Ir a OIT y crear una orden con cliente, descripción y al menos un componente.
5. Confirmar que aparece en la lista.
6. Recargar la página y confirmar que la OIT continúa registrada.
7. Verificar rechazo de peticiones sin sesión y de un usuario sin permisos.
8. Comprobar la renovación de sesión con las pruebas automatizadas; la renovación se activa cuando una petición devuelve HTTP 401 y hay un refresh token almacenado.

## Precauciones

- Este entorno es local y de pruebas; no es una autorización para producción.
- No uses información confidencial ni contraseñas de la empresa.
- No expongas los puertos a Internet ni cambies el entorno a `production` para esta prueba.
- La prueba automatizada recrea y elimina las tablas de la base indicada por `TEST_DATABASE_URL`. **Nunca apuntes esa variable a una base con datos que debas conservar.**
- No compartas archivos `.env`, tokens ni capturas que muestren secretos.
