"""sucursales, configuracion del sistema y razones de movimiento

- Catálogo `sucursal` y `configuracion_sistema` (una fila) con la sucursal
  predeterminada. Los datos existentes pasan a la "Sucursal principal".
- El stock deja de ser uno por producto: `inventario` lleva una fila por
  (producto, sucursal).
- `movimiento`, `venta` y `compra` quedan asociados a una sucursal.
- Catálogo `razon_movimiento` con las razones predefinidas y las del sistema;
  todo movimiento lleva razón (los anteriores reciben la que corresponde a su
  documento o "Registro previo").
"""

import sqlalchemy as sa
from alembic import op

revision = "20261111_01"
down_revision = "20261104_01"
branch_labels = None
depends_on = None


# (codigo, nombre, tipo, sistema, requiere_sucursal_destino). Copia fija: la
# migración no importa los modelos para no cambiar si estos cambian después.
RAZONES = [
    ("ingreso_proveedor", "Ingreso desde proveedor", "entrada", False, False),
    ("devolucion_sucursal", "Devolución de sucursal", "entrada", False, False),
    ("devolucion_cliente", "Devolución de cliente", "entrada", False, False),
    ("reposicion_falla", "Reposición por falla", "entrada", False, False),
    ("salida_sucursal", "Salida a sucursal", "salida", False, True),
    ("salida_falla", "Salida por falla", "salida", False, False),
    ("salida_cambio_cliente", "Salida por cambio a cliente", "salida", False, False),
    ("salida_tester", "Salida para tester", "salida", False, False),
    ("salida_extravio", "Salida por extravío", "salida", False, False),
    ("ajuste_desglose", "Ajuste por desglose", "ajuste", False, False),
    ("venta", "Venta", "salida", True, False),
    ("anulacion_venta", "Anulación de venta", "entrada", True, False),
    ("compra", "Compra", "entrada", True, False),
    ("stock_inicial", "Stock inicial", "entrada", True, False),
    ("deteccion_ia_entrada", "Detección IA", "entrada", True, False),
    ("deteccion_ia_salida", "Detección IA", "salida", True, False),
    ("traspaso_entrada", "Ingreso por traspaso", "entrada", True, False),
    ("historico_entrada", "Registro previo", "entrada", True, False),
    ("historico_salida", "Registro previo", "salida", True, False),
    ("historico_ajuste", "Registro previo", "ajuste", True, False),
]


def _existe_tabla(nombre: str) -> bool:
    # El arranque local ejecuta create_all y puede haber creado ya las tablas
    # nuevas (vacías) antes de correr esta migración.
    if op.get_context().as_sql:
        return False
    return sa.inspect(op.get_bind()).has_table(nombre)


def _sql_literal(valor) -> str:
    if isinstance(valor, bool):
        return "true" if valor else "false"
    return "'" + str(valor).replace("'", "''") + "'"


def _agregar_sucursal_obligatoria(tabla: str) -> None:
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


def upgrade() -> None:
    if not _existe_tabla("sucursal"):
        op.create_table(
            "sucursal",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("nombre", sa.String(100), nullable=False),
            sa.Column("direccion", sa.String(200)),
            sa.Column("telefono", sa.String(30)),
            sa.Column("activo", sa.Boolean(), nullable=False, server_default=sa.text("true")),
            sa.Column(
                "creado_en", sa.DateTime(timezone=True), nullable=False,
                server_default=sa.func.now(),
            ),
        )
        op.create_index("ix_sucursal_id", "sucursal", ["id"])
        op.create_index(
            "uq_sucursal_nombre_lower", "sucursal", [sa.text("lower(nombre)")], unique=True
        )

    if not _existe_tabla("configuracion_sistema"):
        op.create_table(
            "configuracion_sistema",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column(
                "sucursal_predeterminada_id", sa.Integer(),
                sa.ForeignKey("sucursal.id", ondelete="RESTRICT"), nullable=False,
            ),
            sa.Column(
                "actualizado_en", sa.DateTime(timezone=True), nullable=False,
                server_default=sa.func.now(),
            ),
            sa.CheckConstraint("id = 1", name="chk_configuracion_sistema_unica"),
        )

    if not _existe_tabla("razon_movimiento"):
        op.create_table(
            "razon_movimiento",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("codigo", sa.String(40), unique=True),
            sa.Column("nombre", sa.String(100), nullable=False),
            sa.Column("tipo_movimiento", sa.String(20), nullable=False),
            sa.Column("sistema", sa.Boolean(), nullable=False, server_default=sa.text("false")),
            sa.Column(
                "requiere_sucursal_destino", sa.Boolean(), nullable=False,
                server_default=sa.text("false"),
            ),
            sa.Column("activo", sa.Boolean(), nullable=False, server_default=sa.text("true")),
            sa.Column(
                "creado_en", sa.DateTime(timezone=True), nullable=False,
                server_default=sa.func.now(),
            ),
            sa.Column(
                "actualizado_en", sa.DateTime(timezone=True), nullable=False,
                server_default=sa.func.now(),
            ),
            sa.CheckConstraint(
                "tipo_movimiento IN ('entrada', 'salida', 'ajuste')",
                name="chk_razon_movimiento_tipo",
            ),
            sa.CheckConstraint(
                "NOT requiere_sucursal_destino OR tipo_movimiento = 'salida'",
                name="chk_razon_movimiento_destino_salida",
            ),
        )
        op.create_index("ix_razon_movimiento_id", "razon_movimiento", ["id"])
        op.create_index(
            "uq_razon_movimiento_nombre_tipo", "razon_movimiento",
            [sa.text("lower(nombre)"), "tipo_movimiento"], unique=True,
        )

    # Sucursal principal y configuración: todo lo existente pasa a ella.
    op.execute(
        "INSERT INTO sucursal (nombre) SELECT 'Sucursal principal' "
        "WHERE NOT EXISTS (SELECT 1 FROM sucursal)"
    )
    op.execute(
        "INSERT INTO configuracion_sistema (id, sucursal_predeterminada_id) "
        "SELECT 1, min(id) FROM sucursal ON CONFLICT (id) DO NOTHING"
    )

    valores = ",\n".join(
        "(" + ", ".join(_sql_literal(v) for v in fila) + ")" for fila in RAZONES
    )
    op.execute(
        "INSERT INTO razon_movimiento "
        "(codigo, nombre, tipo_movimiento, sistema, requiere_sucursal_destino) VALUES\n"
        f"{valores}\nON CONFLICT (codigo) DO NOTHING"
    )

    # Inventario: de una fila por producto a una por (producto, sucursal).
    if not op.get_context().as_sql:
        inspector = sa.inspect(op.get_bind())
        for unico in inspector.get_unique_constraints("inventario"):
            if unico["column_names"] == ["producto_id"]:
                op.drop_constraint(unico["name"], "inventario", type_="unique")
    else:
        op.drop_constraint("inventario_producto_id_key", "inventario", type_="unique")
    _agregar_sucursal_obligatoria("inventario")
    op.create_unique_constraint(
        "uq_inventario_producto_sucursal", "inventario", ["producto_id", "sucursal_id"]
    )

    # Movimiento: sucursal, razón y, en traspasos, la otra sucursal.
    _agregar_sucursal_obligatoria("movimiento")
    op.add_column("movimiento", sa.Column("razon_movimiento_id", sa.Integer()))
    op.add_column("movimiento", sa.Column("sucursal_relacionada_id", sa.Integer()))
    op.execute("""
        UPDATE movimiento m SET razon_movimiento_id = r.id
        FROM razon_movimiento r
        WHERE r.codigo = CASE
            WHEN m.venta_detalle_id IS NOT NULL AND m.tipo = 'salida' THEN 'venta'
            WHEN m.movimiento_revertido_id IS NOT NULL AND m.tipo = 'entrada' THEN 'anulacion_venta'
            WHEN m.compra_detalle_id IS NOT NULL THEN 'compra'
            WHEN m.origen = 'ia' AND m.tipo = 'entrada' THEN 'deteccion_ia_entrada'
            WHEN m.origen = 'ia' AND m.tipo = 'salida' THEN 'deteccion_ia_salida'
            ELSE 'historico_' || m.tipo
        END
    """)
    op.alter_column(
        "movimiento", "razon_movimiento_id", existing_type=sa.Integer(), nullable=False
    )
    op.create_foreign_key(
        "fk_movimiento_razon", "movimiento", "razon_movimiento",
        ["razon_movimiento_id"], ["id"], ondelete="RESTRICT",
    )
    op.create_foreign_key(
        "fk_movimiento_sucursal_relacionada", "movimiento", "sucursal",
        ["sucursal_relacionada_id"], ["id"], ondelete="RESTRICT",
    )
    op.create_check_constraint(
        "chk_movimiento_sucursal_relacionada", "movimiento",
        "sucursal_relacionada_id IS NULL OR sucursal_relacionada_id <> sucursal_id",
    )
    op.create_index("idx_movimiento_razon", "movimiento", ["razon_movimiento_id"])

    _agregar_sucursal_obligatoria("venta")
    _agregar_sucursal_obligatoria("compra")


def downgrade() -> None:
    bind = op.get_bind()
    sucursales = bind.execute(sa.text("SELECT count(*) FROM sucursal")).scalar_one()
    if sucursales > 1:
        raise RuntimeError(
            "No se puede revertir: hay más de una sucursal y el stock por "
            "sucursal no cabe en una sola fila por producto."
        )
    for tabla in ("compra", "venta"):
        op.drop_index(f"idx_{tabla}_sucursal", table_name=tabla)
        op.drop_constraint(f"fk_{tabla}_sucursal", tabla, type_="foreignkey")
        op.drop_column(tabla, "sucursal_id")

    op.drop_index("idx_movimiento_razon", table_name="movimiento")
    op.drop_constraint("chk_movimiento_sucursal_relacionada", "movimiento", type_="check")
    op.drop_constraint("fk_movimiento_sucursal_relacionada", "movimiento", type_="foreignkey")
    op.drop_constraint("fk_movimiento_razon", "movimiento", type_="foreignkey")
    op.drop_column("movimiento", "sucursal_relacionada_id")
    op.drop_column("movimiento", "razon_movimiento_id")
    op.drop_index("idx_movimiento_sucursal", table_name="movimiento")
    op.drop_constraint("fk_movimiento_sucursal", "movimiento", type_="foreignkey")
    op.drop_column("movimiento", "sucursal_id")

    op.drop_constraint("uq_inventario_producto_sucursal", "inventario", type_="unique")
    op.drop_index("idx_inventario_sucursal", table_name="inventario")
    op.drop_constraint("fk_inventario_sucursal", "inventario", type_="foreignkey")
    op.drop_column("inventario", "sucursal_id")
    op.create_unique_constraint("inventario_producto_id_key", "inventario", ["producto_id"])

    op.drop_table("razon_movimiento")
    op.drop_table("configuracion_sistema")
    op.drop_table("sucursal")
