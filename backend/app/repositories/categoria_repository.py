from typing import Optional

from sqlalchemy import select
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
        result = await self.db.execute(
            select(Categoria).where(Categoria.nombre == nombre)
        )
        return result.scalar_one_or_none()

    async def crear(self, categoria: Categoria) -> Categoria:
        self.db.add(categoria)
        await self.db.commit()
        return await self.obtener_por_id(categoria.id)

    async def guardar(self, categoria: Categoria) -> Categoria:
        await self.db.commit()
        return await self.obtener_por_id(categoria.id)