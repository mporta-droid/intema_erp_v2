import re
from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.api.deps import require_permission
from app.db.session import get_db
from app.models.mes import (
    Machine,
    ProductionRouteStep,
    ProductionRun,
    QualityInspection,
    WarehouseIssue,
    WorkOrder,
    WorkOrderComponent,
)
from app.models.user import User
from app.schemas.mes import (
    MachineCreate,
    MachineRead,
    MachineUpdate,
    ObservationClose,
    QualityInspectionCreate,
    QualitySkipCreate,
    QuantityClose,
    RouteReplace,
    WarehouseIssueCreate,
    WarehouseIssueRead,
    WorkOrderCreate,
    WorkOrderRead,
    WorkOrderUpdate,
)
from app.services.audit import write_audit

router = APIRouter()

ACTIVE_OIT_STATUSES = {
    "pending_design",
    "design_in_progress",
    "design_paused",
    "pending_production",
    "production_planned",
    "production_in_progress",
    "pending_quality",
}


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


@router.get("/machines", response_model=list[MachineRead])
def list_machines(
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("production.view")),
) -> list[Machine]:
    return list(
        db.execute(
            select(Machine).where(Machine.is_active.is_(True)).order_by(Machine.name)
        ).scalars().all()
    )


@router.post("/machines", response_model=MachineRead, status_code=status.HTTP_201_CREATED)
def create_machine(
    payload: MachineCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("production.edit")),
) -> Machine:
    existing = db.execute(select(Machine).where(Machine.name == payload.name)).scalar_one_or_none()
    if existing is not None:
        return existing
    machine = Machine(name=payload.name, process_name=payload.process_name)
    db.add(machine)
    db.commit()
    db.refresh(machine)
    return machine


@router.put("/machines/{machine_id}", response_model=MachineRead)
def update_machine(
    machine_id: UUID,
    payload: MachineUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("production.edit")),
) -> Machine:
    machine = db.get(Machine, machine_id)
    if machine is None:
        raise HTTPException(status_code=404, detail="Máquina no encontrada.")
    existing = db.execute(select(Machine).where(Machine.name == payload.name)).scalar_one_or_none()
    if existing is not None and existing.id != machine.id:
        raise HTTPException(status_code=400, detail="Ya existe una máquina con ese nombre.")
    machine.name = payload.name
    machine.process_name = payload.process_name
    machine.is_active = payload.is_active
    db.commit()
    db.refresh(machine)
    return machine


@router.delete("/machines/{machine_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_machine(
    machine_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(require_permission("production.edit")),
) -> None:
    machine = db.get(Machine, machine_id)
    if machine is None:
        raise HTTPException(status_code=404, detail="Máquina no encontrada.")
    machine.is_active = False
    db.commit()


@router.put("/components/{component_id}/route", response_model=WorkOrderRead)
def replace_route(
    component_id: UUID,
    payload: RouteReplace,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("production.edit")),
) -> WorkOrder:
    component = get_component_or_404(db, component_id)
    if component.status not in {"pending_production", "production_planned", "production_in_progress"}:
        raise HTTPException(status_code=400, detail="El componente debe estar terminado en diseño para planificar producción.")
    machines = {machine.id: machine for machine in db.execute(select(Machine)).scalars().all()}
    existing_routes = sorted(component.routes, key=lambda route: route.sequence)
    used_route_ids: set[UUID] = set()
    planned_routes: list[ProductionRouteStep] = []
    for step in sorted(payload.steps, key=lambda item: item.sequence):
        if step.machine_id not in machines:
            raise HTTPException(status_code=400, detail="Una de las máquinas seleccionadas no existe.")
        route = next(
            (
                item
                for item in existing_routes
                if item.id not in used_route_ids and item.machine_id == step.machine_id
            ),
            None,
        )
        if route is None:
            route = ProductionRouteStep(
                sequence=step.sequence,
                machine_id=step.machine_id,
                process_name=step.process_name,
                status="pending",
                planned_by_id=current_user.id,
            )
            component.routes.append(route)
        else:
            route.sequence = step.sequence
            route.process_name = step.process_name
            route.planned_by_id = current_user.id
            used_route_ids.add(route.id)
        planned_routes.append(route)
    for route in existing_routes:
        if route in planned_routes:
            continue
        if route.status != "pending" or route.runs:
            raise HTTPException(
                status_code=400,
                detail="No se puede quitar un proceso que ya tiene tiempos o avance registrado.",
            )
        component.routes.remove(route)
    has_started_route = any(route.status != "pending" or route.runs for route in component.routes)
    next_status = "production_in_progress" if has_started_route else "production_planned"
    component.status = next_status
    component.work_order.status = next_status
    write_audit(db, actor=current_user, action="production_route_planned", entity_type="work_order_components", entity_id=str(component.id), request=request)
    db.commit()
    return load_work_order(db, component.work_order_id)


@router.post("/routes/{route_id}/start", response_model=WorkOrderRead)
def start_production_route(
    route_id: UUID,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("production.operate")),
) -> WorkOrder:
    route = get_route_or_404(db, route_id)
    if route.status not in {"setup_finished", "paused"}:
        raise HTTPException(status_code=400, detail="Este proceso no está disponible para iniciar.")
    route.status = "running"
    route.component.status = "production_in_progress"
    route.component.work_order.status = "production_in_progress"
    db.add(ProductionRun(route_step_id=route.id, operator_id=current_user.id, status="running", run_type="machining"))
    write_audit(db, actor=current_user, action="production_started", entity_type="production_route_steps", entity_id=str(route.id), request=request)
    db.commit()
    return load_work_order(db, route.component.work_order_id)


@router.post("/routes/{route_id}/setup/start", response_model=WorkOrderRead)
def start_setup_route(
    route_id: UUID,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("production.operate")),
) -> WorkOrder:
    route = get_route_or_404(db, route_id)
    if route.status not in {"pending", "setup_paused"}:
        raise HTTPException(status_code=400, detail="La preparación no está disponible para iniciar.")
    route.status = "setup_running"
    route.component.status = "production_in_progress"
    route.component.work_order.status = "production_in_progress"
    db.add(ProductionRun(route_step_id=route.id, operator_id=current_user.id, status="running", run_type="setup"))
    write_audit(db, actor=current_user, action="setup_started", entity_type="production_route_steps", entity_id=str(route.id), request=request)
    db.commit()
    return load_work_order(db, route.component.work_order_id)


@router.post("/runs/{run_id}/setup/pause", response_model=WorkOrderRead)
def pause_setup_run(
    run_id: UUID,
    payload: ObservationClose,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("production.operate")),
) -> WorkOrder:
    run = db.get(ProductionRun, run_id)
    if run is None:
        raise HTTPException(status_code=404, detail="Registro de preparación no encontrado.")
    if run.status != "running" or run.run_type != "setup":
        raise HTTPException(status_code=400, detail="Este registro de preparación no está en curso.")
    now = datetime.now(UTC)
    route = run.route_step
    run.status = "paused"
    run.finished_at = now
    run.observations = payload.observations
    run.elapsed_seconds = max(0, int((now - run.started_at).total_seconds()))
    route.status = "setup_paused"
    route.component.status = "production_in_progress"
    route.component.work_order.status = "production_in_progress"
    write_audit(db, actor=current_user, action="setup_paused", entity_type="production_runs", entity_id=str(run.id), request=request)
    db.commit()
    return load_work_order(db, route.component.work_order_id)


@router.post("/routes/{route_id}/setup/finish", response_model=WorkOrderRead)
def finish_setup_route(
    route_id: UUID,
    payload: ObservationClose,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("production.operate")),
) -> WorkOrder:
    route = get_route_or_404(db, route_id)
    if route.status not in {"setup_running", "setup_paused"}:
        raise HTTPException(status_code=400, detail="Primero inicia la preparación.")
    now = datetime.now(UTC)
    run = running_run(route, "setup")
    entity_id = str(route.id)
    if run is not None:
        run.status = "finished"
        run.finished_at = now
        run.observations = payload.observations
        run.elapsed_seconds = max(0, int((now - run.started_at).total_seconds()))
        entity_id = str(run.id)
    route.status = "setup_finished"
    route.component.status = "production_in_progress"
    route.component.work_order.status = "production_in_progress"
    write_audit(db, actor=current_user, action="setup_finished", entity_type="production_runs", entity_id=entity_id, request=request)
    db.commit()
    return load_work_order(db, route.component.work_order_id)


@router.post("/runs/{run_id}/finish", response_model=WorkOrderRead)
def finish_production_run(
    run_id: UUID,
    payload: QuantityClose,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("production.operate")),
) -> WorkOrder:
    run = db.get(ProductionRun, run_id)
    if run is None:
        raise HTTPException(status_code=404, detail="Registro de producción no encontrado.")
    if run.status != "running":
        raise HTTPException(status_code=400, detail="Este registro de producción no está en curso.")
    now = datetime.now(UTC)
    route = run.route_step
    component = route.component
    if run.run_type != "machining":
        raise HTTPException(status_code=400, detail="Este registro no corresponde a mecanizado.")
    remaining = remaining_route_quantity(route, run.id)
    if payload.good_quantity > remaining:
        raise HTTPException(status_code=400, detail=f"Solo faltan {remaining} piezas en este proceso.")
    if payload.good_quantity < remaining:
        raise HTTPException(status_code=400, detail="Para terminar el proceso debes completar todas las piezas faltantes.")
    run.status = "finished"
    run.finished_at = now
    run.good_quantity = payload.good_quantity
    run.rejected_quantity = payload.rejected_quantity
    run.observations = payload.observations
    run.elapsed_seconds = max(0, int((now - run.started_at).total_seconds()))
    route.status = "finished"
    component.quantity_completed = component_production_quantity(component)
    if all(step.status == "finished" for step in component.routes) and component.quantity_completed >= component.quantity_required:
        component.status = "pending_quality"
    else:
        component.status = "production_in_progress"
    update_work_order_flow_status(component.work_order)
    write_audit(db, actor=current_user, action="production_finished", entity_type="production_runs", entity_id=str(run.id), request=request)
    db.commit()
    return load_work_order(db, component.work_order_id)


@router.post("/runs/{run_id}/pause", response_model=WorkOrderRead)
def pause_production_run(
    run_id: UUID,
    payload: QuantityClose,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("production.operate")),
) -> WorkOrder:
    run = db.get(ProductionRun, run_id)
    if run is None:
        raise HTTPException(status_code=404, detail="Registro de producción no encontrado.")
    if run.status != "running":
        raise HTTPException(status_code=400, detail="Este registro de producción no está en curso.")
    now = datetime.now(UTC)
    route = run.route_step
    component = route.component
    if run.run_type != "machining":
        raise HTTPException(status_code=400, detail="Este registro no corresponde a mecanizado.")
    remaining = remaining_route_quantity(route, run.id)
    if payload.good_quantity > remaining:
        raise HTTPException(status_code=400, detail=f"Solo faltan {remaining} piezas en este proceso.")
    if payload.good_quantity == remaining:
        raise HTTPException(status_code=400, detail="Si completaste todas las piezas, usa Terminar.")
    run.status = "paused"
    run.finished_at = now
    run.good_quantity = payload.good_quantity
    run.rejected_quantity = payload.rejected_quantity
    run.observations = payload.observations
    run.elapsed_seconds = max(0, int((now - run.started_at).total_seconds()))
    route.status = "paused"
    component.quantity_completed = component_production_quantity(component)
    component.status = "production_in_progress"
    component.work_order.status = "production_in_progress"
    write_audit(db, actor=current_user, action="production_paused", entity_type="production_runs", entity_id=str(run.id), request=request)
    db.commit()
    return load_work_order(db, component.work_order_id)


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


def resolve_oit_code(db: Session, requested_code: str | None, current_id: UUID | None = None) -> str:
    code = normalize_oit_code(requested_code)
    if not code:
        code = next_oit_code(db)
    existing = db.execute(select(WorkOrder).where(WorkOrder.code == code)).scalar_one_or_none()
    if existing is not None and existing.id != current_id:
        raise HTTPException(status_code=400, detail="Ya existe una OIT con ese número.")
    return code


def normalize_oit_code(value: str | None) -> str:
    raw = (value or "").strip().upper()
    if not raw:
        return raw
    if raw.isdigit():
        return f"OIT-{datetime.now(UTC).year}-{int(raw):05d}"
    match = re.fullmatch(r"(?:OIT[- ]?)?(\d{4})[- ]?(\d+)", raw)
    if match:
        year, sequence = match.groups()
        return f"OIT-{year}-{int(sequence):05d}"
    return raw


def next_oit_code(db: Session) -> str:
    year = datetime.now(UTC).year
    codes = db.execute(select(WorkOrder.code)).scalars().all()
    current = 0
    for code in codes:
        match = re.fullmatch(rf"OIT-{year}-(\d+)", code)
        if match:
            current = max(current, int(match.group(1)))
    return f"OIT-{year}-{current + 1:05d}"


def get_work_order_or_404(db: Session, work_order_id: UUID) -> WorkOrder:
    work_order = load_work_order(db, work_order_id)
    if work_order is None:
        raise HTTPException(status_code=404, detail="OIT no encontrada.")
    return work_order


def get_component_or_404(db: Session, component_id: UUID) -> WorkOrderComponent:
    component = db.get(WorkOrderComponent, component_id)
    if component is None:
        raise HTTPException(status_code=404, detail="Componente no encontrado.")
    return component


def get_route_or_404(db: Session, route_id: UUID) -> ProductionRouteStep:
    route = db.get(ProductionRouteStep, route_id)
    if route is None:
        raise HTTPException(status_code=404, detail="Proceso planificado no encontrado.")
    return route


def running_run(route: ProductionRouteStep, run_type: str) -> ProductionRun | None:
    return next(
        (
            run
            for run in route.runs
            if run.status == "running" and run.run_type == run_type
        ),
        None,
    )


def route_completed_quantity(route: ProductionRouteStep, exclude_run_id: UUID | None = None) -> int:
    return sum(
        run.good_quantity
        for run in route.runs
        if run.id != exclude_run_id
        and run.run_type == "machining"
        and run.status in {"paused", "finished"}
    )


def remaining_route_quantity(route: ProductionRouteStep, exclude_run_id: UUID | None = None) -> int:
    completed = route_completed_quantity(route, exclude_run_id)
    return max(0, route.component.quantity_required - completed)


def component_production_quantity(component: WorkOrderComponent) -> int:
    if not component.routes:
        return min(component.quantity_required, component.quantity_completed)
    completed_by_route = [route_completed_quantity(route) for route in component.routes]
    return min(component.quantity_required, max(completed_by_route, default=0))


def load_work_order(db: Session, work_order_id: UUID) -> WorkOrder | None:
    stmt = (
        select(WorkOrder)
        .where(WorkOrder.id == work_order_id)
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
    )
    return db.execute(stmt).scalar_one_or_none()


def update_work_order_flow_status(work_order: WorkOrder) -> None:
    statuses = {component.status for component in work_order.components}
    if statuses <= {"pending_quality", "finished"}:
        work_order.status = "pending_quality"
    elif "production_in_progress" in statuses:
        work_order.status = "production_in_progress"
    elif "production_planned" in statuses:
        work_order.status = "production_planned"
    elif "pending_production" in statuses:
        work_order.status = "pending_production"
    elif "design_in_progress" in statuses:
        work_order.status = "design_in_progress"
    elif "design_paused" in statuses:
        work_order.status = "design_paused"
    elif "pending_design" in statuses:
        work_order.status = "pending_design"
