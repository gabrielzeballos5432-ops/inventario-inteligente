from typing import Optional

from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.models.movimiento import Movimiento
from app.models.inventario import Inventario


class MovimientoRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def crear_movimiento(
        self,
        producto_id: int,
        usuario_id: int,
        tipo: str,
        cantidad: int,
        origen: str = "app",
    ) -> Movimiento:
        inventario = await self.db.execute(
            select(Inventario).where(Inventario.producto_id == producto_id)
        )
        inv = inventario.scalar_one_or_none()
        if inv is None:
            inv = Inventario(producto_id=producto_id, cantidad=0)
            self.db.add(inv)
            await self.db.flush()

        if tipo == "entrada":
            inv.cantidad += cantidad
        elif tipo == "salida":
            inv.cantidad = max(0, inv.cantidad - cantidad)

        mov = Movimiento(
            producto_id=producto_id,
            usuario_id=usuario_id,
            tipo=tipo,
            cantidad=cantidad,
            stock_resultante=inv.cantidad,
            origen=origen,
        )
        self.db.add(mov)
        await self.db.commit()
        await self.db.refresh(mov)
        return mov

    async def listar_historial(
        self, limite: int = 50
    ) -> list[Movimiento]:
        result = await self.db.execute(
            select(Movimiento)
            .options(
                joinedload(Movimiento.producto),
                joinedload(Movimiento.usuario),
            )
            .order_by(desc(Movimiento.creado_en))
            .limit(limite)
        )
        return list(result.scalars().unique().all())

    async def listar_por_producto(
        self, producto_id: int, limite: int = 20
    ) -> list[Movimiento]:
        result = await self.db.execute(
            select(Movimiento)
            .options(
                joinedload(Movimiento.producto),
                joinedload(Movimiento.usuario),
            )
            .where(Movimiento.producto_id == producto_id)
            .order_by(desc(Movimiento.creado_en))
            .limit(limite)
        )
        return list(result.scalars().unique().all())
