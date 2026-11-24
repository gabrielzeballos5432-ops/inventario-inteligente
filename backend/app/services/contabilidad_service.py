from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP
from zoneinfo import ZoneInfo

from sqlalchemy import Date, cast, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.caja import SesionCaja
from app.models.compra import Moneda
from app.models.contabilidad import BonoSueldo, CategoriaGasto, Gasto, PagoGasto
from app.models.proveedor import Proveedor
from app.models.sueldo import LiquidacionSueldo
from app.models.usuario import Usuario
from app.models.venta import Venta, VentaDetalle
from app.schemas.contabilidad import (
    BonoSueldoCreate,
    CategoriaGastoCreate,
    CategoriaGastoUpdate,
    GastoCreate,
    PagoGastoCreate,
)
from app.services.caja_service import CajaService, CajaValidationError


CENTAVO = Decimal("0.01")
ZONA_NEGOCIO = ZoneInfo("America/La_Paz")


class ContabilidadValidationError(Exception):
    pass


class ContabilidadService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def registrar_bono(self, data: BonoSueldoCreate) -> BonoSueldo:
        result_usuario = await self.db.execute(
            select(Usuario)
            .options(selectinload(Usuario.rol))
            .where(Usuario.id == data.usuario_id)
        )
        usuario = result_usuario.scalar_one_or_none()
        if usuario is None or not usuario.activo or usuario.rol.nombre != "vendedor":
            raise ContabilidadValidationError(
                "El beneficiario debe ser un usuario vendedor activo."
            )
        liquidacion = None
        if data.liquidacion_sueldo_id is not None:
            result = await self.db.execute(
                select(LiquidacionSueldo)
                .where(LiquidacionSueldo.id == data.liquidacion_sueldo_id)
                .with_for_update()
            )
            liquidacion = result.scalar_one_or_none()
            if liquidacion is None or liquidacion.usuario_id != data.usuario_id:
                raise ContabilidadValidationError(
                    "La liquidación no existe o no corresponde al vendedor."
                )
            if liquidacion.estado != "pendiente":
                raise ContabilidadValidationError(
                    "No se pueden agregar bonos a una liquidación ya pagada."
                )

        bono = BonoSueldo(**data.model_dump())
        self.db.add(bono)
        if liquidacion is not None:
            liquidacion.total_bonos += data.monto
            liquidacion.total_pagado += data.monto
        await self.db.commit()
        await self.db.refresh(bono)
        return bono

    async def listar_bonos(
        self, usuario_id: int | None = None, limite: int = 200
    ) -> list[BonoSueldo]:
        query = select(BonoSueldo).order_by(
            BonoSueldo.fecha_registro.desc(), BonoSueldo.id.desc()
        )
        if usuario_id is not None:
            query = query.where(BonoSueldo.usuario_id == usuario_id)
        result = await self.db.execute(query.limit(limite))
        return list(result.scalars().all())

    async def asignar_bono(
        self, bono_id: int, liquidacion_id: int
    ) -> BonoSueldo:
        result = await self.db.execute(
            select(BonoSueldo).where(BonoSueldo.id == bono_id).with_for_update()
        )
        bono = result.scalar_one_or_none()
        if bono is None:
            raise ContabilidadValidationError("Bono no encontrado.")
        if bono.liquidacion_sueldo_id is not None:
            raise ContabilidadValidationError(
                "El bono ya fue asignado a una liquidación."
            )
        result_liquidacion = await self.db.execute(
            select(LiquidacionSueldo)
            .where(LiquidacionSueldo.id == liquidacion_id)
            .with_for_update()
        )
        liquidacion = result_liquidacion.scalar_one_or_none()
        if (
            liquidacion is None
            or liquidacion.usuario_id != bono.usuario_id
            or liquidacion.estado != "pendiente"
        ):
            raise ContabilidadValidationError(
                "La liquidación no existe, no corresponde al vendedor o ya fue pagada."
            )
        liquidacion.total_bonos += bono.monto
        liquidacion.total_pagado += bono.monto
        bono.liquidacion_sueldo_id = liquidacion.id
        await self.db.commit()
        await self.db.refresh(bono)
        return bono

    async def listar_categorias_gasto(self, incluir_inactivas: bool = False) -> list[CategoriaGasto]:
        query = select(CategoriaGasto).order_by(func.lower(CategoriaGasto.nombre), CategoriaGasto.id)
        if not incluir_inactivas:
            query = query.where(CategoriaGasto.activo.is_(True))
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def guardar_categoria_gasto(
        self, data: CategoriaGastoCreate | CategoriaGastoUpdate,
        categoria_id: int | None = None,
    ) -> CategoriaGasto:
        categoria = None
        if categoria_id is not None:
            categoria = await self.db.get(CategoriaGasto, categoria_id)
            if categoria is None:
                raise ContabilidadValidationError("Categoría de gasto no encontrada.")
        query = select(CategoriaGasto).where(
            func.lower(func.regexp_replace(
                func.trim(CategoriaGasto.nombre), r"\s+", " ", "g"
            )) == data.nombre.lower()
        ).with_for_update()
        if categoria_id is not None:
            query = query.where(CategoriaGasto.id != categoria_id)
        existente = await self.db.execute(query)
        coincidencias = list(existente.scalars().all())
        if coincidencias:
            if categoria_id is not None or any(c.activo for c in coincidencias):
                raise ContabilidadValidationError(
                    "Ya existe una categoría activa con ese nombre."
                )
            if len(coincidencias) > 1:
                raise ContabilidadValidationError(
                    "Hay varias categorías inactivas con ese nombre. "
                    "Contacta al administrador para revisar las coincidencias."
                )
            categoria = coincidencias[0]
            categoria.activo = True
        if categoria is None:
            categoria = CategoriaGasto(**data.model_dump(), activo=True)
            self.db.add(categoria)
        else:
            for campo, valor in data.model_dump().items():
                setattr(categoria, campo, valor)
        await self.db.commit()
        await self.db.refresh(categoria)
        return categoria

    async def eliminar_categoria_gasto(self, categoria_id: int) -> None:
        categoria = await self.db.get(CategoriaGasto, categoria_id)
        if categoria is None:
            raise ContabilidadValidationError("Categoría de gasto no encontrada.")
        categoria.activo = False
        await self.db.commit()

    async def registrar_gasto(
        self, data: GastoCreate, usuario_id: int, sucursal_id: int
    ) -> dict:
        valores = data.model_dump()
        if data.categoria_gasto_id is not None:
            resultado = await self.db.execute(
                select(CategoriaGasto)
                .where(CategoriaGasto.id == data.categoria_gasto_id)
                .with_for_update()
            )
            categoria = resultado.scalar_one_or_none()
            if categoria is None or not categoria.activo:
                raise ContabilidadValidationError("La categoría no existe o está inactiva.")
            valores["categoria"] = categoria.nombre
        moneda = await self.db.get(Moneda, data.moneda_codigo)
        if moneda is None or not moneda.activa:
            raise ContabilidadValidationError("La moneda no existe o está inactiva.")
        if data.moneda_codigo == "USD" and data.tipo_cambio_ext != Decimal("1"):
            raise ContabilidadValidationError(
                "Para gastos en USD, tipo_cambio_ext debe ser 1."
            )
        if data.moneda_codigo == "BOB" and data.tipo_cambio_ext != data.tipo_cambio_bob:
            raise ContabilidadValidationError(
                "Para gastos en BOB, las dos cotizaciones deben coincidir."
            )
        if data.monto.quantize(Decimal("1").scaleb(-moneda.decimales)) != data.monto:
            raise ContabilidadValidationError(
                f"El monto admite como máximo {moneda.decimales} decimales."
            )
        if data.proveedor_id is not None:
            proveedor = await self.db.get(Proveedor, data.proveedor_id)
            if proveedor is None or not proveedor.activo:
                raise ContabilidadValidationError(
                    "El proveedor no existe o está inactivo."
                )
        monto_bob = (
            data.monto / data.tipo_cambio_ext * data.tipo_cambio_bob
        ).quantize(CENTAVO, rounding=ROUND_HALF_UP)
        if monto_bob <= 0:
            raise ContabilidadValidationError(
                "El importe convertido a BOB debe ser mayor que cero."
            )
        gasto = Gasto(
            **valores,
            usuario_id=usuario_id,
            sucursal_id=sucursal_id,
            monto_bob=monto_bob,
            estado="pendiente",
        )
        self.db.add(gasto)
        await self.db.commit()
        return await self.obtener_gasto(gasto.id)

    async def registrar_pago_gasto(
        self, gasto_id: int, data: PagoGastoCreate, usuario_id: int
    ) -> PagoGasto:
        pagos = await self.registrar_pagos_gasto(gasto_id, [data], usuario_id)
        return pagos[0]

    async def registrar_pagos_gasto(
        self, gasto_id: int, datos: list[PagoGastoCreate], usuario_id: int
    ) -> list[PagoGasto]:
        result = await self.db.execute(
            select(Gasto).where(Gasto.id == gasto_id).with_for_update()
        )
        gasto = result.scalar_one_or_none()
        if gasto is None or gasto.estado == "anulado":
            raise ContabilidadValidationError(
                "El gasto no existe o está anulado."
            )
        moneda = await self.db.get(Moneda, gasto.moneda_codigo)
        if moneda is None:
            raise ContabilidadValidationError(
                "La moneda del gasto ya no está disponible."
            )
        if any(
            data.monto.quantize(Decimal("1").scaleb(-moneda.decimales)) != data.monto
            for data in datos
        ):
            raise ContabilidadValidationError(
                f"El pago admite como máximo {moneda.decimales} decimales."
            )
        pagado_result = await self.db.execute(
            select(func.coalesce(func.sum(PagoGasto.monto), 0)).where(
                PagoGasto.gasto_id == gasto_id
            )
        )
        pagado = Decimal(pagado_result.scalar_one())
        total = sum((data.monto for data in datos), Decimal("0"))
        if pagado + total > gasto.monto:
            raise ContabilidadValidationError(
                "El pago supera el saldo pendiente del gasto."
            )
        pagos = []
        # Efectivo que este registro saca de cada caja: no puede superar lo
        # que hay. Antes se aceptaba cualquier monto y la caja quedaba con un
        # esperado negativo que ya no se podía cerrar nunca.
        efectivo_por_caja: dict[int, Decimal] = {}
        cajas: dict[int, SesionCaja] = {}
        for data in datos:
            # Solo el efectivo marcado "desde la caja" se liga a una sesión:
            # el resto (QR, transferencia, efectivo pagado aparte) no toca el
            # cajón y no necesita caja abierta.
            sesion_caja_id = data.sesion_caja_id if data.desde_caja else None
            if data.desde_caja and sesion_caja_id is None:
                # El efectivo sale de la caja del local del gasto.
                abierta = await self.db.execute(
                    select(SesionCaja.id).where(
                        SesionCaja.usuario_apertura_id == usuario_id,
                        SesionCaja.estado == "abierta",
                        SesionCaja.sucursal_id == gasto.sucursal_id,
                    )
                )
                sesion_caja_id = abierta.scalar_one_or_none()
                if sesion_caja_id is None:
                    raise ContabilidadValidationError(
                        "No tienes una caja abierta en la sucursal del gasto. "
                        "Desmarca \"Se pagó con dinero de la caja\" si el "
                        "efectivo salió de otro lado."
                    )
            if sesion_caja_id is not None:
                try:
                    cajas[sesion_caja_id] = await CajaService(self.db).validar_caja_venta(
                        usuario_id, sesion_caja_id, gasto.sucursal_id
                    )
                except CajaValidationError as exc:
                    raise ContabilidadValidationError(str(exc)) from exc
            monto_bob = (
                data.monto / gasto.tipo_cambio_ext * gasto.tipo_cambio_bob
            ).quantize(CENTAVO, rounding=ROUND_HALF_UP)
            if monto_bob <= 0:
                raise ContabilidadValidationError(
                    "El importe convertido del pago debe ser mayor que cero."
                )
            if data.metodo_pago == "efectivo" and sesion_caja_id is not None:
                efectivo_por_caja[sesion_caja_id] = (
                    efectivo_por_caja.get(sesion_caja_id, Decimal("0")) + monto_bob
                )
            pagos.append(PagoGasto(
                gasto_id=gasto.id,
                sesion_caja_id=sesion_caja_id,
                monto=data.monto,
                monto_bob=monto_bob,
                metodo_pago=data.metodo_pago,
                referencia=data.referencia,
            ))
        for sesion_caja_id, salida in efectivo_por_caja.items():
            disponible = await CajaService(self.db).efectivo_en_caja(
                cajas[sesion_caja_id]
            )
            if salida > disponible:
                raise ContabilidadValidationError(
                    f"No hay efectivo suficiente en la caja: disponible "
                    f"Bs {max(disponible, Decimal('0')):.2f}, se quieren pagar "
                    f"Bs {salida:.2f}. Paga el resto por transferencia o QR."
                )
        self.db.add_all(pagos)
        if pagado + total == gasto.monto:
            gasto.estado = "pagado"
        await self.db.commit()
        for pago in pagos:
            await self.db.refresh(pago)
        return pagos

    async def anular_gasto(
        self, gasto_id: int, usuario_id: int, motivo: str
    ) -> dict:
        result = await self.db.execute(
            select(Gasto).where(Gasto.id == gasto_id).with_for_update()
        )
        gasto = result.scalar_one_or_none()
        if gasto is None:
            raise ContabilidadValidationError("Gasto no encontrado.")
        if gasto.estado == "anulado":
            raise ContabilidadValidationError("El gasto ya está anulado.")
        if gasto.estado == "pagado":
            raise ContabilidadValidationError(
                "No se puede anular un gasto ya pagado."
            )
        pagos_result = await self.db.execute(
            select(func.count(PagoGasto.id)).where(PagoGasto.gasto_id == gasto_id)
        )
        if pagos_result.scalar_one():
            raise ContabilidadValidationError(
                "No se puede anular un gasto con pagos registrados."
            )
        gasto.estado = "anulado"
        gasto.anulado_en = datetime.now(timezone.utc)
        gasto.anulada_por_usuario_id = usuario_id
        gasto.motivo_anulacion = motivo.strip()
        await self.db.commit()
        return await self.obtener_gasto(gasto_id)

    async def obtener_gasto(self, gasto_id: int) -> dict:
        result = await self.db.execute(
            select(Gasto)
            .options(selectinload(Gasto.pagos))
            .where(Gasto.id == gasto_id)
        )
        gasto = result.scalar_one_or_none()
        if gasto is None:
            raise ContabilidadValidationError("Gasto no encontrado.")
        saldo = max(
            gasto.monto_bob
            - sum((pago.monto_bob for pago in gasto.pagos), Decimal("0")),
            Decimal("0.00"),
        ).quantize(CENTAVO, rounding=ROUND_HALF_UP)
        return {
            "id": gasto.id,
            "categoria": gasto.categoria,
            "categoria_gasto_id": gasto.categoria_gasto_id,
            "concepto": gasto.concepto,
            "proveedor_id": gasto.proveedor_id,
            "usuario_id": gasto.usuario_id,
            "sucursal_id": gasto.sucursal_id,
            "fecha_documento": gasto.fecha_documento,
            "periodo_desde": gasto.periodo_desde,
            "periodo_hasta": gasto.periodo_hasta,
            "numero_documento": gasto.numero_documento,
            "moneda_codigo": gasto.moneda_codigo,
            "monto": gasto.monto,
            "tipo_cambio_ext": gasto.tipo_cambio_ext,
            "tipo_cambio_bob": gasto.tipo_cambio_bob,
            "monto_bob": gasto.monto_bob,
            "saldo_pendiente_bob": saldo,
            "soporte_url": gasto.soporte_url,
            "anulado_en": gasto.anulado_en,
            "anulada_por_usuario_id": gasto.anulada_por_usuario_id,
            "motivo_anulacion": gasto.motivo_anulacion,
            "estado": gasto.estado,
            "fecha_creacion": gasto.fecha_creacion,
            "pagos": gasto.pagos,
        }

    async def listar_gastos(
        self,
        fecha_inicio: date | None = None,
        fecha_fin: date | None = None,
        categoria: str | None = None,
        limite: int = 100,
        sucursal_id: int | None = None,
    ) -> list[dict]:
        query = select(Gasto).options(selectinload(Gasto.pagos)).order_by(
            Gasto.fecha_creacion.desc(), Gasto.id.desc()
        )
        if fecha_inicio:
            query = query.where(
                func.coalesce(
                    Gasto.periodo_desde,
                    Gasto.fecha_documento,
                    cast(Gasto.fecha_creacion, Date),
                )
                >= fecha_inicio
            )
        if fecha_fin:
            query = query.where(
                func.coalesce(
                    Gasto.periodo_desde,
                    Gasto.fecha_documento,
                    cast(Gasto.fecha_creacion, Date),
                )
                <= fecha_fin
            )
        if categoria:
            query = query.where(Gasto.categoria == categoria)
        if sucursal_id is not None:
            query = query.where(Gasto.sucursal_id == sucursal_id)
        result = await self.db.execute(query.limit(limite))
        return [await self.obtener_gasto(gasto.id) for gasto in result.scalars().all()]

    async def reporte_financiero(
        self, fecha_inicio: date, fecha_fin: date, sucursal_id: int | None = None
    ) -> dict:
        """Resultado del período, de una sucursal o de todas (None).

        Ventas, costo y gastos se filtran por sucursal. Los sueldos y bonos son
        del personal, no de un local: solo entran en el reporte de todas las
        sucursales, y la nota lo dice para no inflar la utilidad de un local.
        """
        if fecha_fin < fecha_inicio:
            raise ContabilidadValidationError(
                "La fecha de fin no puede ser anterior a la fecha de inicio."
            )
        inicio_local = datetime.combine(fecha_inicio, time.min, ZONA_NEGOCIO)
        fin_exclusivo = datetime.combine(
            fecha_fin + timedelta(days=1), time.min, ZONA_NEGOCIO
        )
        filtro_venta = [
            Venta.estado == "completada",
            Venta.fecha_creacion >= inicio_local,
            Venta.fecha_creacion < fin_exclusivo,
        ]
        if sucursal_id is not None:
            filtro_venta.append(Venta.sucursal_id == sucursal_id)
        ventas_result = await self.db.execute(
            select(func.coalesce(func.sum(Venta.total), 0)).where(*filtro_venta)
        )
        ventas_netas = Decimal(ventas_result.scalar_one()).quantize(CENTAVO)
        resultado_costos = await self.db.execute(
            select(
                func.coalesce(func.sum(VentaDetalle.costo_total_bob_aplicado), 0),
                func.count(VentaDetalle.id),
                func.count(VentaDetalle.costo_total_bob_aplicado),
            )
            .join(Venta, VentaDetalle.venta_id == Venta.id)
            .where(*filtro_venta)
        )
        costos_suma, total_detalles, detalles_con_costo = resultado_costos.one()
        sin_costo = total_detalles - detalles_con_costo
        costo_completo = sin_costo == 0
        costo_ventas = Decimal(costos_suma).quantize(CENTAVO) if costo_completo else None
        ganancia_bruta = (
            ventas_netas - costo_ventas
            if costo_ventas is not None
            else None
        )

        fecha_gasto = func.coalesce(
            Gasto.periodo_desde,
            Gasto.fecha_documento,
            cast(Gasto.fecha_creacion, Date),
        )
        gastos_result = await self.db.execute(
            select(func.coalesce(func.sum(Gasto.monto_bob), 0)).where(
                Gasto.estado != "anulado",
                fecha_gasto >= fecha_inicio,
                fecha_gasto <= fecha_fin,
                *([Gasto.sucursal_id == sucursal_id] if sucursal_id is not None else []),
            )
        )
        gastos = Decimal(gastos_result.scalar_one()).quantize(CENTAVO)

        liquidaciones_result = await self.db.execute(
            select(LiquidacionSueldo).where(
                LiquidacionSueldo.fecha_inicio <= fecha_fin,
                LiquidacionSueldo.fecha_fin >= fecha_inicio,
            )
        )
        salarios = Decimal("0")
        liquidaciones = list(liquidaciones_result.scalars()) if sucursal_id is None else []
        for liquidacion in liquidaciones:
            dias_periodo = (liquidacion.fecha_fin - liquidacion.fecha_inicio).days + 1
            dias_solapados = (
                min(liquidacion.fecha_fin, fecha_fin)
                - max(liquidacion.fecha_inicio, fecha_inicio)
            ).days + 1
            salarios += (
                liquidacion.total_pagado * Decimal(dias_solapados) / Decimal(dias_periodo)
            )
        salarios = salarios.quantize(CENTAVO, rounding=ROUND_HALF_UP)
        utilidad_operativa = (
            (ganancia_bruta - gastos - salarios).quantize(CENTAVO)
            if ganancia_bruta is not None
            else None
        )
        return {
            "fecha_inicio": fecha_inicio,
            "fecha_fin": fecha_fin,
            "ventas_netas_bob": ventas_netas,
            "costo_ventas_bob": costo_ventas,
            "costo_historico_completo": costo_completo,
            "detalles_sin_costo_historico": sin_costo,
            "ganancia_bruta_bob": ganancia_bruta,
            "gastos_operativos_bob": gastos,
            "sueldos_y_bonos_bob": salarios,
            "utilidad_operativa_bob": utilidad_operativa,
            "cargos_adicionales_bob": Decimal("0.00"),
            "utilidad_neta_estimada_bob": utilidad_operativa,
            "moneda": "BOB",
            "sucursal_id": sucursal_id,
            "nota": (
                "Estimación operativa antes de impuestos y cargos no registrados. "
                "La ganancia bruta solo se informa si todas las ventas del período "
                "tienen costo histórico capturado."
                + (
                    " Los sueldos y bonos son del negocio completo: solo se "
                    "incluyen en el reporte de todas las sucursales."
                    if sucursal_id is not None
                    else ""
                )
            ),
        }
