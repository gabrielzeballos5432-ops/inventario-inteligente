from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db
from app.core.security import get_current_user_id, require_admin
from app.schemas.sueldo import (
    LiquidacionSueldoCreate,
    LiquidacionSueldoOut,
    RegistroHoraManualCreate,
    RegistroHoraOut,
)
from app.services.sueldo_service import SueldoService, SueldoValidationError


router = APIRouter(prefix="/api/sueldos", tags=["Sueldos"])


@router.post("/asistencias/entrada", response_model=RegistroHoraOut, status_code=201)
async def marcar_entrada(
    usuario_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await SueldoService(db).marcar_entrada(usuario_id)
    except SueldoValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/asistencias/salida", response_model=RegistroHoraOut)
async def marcar_salida(
    usuario_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await SueldoService(db).marcar_salida(usuario_id)
    except SueldoValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post(
    "/asistencias/manual",
    response_model=RegistroHoraOut,
    status_code=201,
)
async def registrar_asistencia_manual(
    body: RegistroHoraManualCreate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await SueldoService(db).registrar_manual(body)
    except SueldoValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/asistencias", response_model=list[RegistroHoraOut])
async def listar_asistencias(
    fecha_inicio: date | None = None,
    fecha_fin: date | None = None,
    usuario_id: int | None = Query(default=None, gt=0),
    limite: int = Query(default=100, ge=1, le=500),
    db: AsyncSession = Depends(get_db),
    _: tuple[int, str] = Depends(require_admin),
):
    if fecha_inicio and fecha_fin and fecha_fin < fecha_inicio:
        raise HTTPException(
            status_code=400,
            detail="La fecha de fin no puede ser anterior a la fecha de inicio.",
        )
    return await SueldoService(db).listar_registros(
        fecha_inicio, fecha_fin, usuario_id, limite
    )


@router.post(
    "/asistencias/{registro_id}/confirmar",
    response_model=RegistroHoraOut,
)
async def confirmar_asistencia(
    registro_id: int,
    administrador: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await SueldoService(db).confirmar_registro(
            registro_id, administrador[0]
        )
    except SueldoValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post(
    "/liquidaciones",
    response_model=LiquidacionSueldoOut,
    status_code=201,
)
async def crear_liquidacion(
    body: LiquidacionSueldoCreate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await SueldoService(db).crear_liquidacion(
            body.usuario_id, body.fecha_inicio, body.fecha_fin
        )
    except SueldoValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/liquidaciones", response_model=list[LiquidacionSueldoOut])
async def listar_liquidaciones(
    usuario_id: int | None = Query(default=None, gt=0),
    limite: int = Query(default=100, ge=1, le=500),
    db: AsyncSession = Depends(get_db),
    _: tuple[int, str] = Depends(require_admin),
):
    return await SueldoService(db).listar_liquidaciones(usuario_id, limite)


@router.post(
    "/liquidaciones/{liquidacion_id}/pagar",
    response_model=LiquidacionSueldoOut,
)
async def pagar_liquidacion(
    liquidacion_id: int,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await SueldoService(db).pagar_liquidacion(liquidacion_id)
    except SueldoValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
