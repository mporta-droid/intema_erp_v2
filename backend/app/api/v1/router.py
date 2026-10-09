from fastapi import APIRouter

from app.api.v1.endpoints import auth, health, permissions, roles, users
from app.api.v1.endpoints.mes import router as mes_router

api_router = APIRouter()
api_router.include_router(health.router, prefix="/health", tags=["salud"])
api_router.include_router(auth.router, prefix="/auth", tags=["autenticación"])
api_router.include_router(users.router, prefix="/users", tags=["usuarios"])
api_router.include_router(roles.router, prefix="/roles", tags=["roles"])
api_router.include_router(permissions.router, prefix="/permissions", tags=["permisos"])
api_router.include_router(mes_router, prefix="/mes", tags=["mes"])
