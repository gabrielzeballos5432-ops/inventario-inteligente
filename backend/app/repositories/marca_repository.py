from typing import Optional

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.marca import Marca


class MarcaRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def listar_todas(self) -> list[Marca]:
        result = await self.db.execute(
            select(Marca).where(Marca.activo == True).order_by(Marca.nombre.asc())
        )
        return list(result.scalars().all())

    async def obtener_por_id(self, marca_id: int) -> Optional[Marca]:
        result = await self.db.execute(
            select(Marca).where(Marca.id == marca_id)
        )
        return result.scalar_one_or_none()

    async def obtener_por_nombre(self, nombre: str) -> Optional[Marca]:
        # Sin distincion de mayusculas, igual que categorias: la unicidad la
        # garantiza uq_marca_nombre_lower sobre lower(nombre).
        resultado = await self.db.execute(
            select(Marca)
            .where(func.lower(Marca.nombre) == nombre.strip().lower())
            .order_by(Marca.id.asc())
        )
        return resultado.scalars().first()

    async def crear(self, marca: Marca) -> Marca:
        self.db.add(marca)
        await self.db.commit()
        return await self.obtener_por_id(marca.id)

    async def guardar(self, marca: Marca) -> Marca:
        await self.db.commit()
        return await self.obtener_por_id(marca.id)