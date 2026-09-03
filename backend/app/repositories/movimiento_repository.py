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
        origen: str = "manual",
        sesion_id: Optional[int] = None,
    ) -> Movimiento:
        inventario = await self.db.execute(
            select(Inventario).where(Inventario.producto_id == producto_id)
        )
        inv = inventario.scalar_one_or_none()
        cantidad_anterior = inv.cantidad if inv else 0

        if tipo == "entrada":
            stock_resultante = cantidad_anterior + cantidad
        elif tipo == "salida":
            stock_resultante = max(0, cantidad_anterior - cantidad)
        elif tipo == "ajuste":
            stock_resultante = cantidad
        else:
            stock_resultante = cantidad_anterior

        if inv is None:
            inv = Inventario(producto_id=producto_id, cantidad=stock_resultante)
            self.db.add(inv)
        else:
            inv.cantidad = stock_resultante

        mov = Movimiento(
            producto_id=producto_id,
            usuario_id=usuario_id,
            sesion_id=sesion_id,
            tipo=tipo,
            cantidad_anterior=cantidad_anterior,
            cantidad=cantidad,
            stock_resultante=stock_resultante,
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