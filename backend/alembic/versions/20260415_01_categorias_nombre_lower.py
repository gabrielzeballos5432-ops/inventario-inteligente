"""categorias: unicidad de nombre sin distincion de mayusculas

Sustituye el UNIQUE de categorias.nombre por un indice unico sobre
LOWER(nombre), igual que ya hace uq_usuarios_email_lower en usuarios.

Motivo: un UNIQUE normal en PostgreSQL distingue mayusculas, asi que
"Uñas", "uñas" y "UÑAS" convivian como categorias distintas. Para quien usa
el inventario son la misma categoria y podia crear duplicados por descuido.

Antes de crear el indice hay que resolver los duplicados que ya existan: si
hay dos filas con el mismo nombre ignorando mayusculas, el CREATE UNIQUE
INDEX falla. Esta migracion no las borra por su cuenta (podrian tener
productos asociados) y avisa para que se revisen a mano.

Revision ID: 20260415_01
Revises: 20260401_00
Create Date: 2026-04-15 12:00:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260415_01"
down_revision = "20260401_00"
branch_labels = None
depends_on = None


def _duplicados(con) -> list[tuple[str, int]]:
    """Nombres que se repiten ignorando mayusculas, con su cantidad."""
    return list(
        con.execute(
            sa.text(
                "SELECT LOWER(nombre) AS n, COUNT(*) "
                "FROM categorias GROUP BY LOWER(nombre) HAVING COUNT(*) > 1"
            )
        ).fetchall()
    )


def upgrade() -> None:
    bind = op.get_bind()

    choques = _duplicados(bind)
    if choques:
        nombres = ", ".join("'%s' x%d" % (n, c) for n, c in choques)
        raise RuntimeError(
            "No se puede crear uq_categorias_nombre_lower: hay categorias que "
            "solo difieren en mayusculas (%s). Resuelvelas antes de migrar "
            "(desactiva o renombra una de cada par y borra la otra, "
            "comprobando que no tenga productos asociados)." % nombres
        )

    # El nombre de la restriccion lo genera PostgreSQL al declarar la columna
    # como UNIQUE, pero se comprueba antes de tirar nada: si alguien ya lo
    # quito a mano, la migracion debe seguir siendo idempotente.
    op.drop_constraint("categorias_nombre_key", "categorias", type_="unique")
    op.create_index(
        "uq_categorias_nombre_lower",
        "categorias",
        [sa.text("lower(nombre)")],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index("uq_categorias_nombre_lower", table_name="categorias")
    op.create_unique_constraint("categorias_nombre_key", "categorias", ["nombre"])