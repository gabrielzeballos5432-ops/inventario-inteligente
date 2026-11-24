from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db
from app.core.security import get_current_user_id, require_admin
from app.schemas.configuracion import (
    ConfiguracionOut,
    ConfiguracionUpdate,
    RazonMovimientoCreate,
    RazonMovimientoOut,
    RazonMovimientoUpdate,
    SucursalCreate,
    SucursalOut,
    SucursalUpdate,
)
from app.services.configuracion_service import (
    ConfiguracionService,
    ConfiguracionValidationError,
)

sucursales_router = APIRouter(prefix="/api/sucursales", tags=["Sucursales"])
configuracion_router = APIRouter(prefix="/api/configuracion", tags=["Configuración"])
razones_router = APIRouter(
    prefix="/api/razones-movimiento", tags=["Razones de movimiento"]
)


def _error(exc: ConfiguracionValidationError) -> HTTPException:
    mensaje = str(exc)
    codigo = 404 if "no encontrada" in mensaje.lower() else 400
    return HTTPException(status_code=codigo, detail=mensaje)


@sucursales_router.get("/", response_model=list[SucursalOut])
async def listar_sucursales(
    incluir_inactivas: bool = False,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(get_current_user_id),
):
    return await ConfiguracionService(db).listar_sucursales(incluir_inactivas)


@sucursales_router.post("/", response_model=SucursalOut, status_code=201)
async def crear_sucursal(
    body: SucursalCreate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await ConfiguracionService(db).crear_sucursal(body)
    except ConfiguracionValidationError as exc:
        raise _error(exc) from exc


@sucursales_router.put("/{sucursal_id}", response_model=SucursalOut)
async def actualizar_sucursal(
    sucursal_id: int,
    body: SucursalUpdate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await ConfiguracionService(db).actualizar_sucursal(sucursal_id, body)
    except ConfiguracionValidationError as exc:
        raise _error(exc) from exc


@configuracion_router.get("/", response_model=ConfiguracionOut)
async def obtener_configuracion(
    db: AsyncSession = Depends(get_db),
    _: int = Depends(get_current_user_id),
):
    try:
        return await ConfiguracionService(db).obtener_configuracion()
    except ConfiguracionValidationError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@configuracion_router.put("/", response_model=ConfiguracionOut)
async def actualizar_configuracion(
    body: ConfiguracionUpdate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await ConfiguracionService(db).definir_sucursal_predeterminada(
            body.sucursal_predeterminada_id
        )
    except ConfiguracionValidationError as exc:
        raise _error(exc) from exc


@razones_router.get("/", response_model=list[RazonMovimientoOut])
async def listar_razones(
    tipo: str | None = Query(default=None, pattern="^(entrada|salida|ajuste)$"),
    incluir_inactivas: bool = False,
    incluir_sistema: bool = False,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(get_current_user_id),
):
    return await ConfiguracionService(db).listar_razones(
        tipo, incluir_inactivas, incluir_sistema
    )


@razones_router.post("/", response_model=RazonMovimientoOut, status_code=201)
async def crear_razon(
    body: RazonMovimientoCreate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await ConfiguracionService(db).crear_razon(body)
    except ConfiguracionValidationError as exc:
        raise _error(exc) from exc


@razones_router.put("/{razon_id}", response_model=RazonMovimientoOut)
async def actualizar_razon(
    razon_id: int,
    body: RazonMovimientoUpdate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await ConfiguracionService(db).actualizar_razon(razon_id, body)
    except ConfiguracionValidationError as exc:
        raise _error(exc) from exc
