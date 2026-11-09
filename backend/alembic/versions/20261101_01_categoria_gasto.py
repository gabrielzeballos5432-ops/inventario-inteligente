"""agrega catalogo de categorias de gasto sin borrar el historial"""

import sqlalchemy as sa
from alembic import op

revision = "20261101_01"
down_revision = "20261028_01"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # El arranque local usa create_all y puede haber creado solo la tabla nueva.
    if op.get_context().as_sql or not sa.inspect(op.get_bind()).has_table("categoria_gasto"):
        op.create_table(
            "categoria_gasto",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("nombre", sa.String(100), nullable=False),
            sa.Column("periodicidad", sa.String(20), nullable=False, server_default="sin_periodicidad"),
            sa.Column("tipo_importe", sa.String(10), nullable=False, server_default="variable"),
            sa.Column("monto_habitual", sa.Numeric(14, 2)),
            sa.Column("activo", sa.Boolean(), nullable=False, server_default=sa.text("true")),
            sa.CheckConstraint(
                "periodicidad IN ('sin_periodicidad', 'mensual', 'semanal', 'anual')",
                name="chk_categoria_gasto_periodicidad",
            ),
            sa.CheckConstraint("tipo_importe IN ('fijo', 'variable')", name="chk_categoria_gasto_tipo_importe"),
            sa.CheckConstraint(
                "monto_habitual IS NULL OR (monto_habitual > 0 AND tipo_importe = 'fijo')",
                name="chk_categoria_gasto_monto",
            ),
        )
        op.create_index("uq_categoria_gasto_nombre_lower", "categoria_gasto", [sa.text("lower(nombre)")], unique=True)
    op.drop_constraint("chk_gasto_categoria", "gasto", type_="check")
    op.alter_column("gasto", "categoria", type_=sa.String(100), existing_type=sa.String(30))
    op.add_column("gasto", sa.Column("categoria_gasto_id", sa.Integer()))
    op.create_foreign_key("fk_gasto_categoria_gasto", "gasto", "categoria_gasto", ["categoria_gasto_id"], ["id"], ondelete="RESTRICT")
    op.create_index("idx_gasto_categoria_gasto", "gasto", ["categoria_gasto_id"])
    op.execute("""
        INSERT INTO categoria_gasto (nombre, periodicidad, tipo_importe) VALUES
        ('Luz', 'mensual', 'variable'), ('Agua', 'mensual', 'fijo'),
        ('Wifi', 'mensual', 'fijo'), ('Alquiler', 'mensual', 'fijo'),
        ('Scotch', 'sin_periodicidad', 'variable'),
        ('Papel para tickets', 'sin_periodicidad', 'variable'),
        ('Etiquetas', 'sin_periodicidad', 'variable') ON CONFLICT DO NOTHING;
    """)
    op.execute("""
        INSERT INTO categoria_gasto (nombre, periodicidad, tipo_importe)
        SELECT DISTINCT categoria, 'sin_periodicidad', 'variable'
        FROM gasto
        WHERE NOT EXISTS (
            SELECT 1 FROM categoria_gasto c WHERE lower(c.nombre) = lower(gasto.categoria)
        );
    """)
    op.execute("""
        UPDATE gasto SET categoria_gasto_id = c.id
        FROM categoria_gasto c WHERE lower(gasto.categoria) = lower(c.nombre);
    """)


def downgrade() -> None:
    # Las categorias nuevas no caben en el enum anterior: no perder datos.
    bind = op.get_bind()
    nuevos = bind.execute(sa.text("""
        SELECT count(*) FROM gasto
        WHERE categoria NOT IN ('servicio', 'alquiler', 'insumo_limpieza', 'mantenimiento', 'otro')
    """)).scalar_one()
    if nuevos:
        raise RuntimeError("No se puede revertir: hay gastos con categorías del nuevo catálogo.")
    op.drop_index("idx_gasto_categoria_gasto", table_name="gasto")
    op.drop_constraint("fk_gasto_categoria_gasto", "gasto", type_="foreignkey")
    op.drop_column("gasto", "categoria_gasto_id")
    op.alter_column("gasto", "categoria", type_=sa.String(30), existing_type=sa.String(100))
    op.create_check_constraint("chk_gasto_categoria", "gasto",
        "categoria IN ('servicio', 'alquiler', 'insumo_limpieza', 'mantenimiento', 'otro')")
    op.drop_table("categoria_gasto")
