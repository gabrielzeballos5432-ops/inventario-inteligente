from decimal import Decimal, ROUND_HALF_UP

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.compra import Compra, CompraDetalle, Moneda
from app.models.inventario import Inventario
from app.models.movimiento import Movimiento
from app.models.producto import Producto
from app.models.proveedor import Proveedor
from app.schemas.compra import CompraCreate, MonedaCreate


CENTAVO = Decimal("0.01")
CUATRO_DECIMALES = Decimal("0.0001")
MAXIMO_MONETARIO = Decimal("99999999999999.9999")
MAXIMO_BOB = Decimal("999999999999.99")


def _unidad_minima(decimales: int) -> Decimal:
    return Decimal("1").scaleb(-decimales)


class CompraValidationError(Exception):
    pass


class CompraService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def listar_monedas(self, incluir_inactivas: bool = False) -> list[Moneda]:
        query = select(Moneda).order_by(Moneda.codigo)
        if not incluir_inactivas:
            query = query.where(Moneda.activa.is_(True))
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def crear_moneda(self, data: MonedaCreate) -> Moneda:
        existente = await self.db.get(Moneda, data.codigo)
        if existente is not None:
            raise CompraValidationError(
                f"Ya existe la moneda con código {data.codigo}."
            )
        moneda = Moneda(**data.model_dump(), activa=True)
        self.db.add(moneda)
        await self.db.commit()
        await self.db.refresh(moneda)
        return moneda

    async def actualizar_estado_moneda(self, codigo: str, activa: bool) -> Moneda:
        moneda = await self.db.get(Moneda, codigo)
        if moneda is None:
            raise CompraValidationError("Moneda no encontrada.")
        moneda.activa = activa
        await self.db.commit()
        await self.db.refresh(moneda)
        return moneda

    async def registrar(self, data: CompraCreate, usuario_id: int) -> Compra:
        if len({detalle.producto_id for detalle in data.detalles}) != len(data.detalles):
            raise CompraValidationError(
                "No se puede repetir un producto en la misma compra."
            )

        moneda = await self.db.get(Moneda, data.moneda_codigo)
        if moneda is None or not moneda.activa:
            raise CompraValidationError("La moneda no existe o está inactiva.")
        if data.moneda_codigo == "USD" and data.tipo_cambio_ext != Decimal("1"):
            raise CompraValidationError(
                "Para compras en USD, tipo_cambio_ext debe ser 1."
            )
        if (
            data.moneda_codigo == "BOB"
            and data.tipo_cambio_ext != data.tipo_cambio_bob
        ):
            raise CompraValidationError(
                "Para compras en BOB, tipo_cambio_ext y tipo_cambio_bob "
                "deben representar la misma cotización."
            )

        unidad_minima = _unidad_minima(moneda.decimales)
        if data.descuento_moneda.quantize(unidad_minima) != data.descuento_moneda:
            raise CompraValidationError(
                f"El descuento admite como máximo {moneda.decimales} decimales "
                "para esta moneda."
            )
        proveedor = await self.db.get(Proveedor, data.proveedor_id)
        if proveedor is None or not proveedor.activo:
            raise CompraValidationError("El proveedor no existe o está inactivo.")

        producto_ids = sorted(detalle.producto_id for detalle in data.detalles)
        result_productos = await self.db.execute(
            select(Producto)
            .where(Producto.id.in_(producto_ids))
            .order_by(Producto.id)
            .with_for_update()
        )
        productos = {producto.id: producto for producto in result_productos.scalars()}
        for producto_id in producto_ids:
            producto = productos.get(producto_id)
            if producto is None:
                raise CompraValidationError(
                    f"El producto {producto_id} no existe."
                )
            if not producto.activo:
                raise CompraValidationError(
                    f"El producto '{producto.nombre}' está dado de baja."
                )

        lineas = []
        subtotal = Decimal("0.00")
        for item in data.detalles:
            subtotal_linea = (item.costo_unitario_moneda * item.cantidad).quantize(
                unidad_minima, rounding=ROUND_HALF_UP
            )
            subtotal += subtotal_linea
            lineas.append((item, subtotal_linea))

        subtotal = subtotal.quantize(unidad_minima, rounding=ROUND_HALF_UP)
        descuento = data.descuento_moneda.quantize(unidad_minima)
        if descuento > subtotal:
            raise CompraValidationError(
                "El descuento no puede superar el subtotal de la compra."
            )
        base_adicional = subtotal - descuento
        costo_manipulacion = (
            base_adicional * data.porcentaje_manipulacion_envio / Decimal("100")
        ).quantize(unidad_minima, rounding=ROUND_HALF_UP)
        total_moneda = base_adicional + costo_manipulacion
        total_usd = total_moneda / data.tipo_cambio_ext
        total_bob = (total_usd * data.tipo_cambio_bob).quantize(
            CENTAVO, rounding=ROUND_HALF_UP
        )
        if total_moneda > MAXIMO_MONETARIO or total_bob > MAXIMO_BOB:
            raise CompraValidationError(
                "El total supera la capacidad monetaria permitida."
            )

        compra = Compra(
            proveedor_id=proveedor.id,
            usuario_id=usuario_id,
            moneda_codigo=moneda.codigo,
            tipo_cambio_ext=data.tipo_cambio_ext,
            tipo_cambio_bob=data.tipo_cambio_bob,
            numero_factura=data.numero_factura,
            fecha_factura=data.fecha_factura,
            subtotal_moneda=subtotal,
            descuento_moneda=descuento,
            base_costo_adicional_moneda=base_adicional,
            porcentaje_manipulacion_envio=data.porcentaje_manipulacion_envio,
            costo_manipulacion_envio_moneda=costo_manipulacion,
            total_moneda=total_moneda,
            total_bob=total_bob,
            imagen_factura_url=data.imagen_factura_url,
            estado="registrada",
        )
        self.db.add(compra)
        await self.db.flush()

        result_inventario = await self.db.execute(
            select(Inventario)
            .where(Inventario.producto_id.in_(producto_ids))
            .order_by(Inventario.producto_id)
            .with_for_update()
        )
        inventarios = {
            inventario.producto_id: inventario
            for inventario in result_inventario.scalars()
        }

        detalles_creados: list[CompraDetalle] = []
        bob_asignado = Decimal("0.00")
        for indice, (item, subtotal_linea) in enumerate(lineas):
            proporcion = (
                subtotal_linea / subtotal if subtotal > 0 else Decimal("0")
            )
            if indice == len(lineas) - 1:
                total_linea_bob = total_bob - bob_asignado
            else:
                total_linea_bob = (total_bob * proporcion).quantize(
                    CENTAVO, rounding=ROUND_HALF_UP
                )
                bob_asignado += total_linea_bob
            costo_unitario_final = (
                total_linea_bob / item.cantidad
            ).quantize(CUATRO_DECIMALES, rounding=ROUND_HALF_UP)
            if costo_unitario_final > Decimal("99999999.99"):
                raise CompraValidationError(
                    "El costo unitario convertido supera el máximo permitido para el producto."
                )
            detalle = CompraDetalle(
                compra_id=compra.id,
                producto_id=item.producto_id,
                descripcion_factura=item.descripcion_factura,
                cantidad=item.cantidad,
                costo_unitario_moneda=item.costo_unitario_moneda,
                subtotal_linea_moneda=subtotal_linea,
                costo_unitario_final_bob=costo_unitario_final,
            )
            self.db.add(detalle)
            detalles_creados.append(detalle)

        await self.db.flush()
        for detalle in detalles_creados:
            inventario = inventarios.get(detalle.producto_id)
            if inventario is None:
                inventario = Inventario(producto_id=detalle.producto_id, cantidad=0)
                self.db.add(inventario)
                inventarios[detalle.producto_id] = inventario
            cantidad_anterior = inventario.cantidad
            stock_resultante = cantidad_anterior + detalle.cantidad
            if stock_resultante > 2_147_483_647:
                raise CompraValidationError(
                    f"La cantidad de inventario de '{productos[detalle.producto_id].nombre}' "
                    "superaría el máximo permitido."
                )
            inventario.cantidad = stock_resultante
            producto = productos[detalle.producto_id]
            stock_previo = cantidad_anterior
            total_unidades = stock_previo + detalle.cantidad
            if stock_previo == 0:
                costo_promedio = detalle.costo_unitario_final_bob
            else:
                costo_promedio = (
                    Decimal(producto.precio_compra) * stock_previo
                    + detalle.costo_unitario_final_bob * detalle.cantidad
                ) / Decimal(total_unidades)
            producto.precio_compra = costo_promedio.quantize(
                CENTAVO, rounding=ROUND_HALF_UP
            )
            self.db.add(
                Movimiento(
                    producto_id=detalle.producto_id,
                    usuario_id=usuario_id,
                    tipo="entrada",
                    cantidad_anterior=cantidad_anterior,
                    cantidad=detalle.cantidad,
                    stock_resultante=stock_resultante,
                    origen="manual",
                    compra_detalle=detalle,
                )
            )

        await self.db.commit()
        return await self.obtener(compra.id)

    async def obtener(self, compra_id: int) -> Compra:
        result = await self.db.execute(
            select(Compra)
            .options(selectinload(Compra.detalles))
            .where(Compra.id == compra_id)
        )
        compra = result.scalar_one_or_none()
        if compra is None:
            raise CompraValidationError("Compra no encontrada.")
        return compra

    async def listar(self, limite: int = 50) -> list[Compra]:
        result = await self.db.execute(
            select(Compra)
            .options(selectinload(Compra.detalles))
            .order_by(Compra.fecha_creacion.desc(), Compra.id.desc())
            .limit(limite)
        )
        return list(result.scalars().all())
