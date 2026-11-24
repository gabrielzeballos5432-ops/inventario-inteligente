from typing import Optional

from sqlalchemy import func, select
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

    async def obtener_stock(self, producto_id: int, sucursal_id: int) -> int:
        result = await self.db.execute(
            select(Inventario.cantidad).where(
                Inventario.producto_id == producto_id,
                Inventario.sucursal_id == sucursal_id,
            )
        )
        cantidad = result.scalar_one_or_none()
        return cantidad or 0

    async def obtener_por_ids(self, ids: list[int]) -> list[Producto]:
        # Un solo SELECT para todo el lote: evita N+1 al validar las filas.
        if not ids:
            return []
        result = await self.db.execute(select(Producto).where(Producto.id.in_(ids)))
        return list(result.scalars().all())

    async def obtener_stocks(
        self, ids: list[int], sucursal_id: Optional[int]
    ) -> dict[int, int]:
        """Stock de varios productos en una consulta.

        Con `sucursal_id=None` suma todas las sucursales (reportes globales y
        costo promedio de compra, que es uno solo por producto).
        """
        if not ids:
            return {}
        query = (
            select(Inventario.producto_id, func.sum(Inventario.cantidad))
            .where(Inventario.producto_id.in_(ids))
            .group_by(Inventario.producto_id)
        )
        if sucursal_id is not None:
            query = query.where(Inventario.sucursal_id == sucursal_id)
        result = await self.db.execute(query)
        return {producto_id: int(cantidad or 0) for producto_id, cantidad in result.all()}

    async def listar_con_stock(self, sucursal_id: Optional[int]) -> list[dict]:
        """Productos activos con su stock en la sucursal (None = todas)."""
        productos = await self.listar_todos()
        stocks = await self.obtener_stocks([p.id for p in productos], sucursal_id)
        resultado = []
        for prod in productos:
            stock = stocks.get(prod.id, 0)
            resultado.append({
                "producto": prod,
                "stock_actual": stock,
                "stock_bajo": stock < prod.stock_minimo,
            })
        return resultado
