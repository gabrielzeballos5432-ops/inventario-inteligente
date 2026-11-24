"""caja y gastos por sucursal

Las sesiones de caja y los gastos existentes pasan a la sucursal
predeterminada. Desde aquí cada local tiene su caja, sus gastos y su reporte
de utilidad.
"""

import sqlalchemy as sa
from alembic import op

revision = "20261111_02"
down_revision = "20261111_01"
branch_labels = None
depends_on = None


TABLAS = ("sesion_caja", "gasto")


def upgrade() -> None:
    for tabla in TABLAS:
        op.add_column(tabla, sa.Column("sucursal_id", sa.Integer()))
        op.execute(
            f"UPDATE {tabla} SET sucursal_id = "
            "(SELECT sucursal_predeterminada_id FROM configuracion_sistema WHERE id = 1)"
        )
        op.alter_column(tabla, "sucursal_id", existing_type=sa.Integer(), nullable=False)
        op.create_foreign_key(
            f"fk_{tabla}_sucursal", tabla, "sucursal", ["sucursal_id"], ["id"],
            ondelete="RESTRICT",
        )
        op.create_index(f"idx_{tabla}_sucursal", tabla, ["sucursal_id"])


def downgrade() -> None:
    bind = op.get_bind()
    sucursales = bind.execute(sa.text("SELECT count(*) FROM sucursal")).scalar_one()
    if sucursales > 1:
        raise RuntimeError(
            "No se puede revertir: hay más de una sucursal y se perdería a qué "
            "local pertenece cada caja y cada gasto."
        )
    for tabla in TABLAS:
        op.drop_index(f"idx_{tabla}_sucursal", table_name=tabla)
        op.drop_constraint(f"fk_{tabla}_sucursal", tabla, type_="foreignkey")
        op.drop_column(tabla, "sucursal_id")
