"""agrega ventas, detalles, pagos y su relacion con el inventario

Revision ID: 20261024_02
Revises: 20261024_01
Create Date: 2026-10-24 23:00:00
"""

import sqlalchemy as sa
from alembic import op


revision = "20261024_02"
down_revision = "20261024_01"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "venta",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "fecha_creacion",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.Column("usuario_id", sa.Integer(), nullable=False),
        sa.Column("total", sa.Numeric(12, 2), nullable=False),
        sa.Column(
            "estado",
            sa.String(length=20),
            nullable=False,
            server_default=sa.text("'completada'"),
        ),
        sa.ForeignKeyConstraint(["usuario_id"], ["usuario.id"]),
        sa.CheckConstraint("total >= 0", name="chk_venta_total_no_negativo"),
        sa.CheckConstraint(
            "estado IN ('completada', 'anulada')", name="chk_venta_estado"
        ),
    )
    op.create_index("idx_venta_usuario", "venta", ["usuario_id"])
    op.create_index("idx_venta_fecha", "venta", ["fecha_creacion"])

    op.create_table(
        "venta_detalle",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("venta_id", sa.Integer(), nullable=False),
        sa.Column("producto_id", sa.Integer(), nullable=False),
        sa.Column("producto_nombre", sa.String(length=200), nullable=False),
        sa.Column("producto_sku", sa.String(length=50), nullable=True),
        sa.Column("cantidad", sa.Integer(), nullable=False),
        sa.Column("precio_lista_unitario", sa.Numeric(10, 2), nullable=False),
        sa.Column("precio_unitario_negociado", sa.Numeric(10, 2), nullable=False),
        sa.Column("total_linea", sa.Numeric(12, 2), nullable=False),
        sa.Column("tipo_promocion", sa.String(length=20), nullable=True),
        sa.Column("observacion_promocion", sa.String(length=200), nullable=True),
        sa.ForeignKeyConstraint(["venta_id"], ["venta.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(
            ["producto_id"], ["producto.id"], ondelete="RESTRICT"
        ),
        sa.CheckConstraint(
            "cantidad > 0", name="chk_venta_detalle_cantidad_positiva"
        ),
        sa.CheckConstraint(
            "precio_lista_unitario >= 0",
            name="chk_venta_detalle_precio_lista_no_negativo",
        ),
        sa.CheckConstraint(
            "precio_unitario_negociado >= 0",
            name="chk_venta_detalle_precio_negociado_no_negativo",
        ),
        sa.CheckConstraint(
            "total_linea >= 0", name="chk_venta_detalle_total_no_negativo"
        ),
        sa.CheckConstraint(
            "tipo_promocion IS NULL OR tipo_promocion IN "
            "('oferta', 'combo', 'liquidacion')",
            name="chk_venta_detalle_tipo_promocion",
        ),
    )
    op.create_index("idx_venta_detalle_venta", "venta_detalle", ["venta_id"])
    op.create_index(
        "idx_venta_detalle_producto", "venta_detalle", ["producto_id"]
    )

    op.create_table(
        "pago_venta",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("venta_id", sa.Integer(), nullable=False),
        sa.Column(
            "fecha_creacion",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.Column("metodo_pago", sa.String(length=20), nullable=False),
        sa.Column("monto", sa.Numeric(12, 2), nullable=False),
        sa.Column(
            "estado",
            sa.String(length=20),
            nullable=False,
            server_default=sa.text("'confirmado'"),
        ),
        sa.Column("referencia", sa.String(length=100), nullable=True),
        sa.ForeignKeyConstraint(["venta_id"], ["venta.id"], ondelete="RESTRICT"),
        sa.CheckConstraint("monto > 0", name="chk_pago_venta_monto_positivo"),
        sa.CheckConstraint(
            "metodo_pago IN ('efectivo', 'qr')", name="chk_pago_venta_metodo"
        ),
        sa.CheckConstraint(
            "estado IN ('confirmado', 'anulado')", name="chk_pago_venta_estado"
        ),
    )
    op.create_index("idx_pago_venta_venta", "pago_venta", ["venta_id"])

    op.add_column(
        "movimiento", sa.Column("venta_detalle_id", sa.Integer(), nullable=True)
    )
    op.create_foreign_key(
        "fk_movimiento_venta_detalle",
        "movimiento",
        "venta_detalle",
        ["venta_detalle_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_unique_constraint(
        "uq_movimiento_venta_detalle", "movimiento", ["venta_detalle_id"]
    )


def downgrade() -> None:
    op.drop_constraint("uq_movimiento_venta_detalle", "movimiento", type_="unique")
    op.drop_constraint(
        "fk_movimiento_venta_detalle", "movimiento", type_="foreignkey"
    )
    op.drop_column("movimiento", "venta_detalle_id")

    op.drop_index("idx_pago_venta_venta", table_name="pago_venta")
    op.drop_table("pago_venta")
    op.drop_index("idx_venta_detalle_producto", table_name="venta_detalle")
    op.drop_index("idx_venta_detalle_venta", table_name="venta_detalle")
    op.drop_table("venta_detalle")
    op.drop_index("idx_venta_fecha", table_name="venta")
    op.drop_index("idx_venta_usuario", table_name="venta")
    op.drop_table("venta")
