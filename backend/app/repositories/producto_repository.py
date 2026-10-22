from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.models.producto import Producto
from app.models.inventario import Inventario


class ProductoRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def listar_todos(
        self,
        incluir_inactivos: bool = False,
        texto: Optional[str] = None,
        categoria_id: Optional[int] = None,
    ) -> list[Producto]:
        query = select(Producto).options(joinedload(Producto.categoria))
        if not incluir_inactivos:
            query = query.where(Producto.activo == True)
        if texto:
            query = query.where(Producto.nombre.ilike(f"%{texto}%"))
        if categoria_id is not None:
            query = query.where(Producto.categoria_id == categoria_id)
        result = await self.db.execute(query)
        return list(result.scalars().unique().all())

    async def obtener_por_id(self, producto_id: int) -> Optional[Producto]:
        result = await self.db.execute(
            select(Producto)
            .options(joinedload(Producto.categoria))
            .where(Producto.id == producto_id)
        )
        return result.scalar_one_or_none()

    async def crear(self, producto: Producto) -> Producto:
        self.db.add(producto)
        await self.db.commit()
        return await self.obtener_por_id(producto.id)

    async def guardar(self, producto: Producto) -> Producto:
        await self.db.commit()
        return await self.obtener_por_id(producto.id)

    async def obtener_stock(self, producto_id: int) -> int:
        result = await self.db.execute(
            select(Inventario).where(Inventario.producto_id == producto_id)
        )
        inventario = result.scalar_one_or_none()
        return inventario.cantidad if inventario else 0

    async def obtener_por_ids(self, ids: list[int]) -> list[Producto]:
        # Un solo SELECT para todo el lote: evita N+1 al validar las filas.
        if not ids:
            return []
        result = await self.db.execute(select(Producto).where(Producto.id.in_(ids)))
        return list(result.scalars().all())

    async def obtener_stocks(self, ids: list[int]) -> dict[int, int]:
        # Stocks actuales de varios productos en una consulta, para validar las
        # salidas del lote sin llamar a obtener_stock por cada fila (N+1).
        if not ids:
            return {}
        result = await self.db.execute(
            select(Inventario.producto_id, Inventario.cantidad).where(
                Inventario.producto_id.in_(ids)
            )
        )
        return {producto_id: cantidad for producto_id, cantidad in result.all()}

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