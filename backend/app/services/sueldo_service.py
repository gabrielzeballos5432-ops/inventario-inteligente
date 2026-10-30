from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP
from zoneinfo import ZoneInfo

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.sueldo import LiquidacionSueldo, RegistroHora
from app.models.usuario import Usuario
from app.models.venta import Venta
from app.schemas.sueldo import RegistroHoraManualCreate


ZONA_NEGOCIO = ZoneInfo("America/La_Paz")
CENTAVO = Decimal("0.01")
MAXIMO_MONETARIO = Decimal("9999999999.99")
MAXIMO_HORAS = Decimal("999999.99")


class SueldoValidationError(Exception):
    pass


class SueldoService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def _vendedor(
        self,
        usuario_id: int,
        bloquear: bool = False,
        exigir_activo: bool = True,
    ) -> Usuario:
        filtros = [Usuario.id == usuario_id]
        if exigir_activo:
            filtros.append(Usuario.activo.is_(True))
        query = (
            select(Usuario)
            .join(Usuario.rol)
            .options(selectinload(Usuario.rol))
            .where(*filtros)
        )
        if bloquear:
            query = query.with_for_update(of=Usuario)
        result = await self.db.execute(query)
        usuario = result.scalar_one_or_none()
        if usuario is None or usuario.rol.nombre != "vendedor":
            raise SueldoValidationError(
                "El usuario debe existir, estar activo y tener rol vendedor."
            )
        return usuario

    async def _validar_dia_sin_liquidar(
        self, usuario_id: int, fecha: date
    ) -> None:
        result = await self.db.execute(
            select(LiquidacionSueldo.id).where(
                LiquidacionSueldo.usuario_id == usuario_id,
                LiquidacionSueldo.fecha_inicio <= fecha,
                LiquidacionSueldo.fecha_fin >= fecha,
            )
        )
        if result.scalar_one_or_none() is not None:
            raise SueldoValidationError(
                "No se puede modificar una asistencia incluida en una liquidación."
            )

    async def marcar_entrada(self, usuario_id: int) -> RegistroHora:
        await self._vendedor(usuario_id, bloquear=True)
        ahora = datetime.now(ZONA_NEGOCIO)
        fecha_local = ahora.date()
        await self._validar_dia_sin_liquidar(usuario_id, fecha_local)
        existente = await self.db.execute(
            select(RegistroHora).where(
                RegistroHora.usuario_id == usuario_id,
                RegistroHora.fecha == fecha_local,
            )
        )
        if existente.scalar_one_or_none() is not None:
            raise SueldoValidationError(
                "Ya existe un registro de asistencia para el vendedor en esta fecha."
            )
        registro = RegistroHora(
            usuario_id=usuario_id,
            fecha=fecha_local,
            hora_entrada=ahora.time().replace(tzinfo=None, microsecond=0),
        )
        self.db.add(registro)
        await self.db.commit()
        await self.db.refresh(registro)
        return registro

    async def marcar_salida(self, usuario_id: int) -> RegistroHora:
        await self._vendedor(usuario_id, bloquear=True)
        ahora = datetime.now(ZONA_NEGOCIO)
        await self._validar_dia_sin_liquidar(usuario_id, ahora.date())
        result = await self.db.execute(
            select(RegistroHora)
            .where(
                RegistroHora.usuario_id == usuario_id,
                RegistroHora.fecha == ahora.date(),
            )
            .with_for_update()
        )
        registro = result.scalar_one_or_none()
        if registro is None:
            raise SueldoValidationError(
                "No existe una entrada registrada para hoy."
            )
        if registro.hora_salida is not None:
            raise SueldoValidationError(
                "La salida de hoy ya fue registrada."
            )
        hora_salida = ahora.time().replace(tzinfo=None, microsecond=0)
        if hora_salida <= registro.hora_entrada:
            raise SueldoValidationError(
                "La hora de salida debe ser posterior a la entrada."
            )
        registro.hora_salida = hora_salida
        await self.db.commit()
        await self.db.refresh(registro)
        return registro

    async def registrar_manual(
        self, data: RegistroHoraManualCreate
    ) -> RegistroHora:
        await self._vendedor(data.usuario_id, bloquear=True)
        await self._validar_dia_sin_liquidar(data.usuario_id, data.fecha)
        registro = RegistroHora(**data.model_dump())
        self.db.add(registro)
        await self.db.commit()
        await self.db.refresh(registro)
        return registro

    async def confirmar_registro(
        self, registro_id: int, administrador_id: int
    ) -> RegistroHora:
        propietario = await self.db.execute(
            select(RegistroHora.usuario_id).where(RegistroHora.id == registro_id)
        )
        usuario_id = propietario.scalar_one_or_none()
        if usuario_id is None:
            raise SueldoValidationError("Registro de asistencia no encontrado.")
        await self._vendedor(
            usuario_id, bloquear=True, exigir_activo=False
        )
        result = await self.db.execute(
            select(RegistroHora)
            .where(RegistroHora.id == registro_id)
            .with_for_update()
        )
        registro = result.scalar_one_or_none()
        if registro is None:
            raise SueldoValidationError("Registro de asistencia no encontrado.")
        await self._validar_dia_sin_liquidar(registro.usuario_id, registro.fecha)
        if registro.hora_salida is None:
            raise SueldoValidationError(
                "No se puede confirmar una jornada sin hora de salida."
            )
        if registro.confirmado_por_usuario_id is not None:
            raise SueldoValidationError(
                "El registro de asistencia ya fue confirmado."
            )
        registro.confirmado_por_usuario_id = administrador_id
        registro.fecha_confirmacion = datetime.now(timezone.utc)
        await self.db.commit()
        await self.db.refresh(registro)
        return registro

    async def listar_registros(
        self,
        fecha_inicio: date | None = None,
        fecha_fin: date | None = None,
        usuario_id: int | None = None,
        limite: int = 200,
    ) -> list[RegistroHora]:
        query = select(RegistroHora).order_by(
            RegistroHora.fecha.desc(), RegistroHora.usuario_id
        )
        if fecha_inicio is not None:
            query = query.where(RegistroHora.fecha >= fecha_inicio)
        if fecha_fin is not None:
            query = query.where(RegistroHora.fecha <= fecha_fin)
        if usuario_id is not None:
            query = query.where(RegistroHora.usuario_id == usuario_id)
        result = await self.db.execute(query.limit(limite))
        return list(result.scalars().all())

    async def crear_liquidacion(
        self, usuario_id: int, fecha_inicio: date, fecha_fin: date
    ) -> LiquidacionSueldo:
        usuario = await self._vendedor(
            usuario_id, bloquear=True, exigir_activo=False
        )
        if fecha_fin < fecha_inicio:
            raise SueldoValidationError(
                "La fecha de fin no puede ser anterior a la fecha de inicio."
            )
        if usuario.pago_por_hora is None or usuario.porcentaje_comision is None:
            raise SueldoValidationError(
                "Configure el pago por hora y el porcentaje de comisión del vendedor."
            )

        existente = await self.db.execute(
            select(LiquidacionSueldo)
            .where(
                LiquidacionSueldo.usuario_id == usuario_id,
                LiquidacionSueldo.fecha_inicio <= fecha_fin,
                LiquidacionSueldo.fecha_fin >= fecha_inicio,
            )
            .with_for_update()
        )
        if existente.scalar_one_or_none() is not None:
            raise SueldoValidationError(
                "El período se superpone con una liquidación ya registrada."
            )

        registros_result = await self.db.execute(
            select(RegistroHora).where(
                RegistroHora.usuario_id == usuario_id,
                RegistroHora.fecha >= fecha_inicio,
                RegistroHora.fecha <= fecha_fin,
            )
        )
        registros = list(registros_result.scalars().all())
        horas = Decimal("0")
        for registro in registros:
            if registro.hora_salida is None or registro.fecha_confirmacion is None:
                raise SueldoValidationError(
                    "El período contiene asistencias incompletas o sin confirmar."
                )
            inicio = datetime.combine(registro.fecha, registro.hora_entrada)
            fin = datetime.combine(registro.fecha, registro.hora_salida)
            horas += Decimal(str((fin - inicio).total_seconds())) / Decimal("3600")
        horas = horas.quantize(CENTAVO, rounding=ROUND_HALF_UP)

        inicio_local = datetime.combine(fecha_inicio, time.min, ZONA_NEGOCIO)
        fin_exclusivo = datetime.combine(
            fecha_fin + timedelta(days=1), time.min, ZONA_NEGOCIO
        )
        ventas_result = await self.db.execute(
            select(func.coalesce(func.sum(Venta.total), 0)).where(
                Venta.usuario_id == usuario_id,
                Venta.estado == "completada",
                Venta.fecha_creacion >= inicio_local,
                Venta.fecha_creacion < fin_exclusivo,
            )
        )
        total_ventas = Decimal(ventas_result.scalar_one())
        total_pago_horas = (horas * usuario.pago_por_hora).quantize(
            CENTAVO, rounding=ROUND_HALF_UP
        )
        total_comision = (
            total_ventas * usuario.porcentaje_comision / Decimal("100")
        ).quantize(CENTAVO, rounding=ROUND_HALF_UP)
        total_pagado = total_pago_horas + total_comision
        if (
            horas > MAXIMO_HORAS
            or total_pago_horas > MAXIMO_MONETARIO
            or total_comision > MAXIMO_MONETARIO
            or total_pagado > MAXIMO_MONETARIO
        ):
            raise SueldoValidationError(
                "El cálculo supera la capacidad monetaria o de horas permitida."
            )
        if not registros and total_ventas == 0:
            raise SueldoValidationError(
                "No hay asistencias ni ventas del vendedor en el período."
            )

        liquidacion = LiquidacionSueldo(
            usuario_id=usuario_id,
            fecha_inicio=fecha_inicio,
            fecha_fin=fecha_fin,
            horas_trabajadas=horas,
            pago_por_hora_aplicado=usuario.pago_por_hora,
            porcentaje_comision_aplicado=usuario.porcentaje_comision,
            total_pago_horas=total_pago_horas,
            total_comision=total_comision,
            total_bonos=Decimal("0.00"),
            total_pagado=total_pagado,
            estado="pendiente",
        )
        self.db.add(liquidacion)
        await self.db.commit()
        await self.db.refresh(liquidacion)
        return liquidacion

    async def pagar_liquidacion(self, liquidacion_id: int) -> LiquidacionSueldo:
        result = await self.db.execute(
            select(LiquidacionSueldo)
            .where(LiquidacionSueldo.id == liquidacion_id)
            .with_for_update()
        )
        liquidacion = result.scalar_one_or_none()
        if liquidacion is None:
            raise SueldoValidationError("Liquidación no encontrada.")
        if liquidacion.estado != "pendiente":
            raise SueldoValidationError("La liquidación ya fue pagada.")
        liquidacion.estado = "pagado"
        liquidacion.fecha_pago = datetime.now(timezone.utc)
        await self.db.commit()
        await self.db.refresh(liquidacion)
        return liquidacion

    async def listar_liquidaciones(
        self, usuario_id: int | None = None, limite: int = 100
    ) -> list[LiquidacionSueldo]:
        query = select(LiquidacionSueldo).order_by(
            LiquidacionSueldo.creado_en.desc(), LiquidacionSueldo.id.desc()
        )
        if usuario_id is not None:
            query = query.where(LiquidacionSueldo.usuario_id == usuario_id)
        result = await self.db.execute(query.limit(limite))
        return list(result.scalars().all())
