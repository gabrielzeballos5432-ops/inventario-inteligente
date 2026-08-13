"""add product visual aliases

Revision ID: 20260401_01
Revises:
Create Date: 2026-04-01 19:30:00
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "20260401_01"
down_revision = "20260401_00"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)
    existing_tables = inspector.get_table_names()

    if "productos_alias_visuales" not in existing_tables:
        op.create_table(
            "productos_alias_visuales",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("producto_id", sa.Integer(), nullable=False),
            sa.Column("alias", sa.String(length=120), nullable=False),
            sa.Column("alias_normalizado", sa.String(length=120), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
            sa.ForeignKeyConstraint(["producto_id"], ["productos.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("alias_normalizado"),
        )

    existing_indexes = {index["name"] for index in inspector.get_indexes("productos_alias_visuales")}
    if op.f("ix_productos_alias_visuales_alias_normalizado") not in existing_indexes:
        op.create_index(
            op.f("ix_productos_alias_visuales_alias_normalizado"),
            "productos_alias_visuales",
            ["alias_normalizado"],
            unique=False,
        )
    if op.f("ix_productos_alias_visuales_id") not in existing_indexes:
        op.create_index(op.f("ix_productos_alias_visuales_id"), "productos_alias_visuales", ["id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_productos_alias_visuales_id"), table_name="productos_alias_visuales")
    op.drop_index(op.f("ix_productos_alias_visuales_alias_normalizado"), table_name="productos_alias_visuales")
    op.drop_table("productos_alias_visuales")
