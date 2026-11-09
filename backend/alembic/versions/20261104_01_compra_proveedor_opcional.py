"""permite registrar compras sin proveedor"""

import sqlalchemy as sa
from alembic import op

revision = "20261104_01"
down_revision = "20261101_01"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column(
        "compra",
        "proveedor_id",
        existing_type=sa.Integer(),
        nullable=True,
    )


def downgrade() -> None:
    bind = op.get_bind()
    compras_sin_proveedor = bind.execute(
        sa.text("SELECT count(*) FROM compra WHERE proveedor_id IS NULL")
    ).scalar_one()
    if compras_sin_proveedor:
        raise RuntimeError(
            "No se puede revertir: hay compras registradas sin proveedor."
        )
    op.alter_column(
        "compra",
        "proveedor_id",
        existing_type=sa.Integer(),
        nullable=False,
    )
