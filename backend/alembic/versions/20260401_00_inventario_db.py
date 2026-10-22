"""esquema inicial inventario_db (Salon de Belleza Zoom)

Revision ID: 20260401_00
Revises:
Create Date: 2026-04-01 21:00:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260401_00"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "roles",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("nombre", sa.String(length=50), nullable=False, unique=True),
        sa.Column("descripcion", sa.Text(), nullable=True),
    )

    op.create_table(
        "marcas",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("nombre", sa.String(length=100), nullable=False, unique=True),
        sa.Column("activo", sa.Boolean(), nullable=False, server_default=sa.text("true")),
    )

    op.create_table(
        "proveedores",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("nombre", sa.String(length=150), nullable=False),
        sa.Column("contacto", sa.String(length=100), nullable=True),
        sa.Column("telefono", sa.String(length=20), nullable=True),
        sa.Column("email", sa.String(length=100), nullable=True),
        sa.Column("activo", sa.Boolean(), nullable=False, server_default=sa.text("true")),
    )

    op.create_table(
        "categorias",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("nombre", sa.String(length=100), nullable=False, unique=True),
        sa.Column(
            "padre_id",
            sa.Integer(),
            sa.ForeignKey("categorias.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("activo", sa.Boolean(), nullable=False, server_default=sa.text("true")),
    )

    op.create_table(
        "usuarios",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("nombre", sa.String(length=100), nullable=False),
        sa.Column("email", sa.String(length=100), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column(
            "rol_id",
            sa.Integer(),
            sa.ForeignKey("roles.id"),
            nullable=False,
        ),
        sa.Column("activo", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column(
            "creado_en",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
    )
    op.create_index("uq_usuarios_email_lower", "usuarios", [sa.text("lower(email)")], unique=True)
    op.create_index("ix_usuarios_rol", "usuarios", ["rol_id"])

    op.create_table(
        "productos",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("sku", sa.String(length=50), unique=True, nullable=True),
        sa.Column("codigo_barras", sa.String(length=50), unique=True, nullable=True),
        sa.Column("nombre", sa.String(length=200), nullable=False),
        sa.Column("descripcion", sa.Text(), nullable=True),
        sa.Column("categoria_id", sa.Integer(), sa.ForeignKey("categorias.id"), nullable=True),
        sa.Column("marca_id", sa.Integer(), sa.ForeignKey("marcas.id"), nullable=True),
        sa.Column("proveedor_id", sa.Integer(), sa.ForeignKey("proveedores.id"), nullable=True),
        sa.Column("precio_compra", sa.Numeric(10, 2), nullable=False),
        sa.Column("precio_venta", sa.Numeric(10, 2), nullable=False),
        sa.Column("stock_minimo", sa.Integer(), nullable=False, server_default=sa.text("5")),
        sa.Column("imagen_url", sa.Text(), nullable=True),
        sa.Column("activo", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column(
            "creado_en",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.CheckConstraint("precio_compra >= 0", name="chk_precio_compra_no_negativo"),
        sa.CheckConstraint("precio_venta >= 0", name="chk_precio_venta_no_negativo"),
        sa.CheckConstraint("stock_minimo >= 0", name="chk_stock_minimo_no_negativo"),
    )
    op.create_index("idx_productos_categoria", "productos", ["categoria_id"])
    op.create_index("idx_productos_marca", "productos", ["marca_id"])
    op.create_index("idx_productos_proveedor", "productos", ["proveedor_id"])
    op.create_index("idx_productos_nombre", "productos", ["nombre"])

    op.create_table(
        "inventario",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "producto_id",
            sa.Integer(),
            sa.ForeignKey("productos.id", ondelete="CASCADE"),
            unique=True,
            nullable=False,
        ),
        sa.Column("cantidad", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column(
            "actualizado_en",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.CheckConstraint("cantidad >= 0", name="chk_inventario_cantidad_no_negativa"),
    )

    op.create_table(
        "sesiones_camara",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("usuario_id", sa.Integer(), sa.ForeignKey("usuarios.id"), nullable=True),
        sa.Column("tipo_operacion", sa.String(length=50), nullable=False),
        sa.Column(
            "fecha_inicio",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.Column("fecha_fin", sa.DateTime(timezone=True), nullable=True),
        sa.Column("productos_detectados", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.CheckConstraint(
            "tipo_operacion IN ('entrada', 'salida', 'conteo')", name="chk_sesion_tipo_operacion"
        ),
        sa.CheckConstraint(
            "productos_detectados >= 0", name="chk_productos_detectados_no_negativo"
        ),
        sa.CheckConstraint(
            "fecha_fin IS NULL OR fecha_fin >= fecha_inicio", name="chk_fechas_sesion"
        ),
    )
    op.create_index("idx_sesiones_usuario", "sesiones_camara", ["usuario_id"])

    op.create_table(
        "movimientos",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("producto_id", sa.Integer(), sa.ForeignKey("productos.id"), nullable=False),
        sa.Column("usuario_id", sa.Integer(), sa.ForeignKey("usuarios.id"), nullable=True),
        sa.Column(
            "sesion_id",
            sa.Integer(),
            sa.ForeignKey("sesiones_camara.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("tipo", sa.String(length=20), nullable=False),
        sa.Column("cantidad_anterior", sa.Integer(), nullable=False),
        sa.Column("cantidad", sa.Integer(), nullable=False),
        sa.Column("stock_resultante", sa.Integer(), nullable=False),
        sa.Column("origen", sa.String(length=10), nullable=False),
        sa.Column(
            "creado_en",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.CheckConstraint("tipo IN ('entrada', 'salida', 'ajuste')", name="chk_movimiento_tipo"),
        sa.CheckConstraint("cantidad_anterior >= 0", name="chk_cantidad_anterior_no_negativa"),
        sa.CheckConstraint("(cantidad > 0 OR tipo = 'ajuste')", name="chk_movimiento_cantidad_positiva"),
        sa.CheckConstraint("stock_resultante >= 0", name="chk_stock_resultante_no_negativo"),
        sa.CheckConstraint("origen IN ('manual', 'ia')", name="chk_movimiento_origen"),
        sa.CheckConstraint(
            "(tipo = 'entrada' AND stock_resultante = cantidad_anterior + cantidad) "
            "OR (tipo = 'salida' AND stock_resultante = cantidad_anterior - cantidad) "
            "OR (tipo = 'ajuste')",
            name="chk_consistencia_movimiento",
        ),
    )
    op.create_index("idx_movimientos_producto", "movimientos", ["producto_id"])
    op.create_index("idx_movimientos_usuario", "movimientos", ["usuario_id"])
    op.create_index("idx_movimientos_sesion", "movimientos", ["sesion_id"])
    op.create_index("idx_movimientos_fecha", "movimientos", ["creado_en"])

    op.create_table(
        "detecciones",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "sesion_id",
            sa.Integer(),
            sa.ForeignKey("sesiones_camara.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("producto_id", sa.Integer(), sa.ForeignKey("productos.id"), nullable=True),
        sa.Column("confianza", sa.Numeric(5, 4), nullable=False),
        sa.Column("imagen_url", sa.Text(), nullable=True),
        sa.Column(
            "detectado_en",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.CheckConstraint("confianza BETWEEN 0 AND 1", name="chk_confianza_rango"),
    )
    op.create_index("idx_detecciones_sesion", "detecciones", ["sesion_id"])
    op.create_index("idx_detecciones_producto", "detecciones", ["producto_id"])

    op.execute(
        "INSERT INTO roles (nombre) VALUES ('administrador'), ('vendedor') "
        "ON CONFLICT (nombre) DO NOTHING"
    )
    op.execute(
        "INSERT INTO categorias (nombre) VALUES ('General'), ('Tintes'), ('Peroxidos') "
        "ON CONFLICT (nombre) DO NOTHING"
    )
    op.execute(
        "INSERT INTO marcas (nombre) VALUES ('Schwarzkopf'), ('Loreal') "
        "ON CONFLICT (nombre) DO NOTHING"
    )


def downgrade() -> None:
    op.drop_table("detecciones")
    op.drop_table("movimientos")
    op.drop_table("sesiones_camara")
    op.drop_table("inventario")
    op.drop_table("productos")
    op.drop_table("usuarios")
    op.drop_table("categorias")
    op.drop_table("proveedores")
    op.drop_table("marcas")
    op.drop_table("roles")