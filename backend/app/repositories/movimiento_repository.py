from typing import Any, Optional

from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.models.movimiento import Movimiento
from app.models.inventario import Inventario


def opciones_detalle_movimiento():
    # Todo lo que pinta el historial, en la misma consulta.
    return (
        joinedload(Movimiento.producto),
        joinedload(Movimiento.usuario),
        joinedload(Movimiento.razon),
        joinedload(Movimiento.sucursal),
        joinedload(Movimiento.sucursal_relacionada),
    )


class MovimientoRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def crear_movimiento(
        self,
        producto_id: int,
        usuario_id: int,
        tipo: str,
        cantidad: int,
        sucursal_id: int,
        razon_movimiento_id: Any,
        origen: str = "manual",
        sesion_id: Optional[int] = None,
    ) -> Movimiento:
        """Un movimiento suelto. `razon_movimiento_id` admite el id o la
        subconsulta de `razon_sistema()` para los movimientos automáticos."""
        inventario = await self.db.execute(
            select(Inventario).where(
                Inventario.producto_id == producto_id,
                Inventario.sucursal_id == sucursal_id,
            )
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
            inv = Inventario(
                producto_id=producto_id,
                sucursal_id=sucursal_id,
                cantidad=stock_resultante,
            )
            self.db.add(inv)
        else:
            inv.cantidad = stock_resultante

        mov = Movimiento(
            producto_id=producto_id,
            sucursal_id=sucursal_id,
            razon_movimiento_id=razon_movimiento_id,
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

    async def crear_lote(
        self,
        productos_y_cantidades: list[tuple[int, int]],
        usuario_id: int,
        tipo: str,
        sucursal_id: int,
        razon_movimiento_id: Any,
        origen: str = "manual",
        sesion_id: Optional[int] = None,
        sucursal_relacionada_id: Optional[int] = None,
        confirmar: bool = True,
        clave_idempotencia: Optional[str] = None,
    ) -> list[Movimiento]:
        """Crea varios movimientos del mismo tipo y ajusta el inventario.

        Una sola transaccion: se valida TODO antes de llamar aqui (el servicio
        rechaza filas con errores y devuelve una lista vacia), asi que si algo
        llegara a fallar el commit deshace todas las lineas y el lote nunca
        queda guardado a medias. La salida va estricta (sin recortar a 0 con
        max()): si un calculo se escapara, chk_stock_resultante_no_negativo
        rebota la transaccion entera en lugar de guardar un numero falso.

        Con `confirmar=False` no hace commit: el traspaso encadena la salida
        del origen y la entrada del destino y los confirma juntos.
        """
        ids = [producto_id for producto_id, _ in productos_y_cantidades]
        inventarios = await self.obtener_inventarios(ids, sucursal_id)

        movimientos: list[Movimiento] = []
        for producto_id, cantidad in productos_y_cantidades:
            inv = inventarios.get(producto_id)
            cantidad_anterior = inv.cantidad if inv else 0
            if tipo == "entrada":
                stock_resultante = cantidad_anterior + cantidad
            elif tipo == "salida":
                stock_resultante = cantidad_anterior - cantidad
            else:
                stock_resultante = cantidad

            if inv is None:
                inv = Inventario(
                    producto_id=producto_id,
                    sucursal_id=sucursal_id,
                    cantidad=stock_resultante,
                )
                self.db.add(inv)
                inventarios[producto_id] = inv
            else:
                inv.cantidad = stock_resultante

            mov = Movimiento(
                producto_id=producto_id,
                sucursal_id=sucursal_id,
                razon_movimiento_id=razon_movimiento_id,
                sucursal_relacionada_id=sucursal_relacionada_id,
                usuario_id=usuario_id,
                sesion_id=sesion_id,
                tipo=tipo,
                cantidad_anterior=cantidad_anterior,
                cantidad=cantidad,
                stock_resultante=stock_resultante,
                origen=origen,
                clave_idempotencia=clave_idempotencia,
            )
            self.db.add(mov)
            movimientos.append(mov)

        if confirmar:
            await self.db.commit()
        else:
            await self.db.flush()
        return movimientos

    async def obtener_por_clave(self, clave: str, usuario_id: int) -> list[Movimiento]:
        # Movimientos de un lote ya registrado con esta clave. La entrada del
        # destino de un traspaso no lleva la clave: solo el lote de origen.
        result = await self.db.execute(
            select(Movimiento)
            .options(joinedload(Movimiento.producto))
            .where(
                Movimiento.clave_idempotencia == clave,
                Movimiento.usuario_id == usuario_id,
            )
            .order_by(Movimiento.id)
        )
        return list(result.scalars().all())

    async def obtener_inventarios(
        self, ids: list[int], sucursal_id: int
    ) -> dict[int, Inventario]:
        # Los inventarios del lote en la sucursal, en una consulta;
        # producto_id -> fila. Puede faltar el de un producto que nunca tuvo
        # stock en esta sucursal: se crea junto con el movimiento.
        if not ids:
            return {}
        result = await self.db.execute(
            select(Inventario).where(
                Inventario.producto_id.in_(ids),
                Inventario.sucursal_id == sucursal_id,
            )
        )
        return {inv.producto_id: inv for inv in result.scalars().all()}

    async def obtener_detalle(self, ids: list[int]) -> list[Movimiento]:
        if not ids:
            return []
        result = await self.db.execute(
            select(Movimiento)
            .options(*opciones_detalle_movimiento())
            .where(Movimiento.id.in_(ids))
            .order_by(Movimiento.id)
            # Recién creados: la sesión no expira al confirmar y creado_en
            # (server_default) quedaría sin cargar; se fuerza a releer la fila.
            .execution_options(populate_existing=True)
        )
        return list(result.scalars().unique().all())

    async def listar_historial(
        self, limite: int = 50, sucursal_id: Optional[int] = None
    ) -> list[Movimiento]:
        query = select(Movimiento).options(*opciones_detalle_movimiento())
        if sucursal_id is not None:
            query = query.where(Movimiento.sucursal_id == sucursal_id)
        result = await self.db.execute(
            query.order_by(desc(Movimiento.creado_en)).limit(limite)
        )
        return list(result.scalars().unique().all())

    async def listar_por_producto(
        self, producto_id: int, limite: int = 20
    ) -> list[Movimiento]:
        result = await self.db.execute(
            select(Movimiento)
            .options(*opciones_detalle_movimiento())
            .where(Movimiento.producto_id == producto_id)
            .order_by(desc(Movimiento.creado_en))
            .limit(limite)
        )
        return list(result.scalars().unique().all())
