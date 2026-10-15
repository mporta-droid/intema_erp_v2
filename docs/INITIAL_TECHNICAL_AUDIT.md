# Auditoría técnica inicial — INTEMA ERP/MES

Fecha: 2026-10-14
Alcance: revisión estática del repositorio; no equivale a una ejecución de pruebas ni a una auditoría de seguridad completa.

## Hallazgos confirmados

### Prioridad alta antes de producción
- `backend/app/core/config.py` define valores predeterminados para `jwt_secret_key` y `admin_password`. Aunque sirven para desarrollo, el arranque de producción debe fallar si no se han configurado secretos y credenciales fuertes explícitamente.
- `backend/app/db/session.py` crea el motor SQLAlchemy al importar el módulo. Las pruebas unitarias que no requieren base de datos deberían poder importar servicios sin intentar conectarse; revisar inicialización y pruebas aisladas.
- `backend/app/main.py` registra CORS a partir de configuración. La lista de orígenes de producción debe ser explícita y no usar comodines junto con credenciales.

### Riesgo de sesión en frontend
- `Intema-web/lib/api.ts` almacena tokens de acceso y renovación en `localStorage`. Un XSS podría exponerlos. Antes de producción, evaluar sesión con cookies `HttpOnly`, `Secure`, `SameSite` y protección CSRF según el flujo elegido.
- `NEXT_PUBLIC_API_BASE_URL` se expone al navegador; debe contener solo la URL pública de la API, nunca credenciales.

### Calidad y modularidad
- El frontend contiene rutas existentes de login, usuarios, roles y órdenes de trabajo. No mover ni renombrar rutas sin pruebas de regresión.
- `app/modules/[slug]/page.tsx` declara funcionalidades previstas, pero advierte que no están conectadas a endpoints verificados. Mantener esa distinción para no presentar funcionalidades ficticias.
- El backend ya separa endpoints, modelos, esquemas, servicios, core, db y migraciones Alembic. Una migración masiva a `app/modules/` puede romper imports y relaciones ORM; extraer cada dominio gradualmente.
- Hay pruebas unitarias de seguridad y permisos y una prueba de integración PostgreSQL que se omite cuando no se define `TEST_DATABASE_URL`.

## Plan de corrección
1. Separar configuración de desarrollo y producción; validar secretos obligatorios al iniciar en producción.
2. Revisar bootstrap de administrador y garantizar que no se crea con contraseña predeterminada en producción.
3. Ejecutar la suite en CI con PostgreSQL efímero y verificar el resultado real.
4. Revisar autorización en cada endpoint sensible y agregar pruebas negativas.
5. Mantener migraciones Alembic como única vía de cambios del esquema.
6. Modularizar un dominio por vez, preservando contratos REST y rutas del frontend.
7. Revisar almacenamiento de tokens antes del despliegue real.

## Limitaciones
Esta revisión se basa en archivos consultados mediante GitHub. No se han ejecutado localmente pytest, lint ni build; no se afirma que el sistema pase dichas verificaciones. No se han cambiado archivos de aplicación ni se ha fusionado ninguna rama en `main`.