from datetime import datetime
from uuid import UUID

from sqlalchemy import JSON, Boolean, DateTime, ForeignKey, Integer, Numeric, String, Text, func
from sqlalchemy.dialects.postgresql import UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.mixins import TimestampMixin, UuidPkMixin


class WorkOrder(UuidPkMixin, TimestampMixin, Base):
    __tablename__ = "work_orders"

    code: Mapped[str] = mapped_column(String(40), unique=True, index=True)
    client_name: Mapped[str] = mapped_column(String(180))
    description: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(40), default="draft", index=True)
    priority: Mapped[str] = mapped_column(String(30), default="normal")
    created_by_id: Mapped[UUID | None] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    approved_by_id: Mapped[UUID | None] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    approved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    due_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    components = relationship("WorkOrderComponent", back_populates="work_order", cascade="all, delete-orphan")
    warehouse_issues = relationship("WarehouseIssue", back_populates="work_order", cascade="all, delete-orphan")


class WorkOrderComponent(UuidPkMixin, TimestampMixin, Base):
    __tablename__ = "work_order_components"

    work_order_id: Mapped[UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("work_orders.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(180))
    drawing_code: Mapped[str | None] = mapped_column(String(80), nullable=True)
    quantity_required: Mapped[int] = mapped_column(Integer)
    quantity_completed: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[str] = mapped_column(String(40), default="draft", index=True)
    design_started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    design_finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    design_seconds: Mapped[int] = mapped_column(Integer, default=0)
    designer_id: Mapped[UUID | None] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    work_order = relationship("WorkOrder", back_populates="components")
    routes = relationship("ProductionRouteStep", back_populates="component", cascade="all, delete-orphan")
    warehouse_issues = relationship("WarehouseIssue", back_populates="component")
    quality_inspections = relationship(
        "QualityInspection", back_populates="component", cascade="all, delete-orphan"
    )


class Machine(UuidPkMixin, TimestampMixin, Base):
    __tablename__ = "machines"

    name: Mapped[str] = mapped_column(String(120), unique=True)
    process_name: Mapped[str] = mapped_column(String(120))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")


class ProductionRouteStep(UuidPkMixin, TimestampMixin, Base):
    __tablename__ = "production_route_steps"

    component_id: Mapped[UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("work_order_components.id", ondelete="CASCADE"), index=True
    )
    sequence: Mapped[int] = mapped_column(Integer)
    machine_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("machines.id"))
    process_name: Mapped[str] = mapped_column(String(120))
    status: Mapped[str] = mapped_column(String(40), default="pending", index=True)
    planned_by_id: Mapped[UUID | None] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    component = relationship("WorkOrderComponent", back_populates="routes")
    machine = relationship("Machine")
    runs = relationship("ProductionRun", back_populates="route_step", cascade="all, delete-orphan")


class ProductionRun(UuidPkMixin, TimestampMixin, Base):
    __tablename__ = "production_runs"

    route_step_id: Mapped[UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("production_route_steps.id", ondelete="CASCADE"), index=True
    )
    operator_id: Mapped[UUID | None] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    status: Mapped[str] = mapped_column(String(40), default="running")
    run_type: Mapped[str] = mapped_column(String(40), default="machining", server_default="machining", index=True)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    good_quantity: Mapped[int] = mapped_column(Integer, default=0)
    rejected_quantity: Mapped[int] = mapped_column(Integer, default=0)
    observations: Mapped[str | None] = mapped_column(Text, nullable=True)
    elapsed_seconds: Mapped[int] = mapped_column(Integer, default=0)

    route_step = relationship("ProductionRouteStep", back_populates="runs")


class WarehouseIssue(UuidPkMixin, TimestampMixin, Base):
    __tablename__ = "warehouse_issues"

    work_order_id: Mapped[UUID] = mapped_column(PgUUID(as_uuid=True), ForeignKey("work_orders.id"), index=True)
    component_id: Mapped[UUID | None] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("work_order_components.id"), nullable=True, index=True
    )
    item_name: Mapped[str] = mapped_column(String(180))
    issue_type: Mapped[str] = mapped_column(String(40), default="material")
    quantity: Mapped[float] = mapped_column(Numeric(12, 3))
    unit: Mapped[str] = mapped_column(String(30), default="und")
    unit_cost: Mapped[float] = mapped_column(Numeric(12, 2), default=0)
    issued_by_id: Mapped[UUID | None] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    issued_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    observations: Mapped[str | None] = mapped_column(Text, nullable=True)

    work_order = relationship("WorkOrder", back_populates="warehouse_issues")
    component = relationship("WorkOrderComponent", back_populates="warehouse_issues")


class QualityInspection(UuidPkMixin, TimestampMixin, Base):
    __tablename__ = "quality_inspections"

    component_id: Mapped[UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("work_order_components.id", ondelete="CASCADE"), index=True
    )
    inspector_id: Mapped[UUID | None] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    drawing_code: Mapped[str | None] = mapped_column(String(80), nullable=True)
    instrument: Mapped[str | None] = mapped_column(String(120), nullable=True)
    nominal_value: Mapped[float | None] = mapped_column(Numeric(12, 4), nullable=True)
    min_value: Mapped[float | None] = mapped_column(Numeric(12, 4), nullable=True)
    max_value: Mapped[float | None] = mapped_column(Numeric(12, 4), nullable=True)
    accepted_quantity: Mapped[int] = mapped_column(Integer, default=0)
    rejected_quantity: Mapped[int] = mapped_column(Integer, default=0)
    measurements: Mapped[list] = mapped_column(JSON, default=list)
    photo_notes: Mapped[list] = mapped_column(JSON, default=list)
    observations: Mapped[str | None] = mapped_column(Text, nullable=True)
    inspected_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    component = relationship("WorkOrderComponent", back_populates="quality_inspections")
