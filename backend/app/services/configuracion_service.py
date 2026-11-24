from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.razon_movimiento import RazonMovimiento
from app.models.sucursal import ConfiguracionSistema, Sucursal
from app.schemas.configuracion import (
    ConfiguracionOut,
    RazonMovimientoCreate,
    RazonMovimientoUpdate,
    SucursalCreate,
    SucursalOut,
    SucursalUpdate,
)


class ConfiguracionValidationError(Exception):
    pass


class ConfiguracionService:
    """Sucursales, sucursal predeterminada y razones de movimiento."""

    def __init__(self, db: AsyncSession):
        self.db = db

    # --- Sucursales -------------------------------------------------------

    async def _predeterminada_id(self) -> int | None:
        resultado = await self.db.execute(
            select(ConfiguracionSistema.sucursal_predeterminada_id).where(
                ConfiguracionSistema.id == 1
            )
        )
        return resultado.scalar_one_or_none()

    def _sucursal_out(self, sucursal: Sucursal, predeterminada_id: int | None) -> SucursalOut:
        salida = SucursalOut.model_validate(sucursal)
        salida.predeterminada = sucursal.id == predeterminada_id
        return salida

    async def listar_sucursales(self, incluir_inactivas: bool = False) -> list[SucursalOut]:
        query = select(Sucursal).order_by(Sucursal.nombre)
        if not incluir_inactivas:
            query = query.where(Sucursal.activo.is_(True))
        resultado = await self.db.execute(query)
        predeterminada_id = await self._predeterminada_id()
        return [self._sucursal_out(s, predeterminada_id) for s in resultado.scalars()]

    async def _sucursal_por_nombre(self, nombre: str) -> Sucursal | None:
        resultado = await self.db.execute(
            select(Sucursal).where(func.lower(Sucursal.nombre) == nombre.lower())
        )
        return resultado.scalar_one_or_none()

    async def crear_sucursal(self, data: SucursalCreate) -> SucursalOut:
        existente = await self._sucursal_por_nombre(data.nombre)
        if existente is not None:
            if existente.activo:
                raise ConfiguracionValidationError(
                    "Ya existe una sucursal con ese nombre."
                )
            # Igual que en categorías: el nombre de una sucursal desactivada
            # sigue reservado, así que volver a crearla la reactiva.
            existente.activo = True
            existente.direccion = data.direccion
            existente.telefono = data.telefono
            sucursal = existente
        else:
            sucursal = Sucursal(**data.model_dump(), activo=True)
            self.db.add(sucursal)
        await self.db.commit()
        await self.db.refresh(sucursal)
        return self._sucursal_out(sucursal, await self._predeterminada_id())

    async def actualizar_sucursal(self, sucursal_id: int, data: SucursalUpdate) -> SucursalOut:
        sucursal = await self.db.get(Sucursal, sucursal_id)
        if sucursal is None:
            raise ConfiguracionValidationError("Sucursal no encontrada.")
        cambios = data.model_dump(exclude_unset=True)
        if "nombre" in cambios and cambios["nombre"].lower() != sucursal.nombre.lower():
            otra = await self._sucursal_por_nombre(cambios["nombre"])
            if otra is not None and otra.id != sucursal.id:
                raise ConfiguracionValidationError(
                    "Ya existe una sucursal con ese nombre."
                )
        predeterminada_id = await self._predeterminada_id()
        if cambios.get("activo") is False and sucursal.id == predeterminada_id:
            raise ConfiguracionValidationError(
                "No se puede desactivar la sucursal predeterminada. "
                "Elige otra predeterminada en Configuración primero."
            )
        for campo, valor in cambios.items():
            setattr(sucursal, campo, valor)
        await self.db.commit()
        await self.db.refresh(sucursal)
        return self._sucursal_out(sucursal, predeterminada_id)

    # --- Configuración ----------------------------------------------------

    async def obtener_configuracion(self) -> ConfiguracionOut:
        config = await self.db.get(ConfiguracionSistema, 1)
        if config is None:
            raise ConfiguracionValidationError(
                "No hay una sucursal predeterminada configurada."
            )
        sucursal = await self.db.get(Sucursal, config.sucursal_predeterminada_id)
        return ConfiguracionOut(
            sucursal_predeterminada_id=config.sucursal_predeterminada_id,
            sucursal_predeterminada=self._sucursal_out(
                sucursal, config.sucursal_predeterminada_id
            ),
            actualizado_en=config.actualizado_en,
        )

    async def definir_sucursal_predeterminada(self, sucursal_id: int) -> ConfiguracionOut:
        sucursal = await self.db.get(Sucursal, sucursal_id)
        if sucursal is None or not sucursal.activo:
            raise ConfiguracionValidationError(
                "La sucursal no existe o está desactivada."
            )
        config = await self.db.get(ConfiguracionSistema, 1)
        if config is None:
            config = ConfiguracionSistema(id=1, sucursal_predeterminada_id=sucursal_id)
            self.db.add(config)
        else:
            config.sucursal_predeterminada_id = sucursal_id
        await self.db.commit()
        await self.db.refresh(config)
        return await self.obtener_configuracion()

    # --- Razones de movimiento --------------------------------------------

    async def listar_razones(
        self,
        tipo: str | None = None,
        incluir_inactivas: bool = False,
        incluir_sistema: bool = False,
    ) -> list[RazonMovimiento]:
        query = select(RazonMovimiento).order_by(
            RazonMovimiento.tipo_movimiento, RazonMovimiento.id
        )
        if tipo is not None:
            query = query.where(RazonMovimiento.tipo_movimiento == tipo)
        if not incluir_inactivas:
            query = query.where(RazonMovimiento.activo.is_(True))
        if not incluir_sistema:
            query = query.where(RazonMovimiento.sistema.is_(False))
        resultado = await self.db.execute(query)
        return list(resultado.scalars())

    async def _razon_por_nombre(self, nombre: str, tipo: str) -> RazonMovimiento | None:
        resultado = await self.db.execute(
            select(RazonMovimiento).where(
                func.lower(RazonMovimiento.nombre) == nombre.lower(),
                RazonMovimiento.tipo_movimiento == tipo,
            )
        )
        return resultado.scalar_one_or_none()

    @staticmethod
    def _validar_destino(tipo: str, requiere_destino: bool) -> None:
        if requiere_destino and tipo != "salida":
            raise ConfiguracionValidationError(
                "Solo una razón de salida puede enviar mercadería a otra sucursal."
            )

    async def crear_razon(self, data: RazonMovimientoCreate) -> RazonMovimiento:
        self._validar_destino(data.tipo_movimiento, data.requiere_sucursal_destino)
        existente = await self._razon_por_nombre(data.nombre, data.tipo_movimiento)
        if existente is not None:
            if existente.activo or existente.sistema:
                raise ConfiguracionValidationError(
                    f"Ya existe la razón '{existente.nombre}' para {data.tipo_movimiento}."
                )
            existente.activo = True
            existente.requiere_sucursal_destino = data.requiere_sucursal_destino
            razon = existente
        else:
            razon = RazonMovimiento(**data.model_dump(), sistema=False, activo=True)
            self.db.add(razon)
        await self.db.commit()
        await self.db.refresh(razon)
        return razon

    async def actualizar_razon(
        self, razon_id: int, data: RazonMovimientoUpdate
    ) -> RazonMovimiento:
        razon = await self.db.get(RazonMovimiento, razon_id)
        if razon is None:
            raise ConfiguracionValidationError("Razón no encontrada.")
        if razon.sistema:
            raise ConfiguracionValidationError(
                "Las razones del sistema se asignan solas y no se pueden modificar."
            )
        cambios = data.model_dump(exclude_unset=True)
        if "requiere_sucursal_destino" in cambios:
            self._validar_destino(razon.tipo_movimiento, cambios["requiere_sucursal_destino"])
        if "nombre" in cambios and cambios["nombre"].lower() != razon.nombre.lower():
            otra = await self._razon_por_nombre(cambios["nombre"], razon.tipo_movimiento)
            if otra is not None and otra.id != razon.id:
                raise ConfiguracionValidationError(
                    f"Ya existe la razón '{otra.nombre}' para {razon.tipo_movimiento}."
                )
        for campo, valor in cambios.items():
            setattr(razon, campo, valor)
        await self.db.commit()
        await self.db.refresh(razon)
        return razon
