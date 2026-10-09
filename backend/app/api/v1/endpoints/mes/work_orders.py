from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.api.deps import require_permission
from app.db.session import get_db
from app.models.mes import ProductionRouteStep, WorkOrder, WorkOrderComponent
from app.models.user import User
from app.schemas.mes import WorkOrderCreate, WorkOrderRead, WorkOrderUpdate
from app.services.audit import write_audit
from app.api.v1.endpoints.mes.common import get_work_order_or_404, load_work_order, resolve_oit_code

router = APIRouter()


@router.get("/work-orders", response_model=list[WorkOrderRead])
def list_work_orders(
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("work_orders.view")),
) -> list[WorkOrder]:
    stmt = (
        select(WorkOrder)
        .options(
            selectinload(WorkOrder.components)
            .selectinload(WorkOrderComponent.routes)
            .selectinload(ProductionRouteStep.machine),
            selectinload(WorkOrder.components)
            .selectinload(WorkOrderComponent.routes)
            .selectinload(ProductionRouteStep.runs),
            selectinload(WorkOrder.components).selectinload(WorkOrderComponent.quality_inspections),
            selectinload(WorkOrder.warehouse_issues),
        )
        .order_by(WorkOrder.created_at.desc())
    )
    return list(db.execute(stmt).scalars().all())


@router.post("/work-orders", response_model=WorkOrderRead, status_code=status.HTTP_201_CREATED)
def create_work_order(
    payload: WorkOrderCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("work_orders.create")),
) -> WorkOrder:
    code = resolve_oit_code(db, payload.code)
    work_order = WorkOrder(
        code=code,
        client_name=payload.client_name,
        description=payload.description,
        priority=payload.priority,
        due_date=payload.due_date,
        status="draft",
        created_by_id=current_user.id,
    )
    work_order.components = [
        WorkOrderComponent(
            name=component.name,
            drawing_code=component.drawing_code,
            quantity_required=component.quantity_required,
            status="draft",
        )
        for component in payload.components
    ]
    db.add(work_order)
    write_audit(db, actor=current_user, action="oit_created", entity_type="work_orders", detail={"code": code}, request=request)
    db.commit()
    return load_work_order(db, work_order.id)


@router.put("/work-orders/{work_order_id}", response_model=WorkOrderRead)
def update_work_order(
    work_order_id: UUID,
    payload: WorkOrderUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("work_orders.edit")),
) -> WorkOrder:
    work_order = get_work_order_or_404(db, work_order_id)
    if work_order.status != "draft":
        raise HTTPException(status_code=400, detail="Solo se puede editar una OIT antes de aprobarla.")
    work_order.code = resolve_oit_code(db, payload.code or work_order.code, current_id=work_order.id)
    work_order.client_name = payload.client_name
    work_order.description = payload.description
    work_order.priority = payload.priority
    work_order.due_date = payload.due_date
    work_order.components = [
        WorkOrderComponent(
            name=component.name,
            drawing_code=component.drawing_code,
            quantity_required=component.quantity_required,
            status="draft",
        )
        for component in payload.components
    ]
    write_audit(db, actor=current_user, action="oit_updated", entity_type="work_orders", entity_id=str(work_order.id), request=request)
    db.commit()
    return load_work_order(db, work_order.id)


@router.delete("/work-orders/{work_order_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_work_order(
    work_order_id: UUID,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("work_orders.delete")),
) -> None:
    work_order = get_work_order_or_404(db, work_order_id)
    if work_order.status != "draft":
        raise HTTPException(status_code=400, detail="Solo se puede eliminar una OIT antes de aprobarla.")
    write_audit(db, actor=current_user, action="oit_deleted", entity_type="work_orders", entity_id=str(work_order.id), detail={"code": work_order.code}, request=request)
    db.delete(work_order)
    db.commit()


@router.post("/work-orders/{work_order_id}/approve", response_model=WorkOrderRead)
def approve_work_order(
    work_order_id: UUID,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("work_orders.approve")),
) -> WorkOrder:
    work_order = get_work_order_or_404(db, work_order_id)
    if work_order.status != "draft":
        raise HTTPException(status_code=400, detail="Solo se puede aprobar una OIT en borrador.")
    work_order.status = "pending_design"
    work_order.approved_by_id = current_user.id
    work_order.approved_at = datetime.now(UTC)
    for component in work_order.components:
        component.status = "pending_design"
    write_audit(db, actor=current_user, action="oit_approved", entity_type="work_orders", entity_id=str(work_order.id), request=request)
    db.commit()
    return load_work_order(db, work_order.id)


@router.post("/work-orders/{work_order_id}/deliver", response_model=WorkOrderRead)
def deliver_work_order(
    work_order_id: UUID,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("work_orders.edit")),
) -> WorkOrder:
    work_order = get_work_order_or_404(db, work_order_id)
    if not work_order.components or any(
        component.status not in {"pending_quality", "finished"}
        for component in work_order.components
    ):
        raise HTTPException(status_code=400, detail="La OIT solo se puede entregar cuando todos sus componentes terminaron producción.")
    for component in work_order.components:
        component.status = "finished"
    work_order.status = "finished"
    write_audit(db, actor=current_user, action="oit_delivered", entity_type="work_orders", entity_id=str(work_order.id), request=request)
    db.commit()
    return load_work_order(db, work_order.id)

