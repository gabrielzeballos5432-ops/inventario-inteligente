import hashlib
import json
from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.caja import Cliente
from app.models.inventario import Inventario
from app.models.movimiento import Movimiento
from app.models.producto import Producto
from app.models.razon_movimiento import razon_sistema
from app.models.caja import SesionCaja
from app.models.venta import PagoVenta, Venta, VentaDetalle
from app.schemas.venta import VentaCreate
from app.services.caja_service import CajaService, CajaValidationError


CENTAVO = Decimal("0.01")
TOTAL_MAXIMO = Decimal("9999999999.99")
TOTAL_COSTO_MAXIMO = Decimal("999999999999.99")


class VentaValidationError(Exception):
    pass


def _total_linea(detalle) -> Decimal:
    calculado = (detalle.precio_unitario_negociado * detalle.cantidad).quantize(
        CENTAVO, rounding=ROUND_HALF_UP
    )
    if detalle.total_linea is None:
        return calculado
    # El precio unitario llega redondeado a centavos: se tolera la diferencia
    # que ese redondeo puede producir en la línea, no un total arbitrario.
    if abs(detalle.total_linea - calculado) > CENTAVO * detalle.cantidad:
        raise VentaValidationError(
            "El total de la línea no corresponde a cantidad x precio unitario."
        )
    return detalle.total_linea


class VentaService:
    def __init__(self, db: AsyncSession):
        self.db = db

    @staticmethod
    def _huella(body: VentaCreate) -> str:
        datos = body.model_dump(mode="json", exclude={"clave_idempotencia"})
        serializado = json.dumps(datos, sort_keys=True, separators=(",", ":"))
        return hashlib.sha256(serializado.encode("utf-8")).hexdigest()

    async def _obtener_por_clave(
        self, clave: str, usuario_id: int
    ) -> Venta | None:
        resultado = await self.db.execute(
            select(Venta)
            .options(selectinload(Venta.detalles), selectinload(Venta.pagos))
            .where(
                Venta.clave_idempotencia == clave,
                Venta.usuario_id == usuario_id,
            )
        )
        return resultado.scalar_one_or_none()

    async def registrar(
        self,
        body: VentaCreate,
        usuario_id: int,
        clave_idempotencia: str | None = None,
        *,
        sucursal_id: int,
    ) -> Venta:
        clave = clave_idempotencia or body.clave_idempotencia
        if (
            clave_idempotencia
            and body.clave_idempotencia
            and clave_idempotencia != body.clave_idempotencia
        ):
            raise VentaValidationError(
                "La clave de idempotencia del encabezado y del cuerpo no coincide."
            )
        huella = self._huella(body)
        if clave:
            existente = await self._obtener_por_clave(clave, usuario_id)
            if existente is not None:
                if existente.huella_solicitud != huella:
                    raise VentaValidationError(
                        "La clave de idempotencia ya se usó con otros datos."
                    )
                return existente

        if body.cliente_id is not None:
            cliente = await self.db.get(Cliente, body.cliente_id)
            if cliente is None or not cliente.activo:
                raise VentaValidationError("El cliente no existe o está inactivo.")
        sesion_caja_id = body.sesion_caja_id
        if sesion_caja_id is None:
            abierta = await self.db.execute(
                select(SesionCaja.id).where(
                    SesionCaja.usuario_apertura_id == usuario_id,
                    SesionCaja.estado == "abierta",
                )
            )
            sesion_caja_id = abierta.scalar_one_or_none()
        if sesion_caja_id is not None:
            try:
                await CajaService(self.db).validar_caja_venta(
                    usuario_id, sesion_caja_id
                )
            except CajaValidationError as exc:
                raise VentaValidationError(str(exc)) from exc

        producto_ids = sorted({detalle.producto_id for detalle in body.detalles})
        resultado_productos = await self.db.execute(
            select(Producto)
            .where(Producto.id.in_(producto_ids))
            .order_by(Producto.id)
            .with_for_update()
        )
        productos = {
            producto.id: producto for producto in resultado_productos.scalars()
        }

        for detalle in body.detalles:
            producto = productos.get(detalle.producto_id)
            if producto is None:
                raise VentaValidationError(
                    f"El producto {detalle.producto_id} no existe."
                )
            if not producto.activo:
                raise VentaValidationError(
                    f"El producto '{producto.nombre}' está dado de baja."
                )

        resultado_inventario = await self.db.execute(
            select(Inventario)
            .where(
                Inventario.producto_id.in_(producto_ids),
                Inventario.sucursal_id == sucursal_id,
            )
            .order_by(Inventario.producto_id)
            .with_for_update()
        )
        inventarios = {
            inventario.producto_id: inventario
            for inventario in resultado_inventario.scalars()
        }

        cantidades_por_producto: dict[int, int] = {}
        for detalle in body.detalles:
            cantidades_por_producto[detalle.producto_id] = (
                cantidades_por_producto.get(detalle.producto_id, 0)
                + detalle.cantidad
            )
        for producto_id, cantidad in cantidades_por_producto.items():
            inventario = inventarios.get(producto_id)
            disponible = inventario.cantidad if inventario else 0
            if cantidad > disponible:
                nombre = productos[producto_id].nombre
                raise VentaValidationError(
                    f"No hay stock suficiente de '{nombre}': "
                    f"disponible {disponible}, solicitado {cantidad}."
                )

        total = sum(
            (_total_linea(detalle) for detalle in body.detalles),
            Decimal("0.00"),
        ).quantize(CENTAVO, rounding=ROUND_HALF_UP)
        if total > TOTAL_MAXIMO:
            raise VentaValidationError(
                "El total de la venta supera el máximo permitido."
            )
        total_pagado = sum((pago.monto for pago in body.pagos), Decimal("0.00"))
        if total_pagado != total:
            raise VentaValidationError(
                f"Los pagos suman {total_pagado:.2f}; el total de la venta es {total:.2f}."
            )

        venta = Venta(
            usuario_id=usuario_id,
            sucursal_id=sucursal_id,
            cliente_id=body.cliente_id,
            sesion_caja_id=sesion_caja_id,
            clave_idempotencia=clave,
            huella_solicitud=huella if clave else None,
            tipo_venta=body.tipo_venta,
            total=total,
            estado="completada",
        )
        self.db.add(venta)
        await self.db.flush()

        detalles_creados: list[VentaDetalle] = []
        for detalle in body.detalles:
            producto = productos[detalle.producto_id]
            total_linea = _total_linea(detalle)
            costo_unitario = Decimal(producto.precio_compra).quantize(
                Decimal("0.0001"), rounding=ROUND_HALF_UP
            )
            costo_total = (costo_unitario * detalle.cantidad).quantize(
                CENTAVO, rounding=ROUND_HALF_UP
            )
            if costo_total > TOTAL_COSTO_MAXIMO:
                raise VentaValidationError(
                    f"El costo historico de '{producto.nombre}' supera el máximo permitido."
                )
            detalle_venta = VentaDetalle(
                venta_id=venta.id,
                producto_id=producto.id,
                producto_nombre=producto.nombre,
                producto_sku=producto.sku,
                cantidad=detalle.cantidad,
                precio_lista_unitario=(
                    producto.precio_mayor
                    if body.tipo_venta == "mayorista" and producto.precio_mayor
                    else producto.precio_venta
                ),
                precio_unitario_negociado=detalle.precio_unitario_negociado,
                total_linea=total_linea,
                costo_unitario_bob_aplicado=costo_unitario,
                costo_total_bob_aplicado=costo_total,
                tipo_promocion=detalle.tipo_promocion,
                observacion_promocion=detalle.observacion_promocion,
            )
            self.db.add(detalle_venta)
            detalles_creados.append(detalle_venta)
        await self.db.flush()

        pagos_creados = [
            PagoVenta(
                venta_id=venta.id,
                metodo_pago=pago.metodo_pago,
                monto=pago.monto,
                estado="confirmado",
                referencia=pago.referencia,
                sesion_caja_id=sesion_caja_id,
            )
            for pago in body.pagos
        ]
        self.db.add_all(pagos_creados)

        stock_resultante_por_producto: dict[int, int] = {}
        for detalle in detalles_creados:
            inventario = inventarios[detalle.producto_id]
            cantidad_anterior = stock_resultante_por_producto.get(
                detalle.producto_id, inventario.cantidad
            )
            stock_resultante = cantidad_anterior - detalle.cantidad
            inventario.cantidad = stock_resultante
            stock_resultante_por_producto[detalle.producto_id] = stock_resultante
            self.db.add(
                Movimiento(
                    producto_id=detalle.producto_id,
                    sucursal_id=sucursal_id,
                    razon_movimiento_id=razon_sistema("venta"),
                    usuario_id=usuario_id,
                    tipo="salida",
                    cantidad_anterior=cantidad_anterior,
                    cantidad=detalle.cantidad,
                    stock_resultante=stock_resultante,
                    origen="manual",
                    venta_detalle=detalle,
                )
            )

        try:
            await self.db.commit()
        except IntegrityError:
            await self.db.rollback()
            if clave:
                existente = await self._obtener_por_clave(clave, usuario_id)
                if existente is not None:
                    if existente.huella_solicitud != huella:
                        raise VentaValidationError(
                            "La clave de idempotencia ya se usó con otros datos."
                        )
                    return existente
            raise
        resultado = await self.db.execute(
            select(Venta)
            .options(selectinload(Venta.detalles), selectinload(Venta.pagos))
            .where(Venta.id == venta.id)
        )
        return resultado.scalar_one()

    async def anular(
        self, venta_id: int, usuario_id: int, motivo: str
    ) -> Venta:
        resultado = await self.db.execute(
            select(Venta)
            .options(selectinload(Venta.detalles), selectinload(Venta.pagos))
            .where(Venta.id == venta_id)
            .with_for_update()
        )
        venta = resultado.scalar_one_or_none()
        if venta is None:
            raise VentaValidationError("Venta no encontrada.")
        if venta.estado != "completada":
            raise VentaValidationError("La venta ya está anulada.")

        for detalle in sorted(
            venta.detalles, key=lambda item: (item.producto_id, item.id)
        ):
            inventario_resultado = await self.db.execute(
                select(Inventario)
                .where(
                    Inventario.producto_id == detalle.producto_id,
                    Inventario.sucursal_id == venta.sucursal_id,
                )
                .with_for_update()
            )
            inventario = inventario_resultado.scalar_one_or_none()
            if inventario is None:
                raise VentaValidationError(
                    f"No existe inventario para el producto {detalle.producto_id}."
                )
            movimiento_resultado = await self.db.execute(
                select(Movimiento)
                .where(
                    Movimiento.venta_detalle_id == detalle.id,
                    Movimiento.movimiento_revertido_id.is_(None),
                    Movimiento.tipo == "salida",
                )
                .with_for_update()
            )
            movimiento_original = movimiento_resultado.scalar_one_or_none()
            if movimiento_original is None:
                raise VentaValidationError(
                    f"No se encontró el movimiento de salida de la línea {detalle.id}."
                )
            anterior = inventario.cantidad
            resultante = anterior + detalle.cantidad
            inventario.cantidad = resultante
            self.db.add(
                Movimiento(
                    producto_id=detalle.producto_id,
                    sucursal_id=venta.sucursal_id,
                    razon_movimiento_id=razon_sistema("anulacion_venta"),
                    usuario_id=usuario_id,
                    tipo="entrada",
                    cantidad_anterior=anterior,
                    cantidad=detalle.cantidad,
                    stock_resultante=resultante,
                    origen="manual",
                    movimiento_revertido=movimiento_original,
                )
            )
        for pago in venta.pagos:
            pago.estado = "anulado"
        venta.estado = "anulada"
        venta.anulada_en = datetime.now(timezone.utc)
        venta.anulada_por_usuario_id = usuario_id
        venta.motivo_anulacion = motivo.strip()
        await self.db.commit()
        resultado = await self.db.execute(
            select(Venta)
            .options(selectinload(Venta.detalles), selectinload(Venta.pagos))
            .where(Venta.id == venta_id)
        )
        return resultado.scalar_one()

    async def listar(
        self, limite: int = 50, sucursal_id: int | None = None
    ) -> list[Venta]:
        query = select(Venta).options(
            selectinload(Venta.detalles), selectinload(Venta.pagos)
        )
        if sucursal_id is not None:
            query = query.where(Venta.sucursal_id == sucursal_id)
        resultado = await self.db.execute(
            query.order_by(Venta.fecha_creacion.desc(), Venta.id.desc()).limit(limite)
        )
        return list(resultado.scalars().all())
