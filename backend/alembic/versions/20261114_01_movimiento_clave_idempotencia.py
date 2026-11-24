"""clave de idempotencia en los movimientos por lote

La app guarda los movimientos hechos sin conexion y los envia al volver el
servidor. Si la respuesta se pierde y reenvia el mismo lote, la clave permite
reconocerlo y no registrarlo dos veces.
"""

import sqlalchemy as sa
from alembic import op

revision = "20261114_01"
down_revision = "20261111_02"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    columnas = {c["name"] for c in sa.inspect(bind).get_columns("movimiento")}
    if "clave_idempotencia" not in columnas:
        op.add_column("movimiento", sa.Column("clave_idempotencia", sa.String(100)))
    # create_all (al arrancar el backend) puede haber creado ya el indice.
    op.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS uq_movimiento_clave_idempotencia "
        "ON movimiento(usuario_id, clave_idempotencia, producto_id) "
        "WHERE clave_idempotencia IS NOT NULL"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS uq_movimiento_clave_idempotencia")
    op.drop_column("movimiento", "clave_idempotencia")
