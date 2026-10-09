"""Router composition for the MES API."""

from fastapi import APIRouter

from app.api.v1.endpoints.mes import design, production, quality, warehouse, work_orders

router = APIRouter()
router.include_router(work_orders.router)
router.include_router(design.router)
router.include_router(production.router)
router.include_router(quality.router)
router.include_router(warehouse.router)
