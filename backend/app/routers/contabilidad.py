from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db
from app.core.security import require_admin
from app.schemas.contabilidad import (
    BonoSueldoCreate,
    BonoSueldoOut,
    CategoriaGastoCreate,
    CategoriaGastoUpdate,
    CategoriaGastoOut,
    GastoAnular,
    GastoCreate,
    GastoOut,
    PagoGastoCreate,
    PagoGastoOut,
    PagoGastoMixtoCreate,
    ReporteFinancieroOut,
)
from app.services.contabilidad_service import (
    ContabilidadService,
    ContabilidadValidationError,
)


router = APIRouter(prefix="/api/contabilidad", tags=["Contabilidad"])


@router.get("/categorias-gasto", response_model=list[CategoriaGastoOut])
async def listar_categorias_gasto(
    incluir_inactivas: bool = False,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await ContabilidadService(db).listar_categorias_gasto(incluir_inactivas)


@router.post("/categorias-gasto", response_model=CategoriaGastoOut, status_code=201)
async def crear_categoria_gasto(
    body: CategoriaGastoCreate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await ContabilidadService(db).guardar_categoria_gasto(body)
    except ContabilidadValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.put("/categorias-gasto/{categoria_id}", response_model=CategoriaGastoOut)
async def actualizar_categoria_gasto(
    categoria_id: int, body: CategoriaGastoUpdate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await ContabilidadService(db).guardar_categoria_gasto(body, categoria_id)
    except ContabilidadValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.delete("/categorias-gasto/{categoria_id}", status_code=204)
async def eliminar_categoria_gasto(
    categoria_id: int,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        await ContabilidadService(db).eliminar_categoria_gasto(categoria_id)
    except ContabilidadValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/bonos", response_model=BonoSueldoOut, status_code=201)
async def registrar_bono(
    body: BonoSueldoCreate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await ContabilidadService(db).registrar_bono(body)
    except ContabilidadValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/bonos", response_model=list[BonoSueldoOut])
async def listar_bonos(
    usuario_id: int | None = Query(default=None, gt=0),
    limite: int = Query(default=100, ge=1, le=500),
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await ContabilidadService(db).listar_bonos(usuario_id, limite)


@router.post(
    "/bonos/{bono_id}/asignar/{liquidacion_id}",
    response_model=BonoSueldoOut,
)
async def asignar_bono(
    bono_id: int,
    liquidacion_id: int,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await ContabilidadService(db).asignar_bono(bono_id, liquidacion_id)
    except ContabilidadValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/gastos", response_model=GastoOut, status_code=201)
async def registrar_gasto(
    body: GastoCreate,
    administrador: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await ContabilidadService(db).registrar_gasto(
            body, administrador[0]
        )
    except ContabilidadValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/gastos", response_model=list[GastoOut])
async def listar_gastos(
    fecha_inicio: date | None = None,
    fecha_fin: date | None = None,
    categoria: str | None = None,
    limite: int = Query(default=100, ge=1, le=500),
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    if fecha_inicio and fecha_fin and fecha_fin < fecha_inicio:
        raise HTTPException(status_code=400, detail="Rango de fechas inválido.")
    return await ContabilidadService(db).listar_gastos(
        fecha_inicio, fecha_fin, categoria, limite
    )


@router.get("/gastos/{gasto_id}", response_model=GastoOut)
async def obtener_gasto(
    gasto_id: int,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await ContabilidadService(db).obtener_gasto(gasto_id)
    except ContabilidadValidationError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/gastos/{gasto_id}/anular", response_model=GastoOut)
async def anular_gasto(
    gasto_id: int,
    body: GastoAnular,
    administrador: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await ContabilidadService(db).anular_gasto(
            gasto_id, administrador[0], body.motivo
        )
    except ContabilidadValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post(
    "/gastos/{gasto_id}/pagos",
    response_model=PagoGastoOut,
    status_code=201,
)
async def registrar_pago_gasto(
    gasto_id: int,
    body: PagoGastoCreate,
    administrador: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await ContabilidadService(db).registrar_pago_gasto(
            gasto_id, body, administrador[0]
        )
    except ContabilidadValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/gastos/{gasto_id}/pagos/mixto", response_model=list[PagoGastoOut], status_code=201)
async def registrar_pagos_gasto(
    gasto_id: int,
    body: PagoGastoMixtoCreate,
    administrador: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await ContabilidadService(db).registrar_pagos_gasto(
            gasto_id, body.pagos, administrador[0]
        )
    except ContabilidadValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/reporte-financiero", response_model=ReporteFinancieroOut)
async def reporte_financiero(
    fecha_inicio: date,
    fecha_fin: date,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await ContabilidadService(db).reporte_financiero(
            fecha_inicio, fecha_fin
        )
    except ContabilidadValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
