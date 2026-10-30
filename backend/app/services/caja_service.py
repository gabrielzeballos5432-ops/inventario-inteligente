from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.caja import Cliente, SesionCaja
from app.models.contabilidad import PagoGasto
from app.models.venta import PagoVenta, Venta
from app.models.usuario import Usuario
from app.schemas.caja import ClienteCreate, SesionCajaAbrir, SesionCajaCerrar


CENTAVO = Decimal("0.01")


class CajaValidationError(Exception):
    pass


class CajaService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def abrir(self, usuario_id: int, data: SesionCajaAbrir) -> SesionCaja:
        usuario = await self.db.get(Usuario, usuario_id)
        if usuario is None or not usuario.activo:
            raise CajaValidationError("El usuario no existe o está inactivo.")
        result = await self.db.execute(
            select(SesionCaja).where(
                SesionCaja.usuario_apertura_id == usuario_id,
                SesionCaja.estado == "abierta",
            )
        )
        if result.scalar_one_or_none() is not None:
            raise CajaValidationError("Ya tienes una sesión de caja abierta.")
        sesion = SesionCaja(
            usuario_apertura_id=usuario_id,
            monto_inicial=data.monto_inicial,
            estado="abierta",
        )
        self.db.add(sesion)
        await self.db.commit()
        await self.db.refresh(sesion)
        return sesion

    async def cerrar(
        self, usuario_id: int, data: SesionCajaCerrar
    ) -> dict:
        result = await self.db.execute(
            select(SesionCaja)
            .where(
                SesionCaja.usuario_apertura_id == usuario_id,
                SesionCaja.estado == "abierta",
            )
            .with_for_update()
        )
        sesion = result.scalar_one_or_none()
        if sesion is None:
            raise CajaValidationError("No tienes una sesión de caja abierta.")

        ingresos = await self.db.execute(
            select(func.coalesce(func.sum(PagoVenta.monto), 0))
            .join(PagoVenta.venta)
            .where(
                PagoVenta.sesion_caja_id == sesion.id,
                PagoVenta.metodo_pago == "efectivo",
                PagoVenta.estado == "confirmado",
                Venta.estado == "completada",
            )
        )
        egresos = await self.db.execute(
            select(func.coalesce(func.sum(PagoGasto.monto_bob), 0)).where(
                PagoGasto.sesion_caja_id == sesion.id,
                PagoGasto.metodo_pago == "efectivo",
            )
        )
        esperado = (
            sesion.monto_inicial
            + Decimal(ingresos.scalar_one())
            - Decimal(egresos.scalar_one())
        ).quantize(CENTAVO, rounding=ROUND_HALF_UP)
        if esperado < 0:
            raise CajaValidationError(
                "Los egresos en efectivo superan el efectivo inicial y los ingresos."
            )

        sesion.monto_esperado_cierre = esperado
        sesion.monto_efectivo_contado = data.monto_efectivo_contado
        sesion.observacion_cierre = data.observacion_cierre
        sesion.usuario_cierre_id = usuario_id
        sesion.fecha_cierre = datetime.now(timezone.utc)
        sesion.estado = "cerrada"
        await self.db.commit()
        await self.db.refresh(sesion)
        return self._salida(sesion)

    @staticmethod
    def _salida(sesion: SesionCaja) -> dict:
        diferencia = None
        if (
            sesion.monto_esperado_cierre is not None
            and sesion.monto_efectivo_contado is not None
        ):
            diferencia = (
                sesion.monto_efectivo_contado - sesion.monto_esperado_cierre
            ).quantize(CENTAVO, rounding=ROUND_HALF_UP)
        return {
            "id": sesion.id,
            "usuario_apertura_id": sesion.usuario_apertura_id,
            "usuario_cierre_id": sesion.usuario_cierre_id,
            "fecha_apertura": sesion.fecha_apertura,
            "fecha_cierre": sesion.fecha_cierre,
            "monto_inicial": sesion.monto_inicial,
            "monto_esperado_cierre": sesion.monto_esperado_cierre,
            "monto_efectivo_contado": sesion.monto_efectivo_contado,
            "monto_diferencia_cierre": diferencia,
            "observacion_cierre": sesion.observacion_cierre,
            "estado": sesion.estado,
        }

    async def listar(self, limite: int = 100) -> list[dict]:
        result = await self.db.execute(
            select(SesionCaja)
            .order_by(SesionCaja.fecha_apertura.desc(), SesionCaja.id.desc())
            .limit(limite)
        )
        return [self._salida(sesion) for sesion in result.scalars().all()]

    async def obtener_abierta(self, usuario_id: int) -> dict | None:
        result = await self.db.execute(
            select(SesionCaja).where(
                SesionCaja.usuario_apertura_id == usuario_id,
                SesionCaja.estado == "abierta",
            )
        )
        sesion = result.scalar_one_or_none()
        return self._salida(sesion) if sesion is not None else None

    async def crear_cliente(self, data: ClienteCreate) -> Cliente:
        cliente = Cliente(**data.model_dump(), activo=True)
        self.db.add(cliente)
        await self.db.commit()
        await self.db.refresh(cliente)
        return cliente

    async def listar_clientes(self, texto: str | None = None) -> list[Cliente]:
        query = select(Cliente).where(Cliente.activo.is_(True)).order_by(Cliente.nombre)
        if texto:
            query = query.where(Cliente.nombre.ilike(f"%{texto}%"))
        result = await self.db.execute(query.limit(200))
        return list(result.scalars().all())

    async def validar_caja_venta(
        self, usuario_id: int, sesion_caja_id: int
    ) -> SesionCaja:
        result = await self.db.execute(
            select(SesionCaja)
            .where(
                SesionCaja.id == sesion_caja_id,
                SesionCaja.usuario_apertura_id == usuario_id,
                SesionCaja.estado == "abierta",
            )
            .with_for_update()
        )
        sesion = result.scalar_one_or_none()
        if sesion is None:
            raise CajaValidationError(
                "La sesión de caja no existe, no está abierta o no pertenece al usuario."
            )
        return sesion
