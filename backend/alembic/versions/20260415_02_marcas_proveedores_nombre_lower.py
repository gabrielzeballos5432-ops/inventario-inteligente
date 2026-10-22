"""marcas y proveedores: unicidad de nombre sin distincion de mayusculas

Aplica a marcas y proveedores el mismo criterio que ya usa categorias
(uq_categorias_nombre_lower) y usuarios (uq_usuarios_email_lower):

- marcas: sustituye el UNIQUE de la columna, que en PostgreSQL distingue
  mayusculas y permitia registrar "Loreal" y "loreal" como dos marcas.
- proveedores: no tenia ninguna restriccion de unicidad, con lo que el mismo
  proveedor se podia registrar varias veces. Se le anade el indice.

Las violaciones que consigan colarse se devuelven como 409 con mensaje en
castellano gracias al handler IntegrityError de main.py.

Antes de crear los indices hay que resolver duplicados preexistentes: si hay
filas con el mismo nombre ignorando mayusculas, el CREATE UNIQUE INDEX falla.
Esta migracion no las borra (podrian tener productos asociados) y avisa.

Revision ID: 20260415_02
Revises: 20260415_01
Create Date: 2026-04-15 13:00:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260415_02"
down_revision = "20260415_01"
branch_labels = None
depends_on = None


# tabla -> (indice a crear, restriccion UNIQUE previa a quitar)
OBJETIVOS = {
    "marcas": ("uq_marcas_nombre_lower", "marcas_nombre_key"),
    "proveedores": ("uq_proveedores_nombre_lower", None),
}


def _duplicados(con, tabla: str) -> list[tuple[str, int]]:
    return list(
        con.execute(
            sa.text(
                "SELECT LOWER(nombre) AS n, COUNT(*) FROM %s "
                "GROUP BY LOWER(nombre) HAVING COUNT(*) > 1" % tabla
            )
        ).fetchall()
    )


def _existe_indice(con, nombre: str) -> bool:
    return (
        con.execute(
            sa.text("SELECT 1 FROM pg_indexes WHERE indexname = :n"),
            {"n": nombre},
        ).fetchone()
        is not None
    )


def upgrade() -> None:
    bind = op.get_bind()

    for tabla, (indice, restriccion) in OBJETIVOS.items():
        choques = _duplicados(bind, tabla)
        if choques:
            nombres = ", ".join("'%s' x%d" % (n, c) for n, c in choques)
            raise RuntimeError(
                "No se puede crear %s: en %s hay nombres que solo difieren en "
                "mayusculas (%s). Resuelvelos antes de migrar." % (indice, tabla, nombres)
            )

        if not _existe_indice(bind, indice):
            op.create_index(indice, tabla, [sa.text("lower(nombre)")], unique=True)

        # El nombre lo genera PostgreSQL al declarar la columna como UNIQUE.
        # Se suelta antes de crear el indice para que ambos no compitan.
        if restriccion is not None:
            op.execute(
                "ALTER TABLE %s DROP CONSTRAINT IF EXISTS %s" % (tabla, restriccion)
            )


def downgrade() -> None:
    for tabla, (indice, restriccion) in OBJETIVOS.items():
        op.drop_index(indice, table_name=tabla)
        if restriccion is not None:
            op.create_unique_constraint(restriccion, tabla, ["nombre"])
        # proveedores no tenia UNIQUE: el downgrade lo deja como estaba.