"""production setup runs

Revision ID: 202608120001
Revises: 202608110001
Create Date: 2026-08-12 00:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "202608120001"
down_revision: str | None = "202608110001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "production_runs",
        sa.Column("run_type", sa.String(length=40), nullable=False, server_default="machining"),
    )
    op.create_index("ix_production_runs_run_type", "production_runs", ["run_type"])


def downgrade() -> None:
    op.drop_index("ix_production_runs_run_type", table_name="production_runs")
    op.drop_column("production_runs", "run_type")
