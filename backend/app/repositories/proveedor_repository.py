from typing import Optional

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.proveedor import Proveedor


class ProveedorRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def listar_todos(self) -> list[Proveedor]:
        result = await self.db.execute(
            select(Proveedor)
            .where(Proveedor.activo == True)
            .order_by(Proveedor.nombre.asc())
        )
        return list(result.scalars().all())

    async def obtener_por_id(self, proveedor_id: int) -> Optional[Proveedor]:
        result = await self.db.execute(
            select(Proveedor).where(Proveedor.id == proveedor_id)
        )
        return result.scalar_one_or_none()

    async def obtener_por_nombre(self, nombre: str) -> Optional[Proveedor]:
        # Sin distincion de mayusculas, igual que categorias y marcas.
        resultado = await self.db.execute(
            select(Proveedor)
            .where(func.lower(Proveedor.nombre) == nombre.strip().lower())
            .order_by(Proveedor.id.asc())
        )
        return resultado.scalars().first()

    async def crear(self, proveedor: Proveedor) -> Proveedor:
        self.db.add(proveedor)
        await self.db.commit()
        return await self.obtener_por_id(proveedor.id)

    async def guardar(self, proveedor: Proveedor) -> Proveedor:
        await self.db.commit()
        return await self.obtener_por_id(proveedor.id)