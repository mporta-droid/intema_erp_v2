from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import require_permission
from app.db.session import get_db
from app.models.mes import Machine, ProductionRouteStep, ProductionRun, WorkOrder
from app.models.user import User
from app.schemas.mes import (
    MachineCreate,
    MachineRead,
    MachineUpdate,
    ObservationClose,
    QuantityClose,
    RouteReplace,
    WorkOrderRead,
)
from app.services.audit import write_audit
from app.api.v1.endpoints.mes.common import (
    component_production_quantity,
    get_component_or_404,
    get_route_or_404,
    load_work_order,
    remaining_route_quantity,
    route_completed_quantity,
    running_run,
    update_work_order_flow_status,
)

router = APIRouter()


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

