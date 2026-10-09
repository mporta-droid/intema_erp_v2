"""flujo inicial mes oit diseno produccion almacen

Revision ID: 202608110001
Revises: 202608100001
Create Date: 2026-08-11 09:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "202608110001"
down_revision: str | None = "202608100001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "work_orders",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("code", sa.String(length=40), nullable=False),
        sa.Column("client_name", sa.String(length=180), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("status", sa.String(length=40), nullable=False),
        sa.Column("priority", sa.String(length=30), nullable=False),
        sa.Column("created_by_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("approved_by_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("approved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("due_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["approved_by_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["created_by_id"], ["users.id"], ondelete="SET NULL"),
        sa.UniqueConstraint("code", name="uq_work_orders_code"),
    )
    op.create_index("ix_work_orders_status", "work_orders", ["status"])

    op.create_table(
        "machines",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("process_name", sa.String(length=120), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("name", name="uq_machines_name"),
    )

    op.create_table(
        "work_order_components",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("work_order_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("name", sa.String(length=180), nullable=False),
        sa.Column("drawing_code", sa.String(length=80), nullable=True),
        sa.Column("quantity_required", sa.Integer(), nullable=False),
        sa.Column("quantity_completed", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("status", sa.String(length=40), nullable=False),
        sa.Column("design_started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("design_finished_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("design_seconds", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("designer_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["designer_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["work_order_id"], ["work_orders.id"], ondelete="CASCADE"),
    )
    op.create_index("ix_work_order_components_work_order_id", "work_order_components", ["work_order_id"])
    op.create_index("ix_work_order_components_status", "work_order_components", ["status"])

    op.create_table(
        "production_route_steps",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("component_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("sequence", sa.Integer(), nullable=False),
        sa.Column("machine_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("process_name", sa.String(length=120), nullable=False),
        sa.Column("status", sa.String(length=40), nullable=False),
        sa.Column("planned_by_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["component_id"], ["work_order_components.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["machine_id"], ["machines.id"]),
        sa.ForeignKeyConstraint(["planned_by_id"], ["users.id"], ondelete="SET NULL"),
    )
    op.create_index("ix_production_route_steps_component_id", "production_route_steps", ["component_id"])
    op.create_index("ix_production_route_steps_status", "production_route_steps", ["status"])

    op.create_table(
        "warehouse_issues",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("work_order_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("component_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("item_name", sa.String(length=180), nullable=False),
        sa.Column("issue_type", sa.String(length=40), nullable=False),
        sa.Column("quantity", sa.Numeric(12, 3), nullable=False),
        sa.Column("unit", sa.String(length=30), nullable=False),
        sa.Column("unit_cost", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("issued_by_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("issued_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("observations", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["component_id"], ["work_order_components.id"]),
        sa.ForeignKeyConstraint(["issued_by_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["work_order_id"], ["work_orders.id"]),
    )
    op.create_index("ix_warehouse_issues_work_order_id", "warehouse_issues", ["work_order_id"])
    op.create_index("ix_warehouse_issues_component_id", "warehouse_issues", ["component_id"])

    op.create_table(
        "production_runs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("route_step_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("operator_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("status", sa.String(length=40), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("finished_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("good_quantity", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("rejected_quantity", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("observations", sa.Text(), nullable=True),
        sa.Column("elapsed_seconds", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["operator_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["route_step_id"], ["production_route_steps.id"], ondelete="CASCADE"),
    )
    op.create_index("ix_production_runs_route_step_id", "production_runs", ["route_step_id"])


def downgrade() -> None:
    op.drop_index("ix_production_runs_route_step_id", table_name="production_runs")
    op.drop_table("production_runs")
    op.drop_index("ix_warehouse_issues_component_id", table_name="warehouse_issues")
    op.drop_index("ix_warehouse_issues_work_order_id", table_name="warehouse_issues")
    op.drop_table("warehouse_issues")
    op.drop_index("ix_production_route_steps_status", table_name="production_route_steps")
    op.drop_index("ix_production_route_steps_component_id", table_name="production_route_steps")
    op.drop_table("production_route_steps")
    op.drop_index("ix_work_order_components_status", table_name="work_order_components")
    op.drop_index("ix_work_order_components_work_order_id", table_name="work_order_components")
    op.drop_table("work_order_components")
    op.drop_table("machines")
    op.drop_index("ix_work_orders_status", table_name="work_orders")
    op.drop_table("work_orders")
