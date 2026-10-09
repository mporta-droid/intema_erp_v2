from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.api.deps import require_permission
from app.db.session import get_db
from app.models.mes import WarehouseIssue
from app.models.user import User
from app.schemas.mes import WarehouseIssueCreate, WarehouseIssueRead
from app.services.audit import write_audit
from app.api.v1.endpoints.mes.common import ACTIVE_OIT_STATUSES, get_work_order_or_404

router = APIRouter()


@router.post("/warehouse/issues", response_model=WarehouseIssueRead, status_code=status.HTTP_201_CREATED)
def issue_warehouse_item(
    payload: WarehouseIssueCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("inventory_movements.create")),
) -> WarehouseIssue:
    work_order = get_work_order_or_404(db, payload.work_order_id)
    if work_order.status not in ACTIVE_OIT_STATUSES:
        raise HTTPException(status_code=400, detail="Almacén solo puede entregar materiales o herramientas a una OIT activa.")
    if payload.component_id and all(component.id != payload.component_id for component in work_order.components):
        raise HTTPException(status_code=400, detail="El componente no pertenece a la OIT seleccionada.")
    issue = WarehouseIssue(
        work_order_id=payload.work_order_id,
        component_id=payload.component_id,
        item_name=payload.item_name,
        issue_type=payload.issue_type,
        quantity=payload.quantity,
        unit=payload.unit,
        unit_cost=payload.unit_cost,
        observations=payload.observations,
        issued_by_id=current_user.id,
    )
    db.add(issue)
    write_audit(db, actor=current_user, action="warehouse_issue_created", entity_type="warehouse_issues", detail={"item": payload.item_name}, request=request)
    db.commit()
    db.refresh(issue)
    return issue

