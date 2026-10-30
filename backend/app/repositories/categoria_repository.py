from typing import Optional

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.categoria import Categoria


class CategoriaRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def listar_todas(self) -> list[Categoria]:
        result = await self.db.execute(
            select(Categoria).where(Categoria.activo == True).order_by(Categoria.nombre.asc())
        )
        return list(result.scalars().all())

    async def obtener_por_id(self, categoria_id: int) -> Optional[Categoria]:
        result = await self.db.execute(
            select(Categoria).where(Categoria.id == categoria_id)
        )
        return result.scalar_one_or_none()

    async def obtener_por_nombre(self, nombre: str) -> Optional[Categoria]:
        # La busqueda ignora mayusculas para coincidir con
        # uq_categoria_nombre_lower. Con una comparacion exacta, escribir
        # "uñas" no encontraria la categoria desactivada "Uñas" y el alta
        # crearia una fila nueva en vez de reactivarla.
        #
        # Se usa first() y no scalar_one_or_none(): si la base todavia no
        # tiene el indice (instalacion previa a la migracion) podria haber
        # mas de una fila y el error seria peor que la ambiguedad.
        resultado = await self.db.execute(
            select(Categoria)
            .where(func.lower(Categoria.nombre) == nombre.strip().lower())
            .order_by(Categoria.id.asc())
        )
        return resultado.scalars().first()

    async def crear(self, categoria: Categoria) -> Categoria:
        self.db.add(categoria)
        await self.db.commit()
        return await self.obtener_por_id(categoria.id)

    async def guardar(self, categoria: Categoria) -> Categoria:
        await self.db.commit()
        return await self.obtener_por_id(categoria.id)