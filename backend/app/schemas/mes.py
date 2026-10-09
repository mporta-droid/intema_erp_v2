from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class ComponentCreate(BaseModel):
    name: str = Field(min_length=2, max_length=180)
    quantity_required: int = Field(gt=0)
    drawing_code: str | None = Field(default=None, max_length=80)


class WorkOrderCreate(BaseModel):
    code: str | None = Field(default=None, max_length=40)
    client_name: str = Field(min_length=2, max_length=180)
    description: str = Field(min_length=3)
    priority: str = Field(default="normal", max_length=30)
    due_date: datetime | None = None
    components: list[ComponentCreate] = Field(min_length=1)


class WorkOrderUpdate(BaseModel):
    code: str | None = Field(default=None, max_length=40)
    client_name: str = Field(min_length=2, max_length=180)
    description: str = Field(min_length=3)
    priority: str = Field(default="normal", max_length=30)
    due_date: datetime | None = None
    components: list[ComponentCreate] = Field(min_length=1)


class MachineCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    process_name: str = Field(min_length=2, max_length=120)


class MachineUpdate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    process_name: str = Field(min_length=2, max_length=120)
    is_active: bool = True


class MachineRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    process_name: str
    is_active: bool


class RouteStepCreate(BaseModel):
    machine_id: UUID
    process_name: str = Field(min_length=2, max_length=120)
    sequence: int = Field(gt=0)


class RouteReplace(BaseModel):
    steps: list[RouteStepCreate] = Field(min_length=1)


class QuantityClose(BaseModel):
    good_quantity: int = Field(ge=0)
    rejected_quantity: int = Field(ge=0)
    observations: str | None = None


class ObservationClose(BaseModel):
    observations: str | None = None


class WarehouseIssueCreate(BaseModel):
    work_order_id: UUID
    component_id: UUID | None = None
    item_name: str = Field(min_length=2, max_length=180)
    issue_type: str = Field(default="material", max_length=40)
    quantity: float = Field(gt=0)
    unit: str = Field(default="und", max_length=30)
    unit_cost: float = Field(default=0, ge=0)
    observations: str | None = None


class QualityMeasurementIn(BaseModel):
    piece_label: str = Field(min_length=1, max_length=40)
    value: float | None = None


class QualityPointIn(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    nominal_value: float | None = None
    min_value: float | None = None
    max_value: float | None = None
    values: list[float | None] = Field(default_factory=list)


class QualityInspectionCreate(BaseModel):
    drawing_code: str | None = Field(default=None, max_length=80)
    instrument: str | None = Field(default=None, max_length=120)
    nominal_value: float | None = None
    min_value: float | None = None
    max_value: float | None = None
    measurements: list[QualityMeasurementIn] = Field(default_factory=list)
    quality_points: list[QualityPointIn] = Field(default_factory=list)
    photo_notes: list[str] = Field(default_factory=list)
    observations: str | None = None


class QualitySkipCreate(BaseModel):
    reason: str = Field(min_length=3, max_length=500)
    authorized_by: str | None = Field(default=None, max_length=160)


class QualityInspectionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    component_id: UUID
    drawing_code: str | None
    instrument: str | None
    nominal_value: float | None
    min_value: float | None
    max_value: float | None
    accepted_quantity: int
    rejected_quantity: int
    measurements: list[dict] = Field(default_factory=list)
    photo_notes: list[str] = Field(default_factory=list)
    observations: str | None
    inspected_at: datetime


class ProductionRunRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    status: str
    run_type: str
    started_at: datetime
    finished_at: datetime | None
    good_quantity: int
    rejected_quantity: int
    observations: str | None
    elapsed_seconds: int


class RouteStepRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    sequence: int
    process_name: str
    status: str
    machine: MachineRead
    runs: list[ProductionRunRead] = Field(default_factory=list)


class WarehouseIssueRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    work_order_id: UUID
    component_id: UUID | None
    item_name: str
    issue_type: str
    quantity: float
    unit: str
    unit_cost: float
    issued_at: datetime
    observations: str | None


class ComponentRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    work_order_id: UUID
    name: str
    drawing_code: str | None
    quantity_required: int
    quantity_completed: int
    status: str
    design_started_at: datetime | None
    design_finished_at: datetime | None
    design_seconds: int
    routes: list[RouteStepRead] = Field(default_factory=list)
    quality_inspections: list[QualityInspectionRead] = Field(default_factory=list)


class WorkOrderRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    code: str
    client_name: str
    description: str
    status: str
    priority: str
    due_date: datetime | None
    created_at: datetime
    approved_at: datetime | None
    components: list[ComponentRead] = Field(default_factory=list)
    warehouse_issues: list[WarehouseIssueRead] = Field(default_factory=list)
