"""quality inspections

Revision ID: 202608120002
Revises: 202608120001
Create Date: 2026-08-12 00:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "202608120002"
down_revision: str | None = "202608120001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "quality_inspections",
        sa.Column("component_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("inspector_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("drawing_code", sa.String(length=80), nullable=True),
        sa.Column("instrument", sa.String(length=120), nullable=True),
        sa.Column("nominal_value", sa.Numeric(12, 4), nullable=True),
        sa.Column("min_value", sa.Numeric(12, 4), nullable=True),
        sa.Column("max_value", sa.Numeric(12, 4), nullable=True),
        sa.Column("accepted_quantity", sa.Integer(), nullable=False),
        sa.Column("rejected_quantity", sa.Integer(), nullable=False),
        sa.Column("measurements", sa.JSON(), nullable=False),
        sa.Column("photo_notes", sa.JSON(), nullable=False),
        sa.Column("observations", sa.Text(), nullable=True),
        sa.Column("inspected_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["component_id"], ["work_order_components.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["inspector_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_quality_inspections_component_id"),
        "quality_inspections",
        ["component_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_quality_inspections_component_id"), table_name="quality_inspections")
    op.drop_table("quality_inspections")
