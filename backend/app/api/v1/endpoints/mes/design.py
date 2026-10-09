from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.api.deps import require_permission
from app.db.session import get_db
from app.models.mes import WorkOrder
from app.models.user import User
from app.schemas.mes import ObservationClose, WorkOrderRead
from app.services.audit import write_audit
from app.api.v1.endpoints.mes.common import get_component_or_404, load_work_order, update_work_order_flow_status

router = APIRouter()


@router.post("/components/{component_id}/design/start", response_model=WorkOrderRead)
def start_design(
    component_id: UUID,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("design.edit")),
) -> WorkOrder:
    component = get_component_or_404(db, component_id)
    if component.status not in {"pending_design", "design_paused"}:
        raise HTTPException(status_code=400, detail="El componente no está pendiente de diseño.")
    component.status = "design_in_progress"
    component.design_started_at = datetime.now(UTC)
    component.designer_id = current_user.id
    component.work_order.status = "design_in_progress"
    write_audit(db, actor=current_user, action="design_started", entity_type="work_order_components", entity_id=str(component.id), request=request)
    db.commit()
    return load_work_order(db, component.work_order_id)


@router.post("/components/{component_id}/design/pause", response_model=WorkOrderRead)
def pause_design(
    component_id: UUID,
    payload: ObservationClose,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("design.edit")),
) -> WorkOrder:
    component = get_component_or_404(db, component_id)
    if component.status != "design_in_progress" or component.design_started_at is None:
        raise HTTPException(status_code=400, detail="Primero inicia el diseÃ±o del componente.")
    now = datetime.now(UTC)
    component.design_seconds += max(0, int((now - component.design_started_at).total_seconds()))
    component.design_started_at = None
    component.status = "design_paused"
    update_work_order_flow_status(component.work_order)
    write_audit(
        db,
        actor=current_user,
        action="design_paused",
        entity_type="work_order_components",
        entity_id=str(component.id),
        detail={"observations": payload.observations},
        request=request,
    )
    db.commit()
    return load_work_order(db, component.work_order_id)


@router.post("/components/{component_id}/design/finish", response_model=WorkOrderRead)
def finish_design(
    component_id: UUID,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("design.edit")),
) -> WorkOrder:
    component = get_component_or_404(db, component_id)
    if component.status != "design_in_progress" or component.design_started_at is None:
        raise HTTPException(status_code=400, detail="Primero inicia el diseño del componente.")
    now = datetime.now(UTC)
    component.design_finished_at = now
    component.design_seconds += max(0, int((now - component.design_started_at).total_seconds()))
    component.status = "pending_production"
    component.design_started_at = None
    update_work_order_flow_status(component.work_order)
    write_audit(db, actor=current_user, action="design_finished", entity_type="work_order_components", entity_id=str(component.id), request=request)
    db.commit()
    return load_work_order(db, component.work_order_id)

