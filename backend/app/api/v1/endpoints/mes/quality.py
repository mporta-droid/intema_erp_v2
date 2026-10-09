from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.api.deps import require_permission
from app.db.session import get_db
from app.models.mes import QualityInspection, WorkOrder
from app.models.user import User
from app.schemas.mes import QualityInspectionCreate, QualitySkipCreate, WorkOrderRead
from app.services.audit import write_audit
from app.api.v1.endpoints.mes.common import get_component_or_404, load_work_order, update_work_order_flow_status

router = APIRouter()


@router.post("/components/{component_id}/quality/inspection", response_model=WorkOrderRead)
def save_quality_inspection(
    component_id: UUID,
    payload: QualityInspectionCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("quality_control.edit")),
) -> WorkOrder:
    component = get_component_or_404(db, component_id)
    if component.status != "pending_quality":
        raise HTTPException(status_code=400, detail="El componente no estÃ¡ pendiente de control de calidad.")

    measurements: list[dict] = []
    accepted = 0
    rejected = 0
    if payload.quality_points:
        for point in payload.quality_points:
            values: list[dict] = []
            for index, value in enumerate(point.values):
                in_range = None
                if (
                    value is not None
                    and point.nominal_value is not None
                    and point.min_value is not None
                    and point.max_value is not None
                ):
                    in_range = point.nominal_value + point.min_value <= value <= point.nominal_value + point.max_value
                    if in_range:
                        accepted += 1
                    else:
                        rejected += 1
                values.append(
                    {
                        "piece_label": f"Pieza {index + 1}",
                        "value": value,
                        "in_range": in_range,
                    }
                )
            measurements.append(
                {
                    "point_name": point.name,
                    "nominal_value": point.nominal_value,
                    "min_value": point.min_value,
                    "max_value": point.max_value,
                    "values": values,
                }
            )
    else:
        for measurement in payload.measurements:
            value = measurement.value
            in_range = None
            if (
                value is not None
                and payload.nominal_value is not None
                and payload.min_value is not None
                and payload.max_value is not None
            ):
                in_range = payload.nominal_value + payload.min_value <= value <= payload.nominal_value + payload.max_value
                if in_range:
                    accepted += 1
                else:
                    rejected += 1
            measurements.append(
                {
                    "piece_label": measurement.piece_label,
                    "value": value,
                    "in_range": in_range,
                }
            )

    inspection = QualityInspection(
        component_id=component.id,
        inspector_id=current_user.id,
        drawing_code=payload.drawing_code or component.drawing_code,
        instrument=payload.instrument,
        nominal_value=payload.quality_points[0].nominal_value if payload.quality_points else payload.nominal_value,
        min_value=payload.quality_points[0].min_value if payload.quality_points else payload.min_value,
        max_value=payload.quality_points[0].max_value if payload.quality_points else payload.max_value,
        accepted_quantity=accepted,
        rejected_quantity=rejected,
        measurements=measurements,
        photo_notes=[note for note in payload.photo_notes if note.strip()],
        observations=payload.observations,
    )
    db.add(inspection)
    if accepted > 0 and rejected == 0:
        component.status = "finished"
        update_work_order_flow_status(component.work_order)
    write_audit(
        db,
        actor=current_user,
        action="quality_inspection_saved",
        entity_type="work_order_components",
        entity_id=str(component.id),
        detail={"accepted": accepted, "rejected": rejected},
        request=request,
    )
    db.commit()
    return load_work_order(db, component.work_order_id)


@router.post("/components/{component_id}/quality/skip", response_model=WorkOrderRead)
def skip_quality_inspection(
    component_id: UUID,
    payload: QualitySkipCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("quality_control.edit")),
) -> WorkOrder:
    component = get_component_or_404(db, component_id)
    if component.status != "pending_quality":
        raise HTTPException(status_code=400, detail="El componente no está pendiente de control de calidad.")

    authorized_by = payload.authorized_by.strip() if payload.authorized_by else current_user.full_name
    reason = payload.reason.strip()
    observation = (
        "CONTROL DE CALIDAD OMITIDO\n"
        f"Motivo: {reason}\n"
        f"Autorizado por: {authorized_by}\n"
        f"Registrado por: {current_user.full_name}"
    )
    inspection = QualityInspection(
        component_id=component.id,
        inspector_id=current_user.id,
        drawing_code=component.drawing_code,
        instrument="No aplica",
        accepted_quantity=0,
        rejected_quantity=0,
        measurements=[
            {
                "type": "quality_skipped",
                "reason": reason,
                "authorized_by": authorized_by,
                "registered_by": current_user.full_name,
            }
        ],
        photo_notes=[],
        observations=observation,
    )
    db.add(inspection)
    component.status = "finished"
    update_work_order_flow_status(component.work_order)
    write_audit(
        db,
        actor=current_user,
        action="quality_inspection_skipped",
        entity_type="work_order_components",
        entity_id=str(component.id),
        detail={"reason": reason, "authorized_by": authorized_by},
        request=request,
    )
    db.commit()
    return load_work_order(db, component.work_order_id)

