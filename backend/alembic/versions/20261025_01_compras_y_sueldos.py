"""agrega compras, monedas y liquidaciones de sueldo

Revision ID: 20261025_01
Revises: 20261024_02
Create Date: 2026-10-25 02:50:00
"""

import sqlalchemy as sa
from alembic import op


revision = "20261025_01"
down_revision = "20261024_02"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("usuario", sa.Column("pago_por_hora", sa.Numeric(10, 2)))
    op.add_column("usuario", sa.Column("porcentaje_comision", sa.Numeric(5, 2)))
    op.create_check_constraint(
        "chk_usuario_pago_por_hora",
        "usuario",
        "pago_por_hora IS NULL OR pago_por_hora > 0",
    )
    op.create_check_constraint(
        "chk_usuario_porcentaje_comision",
        "usuario",
        "porcentaje_comision IS NULL OR porcentaje_comision BETWEEN 0 AND 100",
    )

    op.create_table(
        "moneda",
        sa.Column("codigo", sa.String(3), primary_key=True),
        sa.Column("nombre", sa.String(80), nullable=False),
        sa.Column("simbolo", sa.String(10)),
        sa.Column("pais", sa.String(80)),
        sa.Column(
            "decimales",
            sa.Integer(),
            nullable=False,
            server_default=sa.text("2"),
        ),
        sa.Column(
            "activa", sa.Boolean(), nullable=False, server_default=sa.text("true")
        ),
        sa.CheckConstraint(
            "decimales BETWEEN 0 AND 4", name="chk_moneda_decimales"
        ),
    )

    op.create_table(
        "compra",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("proveedor_id", sa.Integer(), nullable=False),
        sa.Column("usuario_id", sa.Integer(), nullable=False),
        sa.Column("moneda_codigo", sa.String(3), nullable=False),
        sa.Column("tipo_cambio_ext", sa.Numeric(18, 6), nullable=False),
        sa.Column("tipo_cambio_bob", sa.Numeric(18, 6), nullable=False),
        sa.Column("numero_factura", sa.String(100)),
        sa.Column("fecha_factura", sa.Date()),
        sa.Column("subtotal_moneda", sa.Numeric(18, 4), nullable=False),
        sa.Column(
            "descuento_moneda",
            sa.Numeric(18, 4),
            nullable=False,
            server_default=sa.text("0"),
        ),
        sa.Column("base_costo_adicional_moneda", sa.Numeric(18, 4), nullable=False),
        sa.Column(
            "porcentaje_manipulacion_envio",
            sa.Numeric(5, 2),
            nullable=False,
            server_default=sa.text("0"),
        ),
        sa.Column("costo_manipulacion_envio_moneda", sa.Numeric(18, 4), nullable=False),
        sa.Column("total_moneda", sa.Numeric(18, 4), nullable=False),
        sa.Column("total_bob", sa.Numeric(14, 2), nullable=False),
        sa.Column("imagen_factura_url", sa.Text()),
        sa.Column(
            "estado",
            sa.String(20),
            nullable=False,
            server_default=sa.text("'registrada'"),
        ),
        sa.Column(
            "fecha_creacion",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.ForeignKeyConstraint(["proveedor_id"], ["proveedor.id"]),
        sa.ForeignKeyConstraint(["usuario_id"], ["usuario.id"]),
        sa.ForeignKeyConstraint(["moneda_codigo"], ["moneda.codigo"]),
        sa.CheckConstraint("subtotal_moneda >= 0", name="chk_compra_subtotal"),
        sa.CheckConstraint("descuento_moneda >= 0", name="chk_compra_descuento"),
        sa.CheckConstraint(
            "descuento_moneda <= subtotal_moneda",
            name="chk_compra_descuento_no_supera_subtotal",
        ),
        sa.CheckConstraint(
            "base_costo_adicional_moneda >= 0",
            name="chk_compra_base_adicional",
        ),
        sa.CheckConstraint(
            "porcentaje_manipulacion_envio >= 0",
            name="chk_compra_porcentaje_manipulacion",
        ),
        sa.CheckConstraint(
            "costo_manipulacion_envio_moneda >= 0",
            name="chk_compra_costo_manipulacion",
        ),
        sa.CheckConstraint("total_moneda >= 0", name="chk_compra_total_moneda"),
        sa.CheckConstraint("total_bob >= 0", name="chk_compra_total_bob"),
        sa.CheckConstraint("tipo_cambio_ext > 0", name="chk_compra_tipo_cambio_ext"),
        sa.CheckConstraint("tipo_cambio_bob > 0", name="chk_compra_tipo_cambio_bob"),
        sa.CheckConstraint(
            "estado IN ('registrada', 'anulada')", name="chk_compra_estado"
        ),
    )
    op.create_index(
        "idx_compra_proveedor_fecha", "compra", ["proveedor_id", "fecha_creacion"]
    )
    op.create_index("idx_compra_fecha", "compra", ["fecha_creacion"])

    op.create_table(
        "compra_detalle",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("compra_id", sa.Integer(), nullable=False),
        sa.Column("producto_id", sa.Integer(), nullable=False),
        sa.Column("descripcion_factura", sa.String(250)),
        sa.Column("cantidad", sa.Integer(), nullable=False),
        sa.Column("costo_unitario_moneda", sa.Numeric(18, 6), nullable=False),
        sa.Column("subtotal_linea_moneda", sa.Numeric(18, 4), nullable=False),
        sa.Column("costo_unitario_final_bob", sa.Numeric(14, 4), nullable=False),
        sa.ForeignKeyConstraint(
            ["compra_id"], ["compra.id"], ondelete="RESTRICT"
        ),
        sa.ForeignKeyConstraint(
            ["producto_id"], ["producto.id"], ondelete="RESTRICT"
        ),
        sa.CheckConstraint("cantidad > 0", name="chk_compra_detalle_cantidad"),
        sa.CheckConstraint(
            "costo_unitario_moneda >= 0",
            name="chk_compra_detalle_costo_unitario",
        ),
        sa.CheckConstraint(
            "subtotal_linea_moneda >= 0",
            name="chk_compra_detalle_subtotal_linea",
        ),
        sa.CheckConstraint(
            "costo_unitario_final_bob >= 0",
            name="chk_compra_detalle_costo_final_bob",
        ),
        sa.UniqueConstraint("compra_id", "producto_id", name="uq_compra_producto"),
    )
    op.create_index(
        "idx_compra_detalle_producto", "compra_detalle", ["producto_id"]
    )

    op.add_column(
        "movimiento", sa.Column("compra_detalle_id", sa.Integer(), nullable=True)
    )
    op.create_foreign_key(
        "fk_movimiento_compra_detalle",
        "movimiento",
        "compra_detalle",
        ["compra_detalle_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_unique_constraint(
        "uq_movimiento_compra_detalle", "movimiento", ["compra_detalle_id"]
    )
    op.create_check_constraint(
        "chk_movimiento_un_solo_documento",
        "movimiento",
        "venta_detalle_id IS NULL OR compra_detalle_id IS NULL",
    )

    op.create_table(
        "registro_hora",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("usuario_id", sa.Integer(), nullable=False),
        sa.Column("fecha", sa.Date(), nullable=False),
        sa.Column("hora_entrada", sa.Time(), nullable=False),
        sa.Column("hora_salida", sa.Time()),
        sa.Column("confirmado_por_usuario_id", sa.Integer()),
        sa.Column("fecha_confirmacion", sa.DateTime(timezone=True)),
        sa.ForeignKeyConstraint(["usuario_id"], ["usuario.id"]),
        sa.ForeignKeyConstraint(["confirmado_por_usuario_id"], ["usuario.id"]),
        sa.CheckConstraint(
            "hora_salida IS NULL OR hora_salida > hora_entrada",
            name="chk_registro_hora_intervalo",
        ),
        sa.UniqueConstraint(
            "usuario_id", "fecha", name="uq_registro_hora_usuario_fecha"
        ),
    )
    op.create_index("idx_registro_hora_fecha", "registro_hora", ["fecha"])

    op.create_table(
        "liquidacion_sueldo",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("usuario_id", sa.Integer(), nullable=False),
        sa.Column("fecha_inicio", sa.Date(), nullable=False),
        sa.Column("fecha_fin", sa.Date(), nullable=False),
        sa.Column("horas_trabajadas", sa.Numeric(8, 2), nullable=False),
        sa.Column("pago_por_hora_aplicado", sa.Numeric(10, 2), nullable=False),
        sa.Column("porcentaje_comision_aplicado", sa.Numeric(5, 2), nullable=False),
        sa.Column("total_pago_horas", sa.Numeric(12, 2), nullable=False),
        sa.Column("total_comision", sa.Numeric(12, 2), nullable=False),
        sa.Column("total_pagado", sa.Numeric(12, 2), nullable=False),
        sa.Column(
            "estado",
            sa.String(20),
            nullable=False,
            server_default=sa.text("'pendiente'"),
        ),
        sa.Column("fecha_pago", sa.DateTime(timezone=True)),
        sa.Column(
            "creado_en",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.ForeignKeyConstraint(["usuario_id"], ["usuario.id"]),
        sa.CheckConstraint(
            "fecha_fin >= fecha_inicio", name="chk_liquidacion_periodo"
        ),
        sa.CheckConstraint(
            "horas_trabajadas >= 0",
            name="chk_liquidacion_horas_no_negativas",
        ),
        sa.CheckConstraint(
            "pago_por_hora_aplicado > 0",
            name="chk_liquidacion_tarifa_positiva",
        ),
        sa.CheckConstraint(
            "porcentaje_comision_aplicado BETWEEN 0 AND 100",
            name="chk_liquidacion_porcentaje_comision",
        ),
        sa.CheckConstraint("total_pago_horas >= 0", name="chk_liquidacion_pago_horas"),
        sa.CheckConstraint("total_comision >= 0", name="chk_liquidacion_comision"),
        sa.CheckConstraint("total_pagado >= 0", name="chk_liquidacion_total"),
        sa.CheckConstraint(
            "estado IN ('pendiente', 'pagado')", name="chk_liquidacion_estado"
        ),
        sa.UniqueConstraint(
            "usuario_id",
            "fecha_inicio",
            "fecha_fin",
            name="uq_liquidacion_usuario_periodo",
        ),
    )
    op.create_index(
        "idx_liquidacion_usuario_periodo",
        "liquidacion_sueldo",
        ["usuario_id", "fecha_inicio", "fecha_fin"],
    )


def downgrade() -> None:
    op.drop_index(
        "idx_liquidacion_usuario_periodo", table_name="liquidacion_sueldo"
    )
    op.drop_table("liquidacion_sueldo")
    op.drop_index("idx_registro_hora_fecha", table_name="registro_hora")
    op.drop_table("registro_hora")

    op.drop_constraint(
        "chk_movimiento_un_solo_documento", "movimiento", type_="check"
    )
    op.drop_constraint(
        "uq_movimiento_compra_detalle", "movimiento", type_="unique"
    )
    op.drop_constraint(
        "fk_movimiento_compra_detalle", "movimiento", type_="foreignkey"
    )
    op.drop_column("movimiento", "compra_detalle_id")

    op.drop_index("idx_compra_detalle_producto", table_name="compra_detalle")
    op.drop_table("compra_detalle")
    op.drop_index("idx_compra_fecha", table_name="compra")
    op.drop_index("idx_compra_proveedor_fecha", table_name="compra")
    op.drop_table("compra")
    op.drop_table("moneda")

    op.drop_constraint(
        "chk_usuario_porcentaje_comision", "usuario", type_="check"
    )
    op.drop_constraint("chk_usuario_pago_por_hora", "usuario", type_="check")
    op.drop_column("usuario", "porcentaje_comision")
    op.drop_column("usuario", "pago_por_hora")
