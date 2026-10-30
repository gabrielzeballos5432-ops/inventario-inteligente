"""agrega precio al por mayor al producto

Revision ID: 20261028_01
Revises: 20261025_02
Create Date: 2026-10-28 23:10:00
"""

import sqlalchemy as sa
from alembic import op


revision = "20261028_01"
down_revision = "20261025_02"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("producto", sa.Column("precio_mayor", sa.Numeric(10, 2)))
    op.create_check_constraint(
        "chk_precio_mayor_positivo",
        "producto",
        "precio_mayor IS NULL OR precio_mayor > 0",
    )


def downgrade() -> None:
    op.drop_constraint("chk_precio_mayor_positivo", "producto", type_="check")
    op.drop_column("producto", "precio_mayor")
