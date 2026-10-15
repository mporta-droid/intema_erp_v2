# INTEMA ERP/MES — arquitectura del backend

## Estado actual
Backend FastAPI en backend/. El punto de entrada backend/app/main.py registra /api/v1. Ya hay capas separadas para API, modelos, esquemas, servicios, configuración, seguridad, base de datos y migraciones Alembic.

## Estructura vigente observada
- app/api/v1/endpoints/: endpoints REST para autenticación, salud, MES, usuarios, roles y permisos.
- app/api/v1/router.py: agregador de routers.
- app/core/: configuración, seguridad y catálogo de permisos.
- app/db/: conexión y sesión de base de datos.
- app/models/: modelos ORM.
- app/schemas/: validación de entrada y salida.
- app/services/: autenticación, auditoría, permisos y datos iniciales.
- app/tests/: pruebas existentes.
- alembic/ y alembic.ini: migraciones de esquema.
- requirements.txt, pyproject.toml y Dockerfile: dependencias y ejecución.

## Decisión de arquitectura
No mover de golpe las capas existentes a app/modules/: las importaciones y relaciones ORM pueden romperse. Modularizar gradualmente por dominio preservando rutas API y tablas actuales.

Estructura objetivo por etapas:
app/
  api/v1/endpoints/   # adaptadores HTTP; preservar contratos actuales
  core/               # configuración, seguridad, permisos
  db/                 # engine y sesiones
  modules/
    cotizaciones/     # models, schemas, service, router cuando exista funcionalidad
    diseno/
    produccion/
    almacen/
    calidad/
  models/             # compatibilidad temporal durante migración
  services/           # servicios transversales temporales
  main.py

No crear módulos vacíos que aparenten funcionalidad. Extraer cada dominio cuando tenga modelos, reglas, esquemas, endpoints y pruebas.

## Controles obligatorios
1. No exponer PostgreSQL a Internet. La API es la vía de acceso del frontend.
2. Mantener secretos en variables de entorno o un gestor de secretos, nunca en Git.
3. Configurar CORS con orígenes explícitos en producción.
4. Usar Alembic para cambios de esquema.
5. Probar autorización para cada operación sensible; ocultar botones no es seguridad.
6. Validar autenticación, permisos, transacciones, auditoría y errores antes de producción.
7. Registrar estado base de pruebas antes de refactorizar y verificar contratos REST después.
8. Mantener main estable y usar ramas y pull requests.

## Próximos pasos
1. Confirmar ejecución de pruebas y cobertura.
2. Revisar endpoints, permisos, transacciones y modelos de OIT.
3. Añadir o validar CI de backend.
4. Extraer un dominio pequeño con pruebas antes de migrar más.
5. Documentar variables de entorno y despliegue local reproducible.