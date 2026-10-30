from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db
from app.core.security import get_current_user_id, require_admin
from app.schemas.compra import (
    CompraCreate,
    CompraOut,
    MonedaCreate,
    MonedaEstadoUpdate,
    MonedaOut,
)
from app.services.compra_service import CompraService, CompraValidationError


compras_router = APIRouter(prefix="/api/compras", tags=["Compras"])
monedas_router = APIRouter(prefix="/api/monedas", tags=["Monedas"])


@monedas_router.get("/", response_model=list[MonedaOut])
async def listar_monedas(
    incluir_inactivas: bool = Query(default=False),
    db: AsyncSession = Depends(get_db),
    _: int = Depends(get_current_user_id),
):
    return await CompraService(db).listar_monedas(incluir_inactivas)


@monedas_router.post("/", response_model=MonedaOut, status_code=201)
async def crear_moneda(
    body: MonedaCreate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await CompraService(db).crear_moneda(body)
    except CompraValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@monedas_router.patch("/{codigo}/estado", response_model=MonedaOut)
async def actualizar_estado_moneda(
    codigo: str,
    body: MonedaEstadoUpdate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await CompraService(db).actualizar_estado_moneda(
            codigo.upper(), body.activa
        )
    except CompraValidationError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@compras_router.post("/", response_model=CompraOut, status_code=201)
async def registrar_compra(
    body: CompraCreate,
    current_user: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await CompraService(db).registrar(body, current_user[0])
    except CompraValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@compras_router.get("/", response_model=list[CompraOut])
async def listar_compras(
    limite: int = Query(default=50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    _: tuple[int, str] = Depends(require_admin),
):
    return await CompraService(db).listar(limite)


@compras_router.get("/{compra_id}", response_model=CompraOut)
async def obtener_compra(
    compra_id: int,
    db: AsyncSession = Depends(get_db),
    _: tuple[int, str] = Depends(require_admin),
):
    try:
        return await CompraService(db).obtener(compra_id)
    except CompraValidationError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
