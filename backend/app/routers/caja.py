from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db
from app.core.security import get_current_user_id, require_admin
from app.schemas.caja import (
    ClienteCreate,
    ClienteOut,
    SesionCajaAbrir,
    SesionCajaCerrar,
    SesionCajaOut,
)
from app.services.caja_service import CajaService, CajaValidationError


caja_router = APIRouter(prefix="/api/caja", tags=["Caja"])
clientes_router = APIRouter(prefix="/api/clientes", tags=["Clientes"])


@caja_router.post("/sesiones/abrir", response_model=SesionCajaOut, status_code=201)
async def abrir_sesion(
    body: SesionCajaAbrir,
    usuario_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await CajaService(db).abrir(usuario_id, body)
    except CajaValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@caja_router.post("/sesiones/cerrar", response_model=SesionCajaOut)
async def cerrar_sesion(
    body: SesionCajaCerrar,
    usuario_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await CajaService(db).cerrar(usuario_id, body)
    except CajaValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@caja_router.get("/sesiones", response_model=list[SesionCajaOut])
async def listar_sesiones(
    limite: int = Query(default=50, ge=1, le=200),
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await CajaService(db).listar(limite)


@caja_router.get("/sesiones/actual", response_model=SesionCajaOut | None)
async def obtener_sesion_actual(
    usuario_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    return await CajaService(db).obtener_abierta(usuario_id)


@clientes_router.get("/", response_model=list[ClienteOut])
async def listar_clientes(
    texto: str | None = None,
    _: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    return await CajaService(db).listar_clientes(texto)


@clientes_router.post("/", response_model=ClienteOut, status_code=201)
async def crear_cliente(
    body: ClienteCreate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await CajaService(db).crear_cliente(body)
