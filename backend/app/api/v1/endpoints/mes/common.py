"""Shared queries and workflow helpers for the MES API endpoints."""

import re
from datetime import UTC, datetime
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models.mes import ProductionRouteStep, ProductionRun, WorkOrder, WorkOrderComponent


ACTIVE_OIT_STATUSES = {
    "pending_design",
    "design_in_progress",
    "design_paused",
    "pending_production",
    "production_planned",
    "production_in_progress",
    "pending_quality",
}


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
