"""renombra las tablas del esquema al singular

Revision ID: 20261024_01
Revises: 20260415_02
Create Date: 2026-10-24 22:00:00
"""

from alembic import op


revision = "20261024_01"
down_revision = "20260415_02"
branch_labels = None
depends_on = None


TABLAS = (
    ("roles", "rol"),
    ("usuarios", "usuario"),
    ("categorias", "categoria"),
    ("marcas", "marca"),
    ("proveedores", "proveedor"),
    ("productos", "producto"),
    ("sesiones_camara", "sesion_camara"),
    ("movimientos", "movimiento"),
    ("detecciones", "deteccion"),
)

INDICES = (
    ("uq_usuarios_email_lower", "uq_usuario_email_lower"),
    ("uq_categorias_nombre_lower", "uq_categoria_nombre_lower"),
    ("uq_marcas_nombre_lower", "uq_marca_nombre_lower"),
    ("uq_proveedores_nombre_lower", "uq_proveedor_nombre_lower"),
    ("ix_usuarios_rol", "idx_usuario_rol"),
    ("idx_productos_categoria", "idx_producto_categoria"),
    ("idx_productos_marca", "idx_producto_marca"),
    ("idx_productos_proveedor", "idx_producto_proveedor"),
    ("idx_productos_nombre", "idx_producto_nombre"),
    ("idx_sesiones_usuario", "idx_sesion_usuario"),
    ("idx_movimientos_producto", "idx_movimiento_producto"),
    ("idx_movimientos_usuario", "idx_movimiento_usuario"),
    ("idx_movimientos_sesion", "idx_movimiento_sesion"),
    ("idx_movimientos_fecha", "idx_movimiento_fecha"),
    ("idx_detecciones_sesion", "idx_deteccion_sesion"),
    ("idx_detecciones_producto", "idx_deteccion_producto"),
)


def upgrade() -> None:
    for anterior, singular in TABLAS:
        op.rename_table(anterior, singular)

    for anterior, singular in INDICES:
        op.execute(f'ALTER INDEX "{anterior}" RENAME TO "{singular}"')

    op.execute(
        'ALTER INDEX IF EXISTS "idx_categorias_padre" RENAME TO "idx_categoria_padre"'
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS idx_categoria_padre ON categoria (padre_id)"
    )


def downgrade() -> None:
    op.execute(
        'ALTER INDEX "idx_categoria_padre" RENAME TO "idx_categorias_padre"'
    )

    for singular, anterior in reversed(INDICES):
        op.execute(f'ALTER INDEX "{anterior}" RENAME TO "{singular}"')

    for anterior, singular in reversed(TABLAS):
        op.rename_table(singular, anterior)
