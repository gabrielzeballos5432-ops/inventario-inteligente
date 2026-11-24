from fastapi import APIRouter, Depends, Header, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db
from app.core.security import get_current_user_id, require_admin
from app.core.sucursal import get_sucursal_activa
from app.schemas.venta import VentaAnular, VentaCreate, VentaOut
from app.services.venta_service import VentaService, VentaValidationError


router = APIRouter(prefix="/api/ventas", tags=["Ventas"])


@router.post("/", response_model=VentaOut, status_code=201)
async def registrar_venta(
    body: VentaCreate,
    db: AsyncSession = Depends(get_db),
    usuario_id: int = Depends(get_current_user_id),
    clave_idempotencia: str | None = Header(default=None, alias="Idempotency-Key"),
    sucursal_id: int = Depends(get_sucursal_activa),
):
    try:
        return await VentaService(db).registrar(
            body, usuario_id, clave_idempotencia, sucursal_id=sucursal_id
        )
    except VentaValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/", response_model=list[VentaOut])
async def listar_ventas(
    limite: int = Query(default=50, ge=1, le=200),
    sucursal_id: int | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    _: int = Depends(get_current_user_id),
):
    """Ventas recientes; `sucursal_id` filtra por sucursal (sin él, todas)."""
    return await VentaService(db).listar(limite, sucursal_id)


@router.post("/{venta_id}/anular", response_model=VentaOut)
async def anular_venta(
    venta_id: int,
    body: VentaAnular,
    administrador: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await VentaService(db).anular(
            venta_id, administrador[0], body.motivo
        )
    except VentaValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
