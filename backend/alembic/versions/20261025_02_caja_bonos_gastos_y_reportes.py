"""completa caja, bonos, gastos, costos historicos y anulacion de ventas

Revision ID: 20261025_02
Revises: 20261025_01
Create Date: 2026-10-25 23:40:00
"""

import sqlalchemy as sa
from alembic import op


revision = "20261025_02"
down_revision = "20261025_01"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "cliente",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("nombre", sa.String(150), nullable=False),
        sa.Column("telefono", sa.String(30)),
        sa.Column("email", sa.String(150)),
        sa.Column(
            "creado_en",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.Column("activo", sa.Boolean(), nullable=False, server_default=sa.text("true")),
    )
    op.create_index(
        "uq_cliente_email_lower",
        "cliente",
        [sa.text("lower(email)")],
        unique=True,
    )

    op.create_table(
        "sesion_caja",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("usuario_apertura_id", sa.Integer(), nullable=False),
        sa.Column("usuario_cierre_id", sa.Integer()),
        sa.Column(
            "fecha_apertura",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.Column("fecha_cierre", sa.DateTime(timezone=True)),
        sa.Column("monto_inicial", sa.Numeric(12, 2), nullable=False),
        sa.Column("monto_esperado_cierre", sa.Numeric(12, 2)),
        sa.Column("monto_efectivo_contado", sa.Numeric(12, 2)),
        sa.Column("observacion_cierre", sa.String(250)),
        sa.Column(
            "estado",
            sa.String(20),
            nullable=False,
            server_default=sa.text("'abierta'"),
        ),
        sa.ForeignKeyConstraint(["usuario_apertura_id"], ["usuario.id"]),
        sa.ForeignKeyConstraint(["usuario_cierre_id"], ["usuario.id"]),
        sa.CheckConstraint("monto_inicial >= 0", name="chk_sesion_caja_monto_inicial"),
        sa.CheckConstraint(
            "monto_esperado_cierre IS NULL OR monto_esperado_cierre >= 0",
            name="chk_sesion_caja_monto_esperado",
        ),
        sa.CheckConstraint(
            "monto_efectivo_contado IS NULL OR monto_efectivo_contado >= 0",
            name="chk_sesion_caja_monto_contado",
        ),
        sa.CheckConstraint(
            "fecha_cierre IS NULL OR fecha_cierre >= fecha_apertura",
            name="chk_sesion_caja_fechas",
        ),
        sa.CheckConstraint(
            "estado IN ('abierta', 'cerrada')", name="chk_sesion_caja_estado"
        ),
    )
    op.create_index(
        "uq_sesion_caja_usuario_abierta",
        "sesion_caja",
        ["usuario_apertura_id"],
        unique=True,
        postgresql_where=sa.text("estado = 'abierta'"),
    )
    op.create_index("idx_sesion_caja_fecha", "sesion_caja", ["fecha_apertura"])

    op.add_column("venta", sa.Column("cliente_id", sa.Integer()))
    op.add_column("venta", sa.Column("sesion_caja_id", sa.Integer()))
    op.add_column("venta", sa.Column("clave_idempotencia", sa.String(100)))
    op.add_column("venta", sa.Column("huella_solicitud", sa.String(64)))
    op.add_column(
        "venta",
        sa.Column(
            "tipo_venta",
            sa.String(20),
            nullable=False,
            server_default=sa.text("'minorista'"),
        ),
    )
    op.add_column("venta", sa.Column("anulada_en", sa.DateTime(timezone=True)))
    op.add_column("venta", sa.Column("anulada_por_usuario_id", sa.Integer()))
    op.add_column("venta", sa.Column("motivo_anulacion", sa.String(250)))
    op.create_foreign_key(
        "fk_venta_cliente", "venta", "cliente", ["cliente_id"], ["id"]
    )
    op.create_foreign_key(
        "fk_venta_sesion_caja",
        "venta",
        "sesion_caja",
        ["sesion_caja_id"],
        ["id"],
    )
    op.create_foreign_key(
        "fk_venta_anulada_por_usuario",
        "venta",
        "usuario",
        ["anulada_por_usuario_id"],
        ["id"],
    )
    op.create_check_constraint(
        "chk_venta_tipo", "venta", "tipo_venta IN ('minorista', 'mayorista')"
    )
    op.create_index(
        "uq_venta_clave_idempotencia",
        "venta",
        ["usuario_id", "clave_idempotencia"],
        unique=True,
        postgresql_where=sa.text("clave_idempotencia IS NOT NULL"),
    )
    op.create_index("idx_venta_cliente", "venta", ["cliente_id"])
    op.create_index("idx_venta_sesion_caja", "venta", ["sesion_caja_id"])

    op.add_column(
        "venta_detalle", sa.Column("costo_unitario_bob_aplicado", sa.Numeric(14, 4))
    )
    op.add_column(
        "venta_detalle", sa.Column("costo_total_bob_aplicado", sa.Numeric(14, 2))
    )
    op.create_check_constraint(
        "chk_venta_detalle_costo_unitario",
        "venta_detalle",
        "costo_unitario_bob_aplicado IS NULL OR costo_unitario_bob_aplicado >= 0",
    )
    op.create_check_constraint(
        "chk_venta_detalle_costo_total",
        "venta_detalle",
        "costo_total_bob_aplicado IS NULL OR costo_total_bob_aplicado >= 0",
    )

    op.add_column("pago_venta", sa.Column("sesion_caja_id", sa.Integer()))
    op.create_foreign_key(
        "fk_pago_venta_sesion_caja",
        "pago_venta",
        "sesion_caja",
        ["sesion_caja_id"],
        ["id"],
    )
    op.create_index("idx_pago_venta_sesion_caja", "pago_venta", ["sesion_caja_id"])

    op.add_column(
        "liquidacion_sueldo",
        sa.Column(
            "total_bonos",
            sa.Numeric(12, 2),
            nullable=False,
            server_default=sa.text("0"),
        ),
    )
    op.create_check_constraint(
        "chk_liquidacion_bonos", "liquidacion_sueldo", "total_bonos >= 0"
    )
    op.create_table(
        "bono_sueldo",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("usuario_id", sa.Integer(), nullable=False),
        sa.Column("liquidacion_sueldo_id", sa.Integer()),
        sa.Column("tipo_bono", sa.String(20), nullable=False),
        sa.Column("descripcion", sa.String(250)),
        sa.Column("monto", sa.Numeric(12, 2), nullable=False),
        sa.Column(
            "fecha_registro",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.ForeignKeyConstraint(["usuario_id"], ["usuario.id"]),
        sa.ForeignKeyConstraint(
            ["liquidacion_sueldo_id"],
            ["liquidacion_sueldo.id"],
            ondelete="RESTRICT",
        ),
        sa.CheckConstraint(
            "tipo_bono IN ('live', 'almuerzo', 'navidad', 'otro')",
            name="chk_bono_sueldo_tipo",
        ),
        sa.CheckConstraint("monto > 0", name="chk_bono_sueldo_monto"),
    )
    op.create_index(
        "idx_bono_sueldo_usuario_fecha",
        "bono_sueldo",
        ["usuario_id", "fecha_registro"],
    )

    op.create_table(
        "gasto",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("categoria", sa.String(30), nullable=False),
        sa.Column("concepto", sa.String(200), nullable=False),
        sa.Column("proveedor_id", sa.Integer()),
        sa.Column("usuario_id", sa.Integer(), nullable=False),
        sa.Column("fecha_documento", sa.Date()),
        sa.Column("periodo_desde", sa.Date()),
        sa.Column("periodo_hasta", sa.Date()),
        sa.Column("numero_documento", sa.String(100)),
        sa.Column("moneda_codigo", sa.String(3), nullable=False),
        sa.Column("monto", sa.Numeric(18, 4), nullable=False),
        sa.Column("tipo_cambio_ext", sa.Numeric(18, 6), nullable=False),
        sa.Column("tipo_cambio_bob", sa.Numeric(18, 6), nullable=False),
        sa.Column("monto_bob", sa.Numeric(14, 2), nullable=False),
        sa.Column("soporte_url", sa.Text()),
        sa.Column("anulado_en", sa.DateTime(timezone=True)),
        sa.Column("anulada_por_usuario_id", sa.Integer()),
        sa.Column("motivo_anulacion", sa.String(250)),
        sa.Column(
            "estado",
            sa.String(20),
            nullable=False,
            server_default=sa.text("'pendiente'"),
        ),
        sa.Column(
            "fecha_creacion",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.ForeignKeyConstraint(["proveedor_id"], ["proveedor.id"]),
        sa.ForeignKeyConstraint(["usuario_id"], ["usuario.id"]),
        sa.ForeignKeyConstraint(["anulada_por_usuario_id"], ["usuario.id"]),
        sa.ForeignKeyConstraint(["moneda_codigo"], ["moneda.codigo"]),
        sa.CheckConstraint(
            "categoria IN ('servicio', 'alquiler', 'insumo_limpieza', "
            "'mantenimiento', 'otro')",
            name="chk_gasto_categoria",
        ),
        sa.CheckConstraint("monto > 0", name="chk_gasto_monto"),
        sa.CheckConstraint("monto_bob > 0", name="chk_gasto_monto_bob"),
        sa.CheckConstraint("tipo_cambio_ext > 0", name="chk_gasto_tipo_cambio_ext"),
        sa.CheckConstraint("tipo_cambio_bob > 0", name="chk_gasto_tipo_cambio_bob"),
        sa.CheckConstraint(
            "periodo_hasta IS NULL OR periodo_desde IS NULL "
            "OR periodo_hasta >= periodo_desde",
            name="chk_gasto_periodo",
        ),
        sa.CheckConstraint(
            "estado IN ('pendiente', 'pagado', 'anulado')",
            name="chk_gasto_estado",
        ),
    )
    op.create_index(
        "idx_gasto_periodo_categoria", "gasto", ["periodo_desde", "categoria"]
    )
    op.create_index("idx_gasto_proveedor", "gasto", ["proveedor_id"])

    op.create_table(
        "pago_gasto",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("gasto_id", sa.Integer(), nullable=False),
        sa.Column("sesion_caja_id", sa.Integer()),
        sa.Column(
            "fecha_pago",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.Column("monto", sa.Numeric(18, 4), nullable=False),
        sa.Column("monto_bob", sa.Numeric(14, 2), nullable=False),
        sa.Column("metodo_pago", sa.String(30), nullable=False),
        sa.Column("referencia", sa.String(150)),
        sa.ForeignKeyConstraint(["gasto_id"], ["gasto.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["sesion_caja_id"], ["sesion_caja.id"]),
        sa.CheckConstraint("monto > 0", name="chk_pago_gasto_monto"),
        sa.CheckConstraint("monto_bob > 0", name="chk_pago_gasto_monto_bob"),
        sa.CheckConstraint(
            "metodo_pago IN ('efectivo', 'transferencia', 'qr', 'otro')",
            name="chk_pago_gasto_metodo",
        ),
    )
    op.create_index(
        "idx_pago_gasto_gasto_fecha", "pago_gasto", ["gasto_id", "fecha_pago"]
    )
    op.create_index("idx_pago_gasto_sesion", "pago_gasto", ["sesion_caja_id"])

    op.add_column("movimiento", sa.Column("movimiento_revertido_id", sa.Integer()))
    op.create_foreign_key(
        "fk_movimiento_revertido",
        "movimiento",
        "movimiento",
        ["movimiento_revertido_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_check_constraint(
        "chk_movimiento_reversion_tipo",
        "movimiento",
        "movimiento_revertido_id IS NULL OR tipo IN ('entrada', 'salida')",
    )


def downgrade() -> None:
    op.drop_constraint(
        "chk_movimiento_reversion_tipo", "movimiento", type_="check"
    )
    op.drop_constraint(
        "fk_movimiento_revertido", "movimiento", type_="foreignkey"
    )
    op.drop_column("movimiento", "movimiento_revertido_id")
    op.drop_index("idx_pago_gasto_sesion", table_name="pago_gasto")
    op.drop_index("idx_pago_gasto_gasto_fecha", table_name="pago_gasto")
    op.drop_table("pago_gasto")
    op.drop_index("idx_gasto_proveedor", table_name="gasto")
    op.drop_index("idx_gasto_periodo_categoria", table_name="gasto")
    op.drop_table("gasto")
    op.drop_index("idx_bono_sueldo_usuario_fecha", table_name="bono_sueldo")
    op.drop_table("bono_sueldo")
    op.drop_constraint("chk_liquidacion_bonos", "liquidacion_sueldo", type_="check")
    op.drop_column("liquidacion_sueldo", "total_bonos")

    op.drop_index("idx_pago_venta_sesion_caja", table_name="pago_venta")
    op.drop_constraint(
        "fk_pago_venta_sesion_caja", "pago_venta", type_="foreignkey"
    )
    op.drop_column("pago_venta", "sesion_caja_id")
    op.drop_constraint(
        "chk_venta_detalle_costo_total", "venta_detalle", type_="check"
    )
    op.drop_constraint(
        "chk_venta_detalle_costo_unitario", "venta_detalle", type_="check"
    )
    op.drop_column("venta_detalle", "costo_total_bob_aplicado")
    op.drop_column("venta_detalle", "costo_unitario_bob_aplicado")

    op.drop_index("idx_venta_cliente", table_name="venta")
    op.drop_index("idx_venta_sesion_caja", table_name="venta")
    op.drop_index("uq_venta_clave_idempotencia", table_name="venta")
    op.drop_constraint("chk_venta_tipo", "venta", type_="check")
    op.drop_constraint("fk_venta_anulada_por_usuario", "venta", type_="foreignkey")
    op.drop_constraint("fk_venta_sesion_caja", "venta", type_="foreignkey")
    op.drop_constraint("fk_venta_cliente", "venta", type_="foreignkey")
    for columna in (
        "motivo_anulacion",
        "anulada_por_usuario_id",
        "anulada_en",
        "tipo_venta",
        "huella_solicitud",
        "clave_idempotencia",
        "sesion_caja_id",
        "cliente_id",
    ):
        op.drop_column("venta", columna)

    op.drop_index("idx_sesion_caja_fecha", table_name="sesion_caja")
    op.drop_index("uq_sesion_caja_usuario_abierta", table_name="sesion_caja")
    op.drop_table("sesion_caja")
    op.drop_index("uq_cliente_email_lower", table_name="cliente")
    op.drop_table("cliente")
