from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.models.producto import Producto
from app.models.inventario import Inventario


class ProductoRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def listar_todos(self) -> list[Producto]:
        result = await self.db.execute(
            select(Producto)
            .options(joinedload(Producto.categoria))
            .where(Producto.activo == True)
        )
        return list(result.scalars().unique().all())

    async def obtener_por_id(self, producto_id: int) -> Optional[Producto]:
        result = await self.db.execute(
            select(Producto)
            .options(joinedload(Producto.categoria))
            .where(Producto.id == producto_id)
        )
        return result.scalar_one_or_none()

    async def obtener_stock(self, producto_id: int) -> int:
        result = await self.db.execute(
            select(Inventario).where(Inventario.producto_id == producto_id)
        )
        inventario = result.scalar_one_or_none()
        return inventario.cantidad if inventario else 0

    async def listar_con_stock(self) -> list[dict]:
        productos = await self.listar_todos()
        resultado = []
        for prod in productos:
            stock = await self.obtener_stock(prod.id)
            resultado.append({
                "producto": prod,
                "stock_actual": stock,
                "stock_bajo": stock < prod.stock_minimo,
            })
        return resultado
