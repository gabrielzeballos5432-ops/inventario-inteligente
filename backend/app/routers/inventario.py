from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db
from app.core.security import get_current_user_id
from app.core.sucursal import get_sucursal_activa
from app.repositories.producto_repository import ProductoRepository
from app.repositories.movimiento_repository import MovimientoRepository
from app.services.inventario_service import InventarioService, MovimientoValidationError
from app.yolo.inference_service import InferenceService
from app.schemas.producto import ProductoStockOut
from app.schemas.movimiento import (
    MovimientoCreate,
    MovimientoLoteCreate,
    MovimientoLoteOut,
    MovimientoOut,
)

router = APIRouter(prefix="/api/inventario", tags=["Inventario"])


def _servicio(db: AsyncSession) -> InventarioService:
    return InventarioService(
        ProductoRepository(db), MovimientoRepository(db), InferenceService()
    )


@router.get("/", response_model=list[ProductoStockOut])
async def obtener_inventario(
    db: AsyncSession = Depends(get_db),
    _: int = Depends(get_current_user_id),
    sucursal_id: int = Depends(get_sucursal_activa),
):
    """Productos con su stock en la sucursal activa."""
    return await _servicio(db).obtener_inventario(sucursal_id)


@router.get("/historial", response_model=list[MovimientoOut])
async def obtener_historial(
    limite: int = 50,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(get_current_user_id),
    sucursal_id: int = Depends(get_sucursal_activa),
):
    """Últimos movimientos de la sucursal activa."""
    return await _servicio(db).obtener_historial(limite, sucursal_id)


@router.get("/stock-bajo", response_model=list[ProductoStockOut])
async def obtener_stock_bajo(
    db: AsyncSession = Depends(get_db),
    _: int = Depends(get_current_user_id),
    sucursal_id: int = Depends(get_sucursal_activa),
):
    inventario = await _servicio(db).obtener_inventario(sucursal_id)
    return [p for p in inventario if p.stock_bajo]


@router.post("/movimiento", response_model=MovimientoOut, status_code=201)
async def registrar_movimiento(
    body: MovimientoCreate,
    db: AsyncSession = Depends(get_db),
    usuario_id: int = Depends(get_current_user_id),
    sucursal_id: int = Depends(get_sucursal_activa),
):
    try:
        return await _servicio(db).registrar_movimiento(
            producto_id=body.producto_id,
            tipo=body.tipo,
            cantidad=body.cantidad,
            usuario_id=usuario_id,
            sucursal_id=sucursal_id,
            origen=body.origen,
            sesion_id=body.sesion_id,
            razon_movimiento_id=body.razon_movimiento_id,
            sucursal_destino_id=body.sucursal_destino_id,
        )
    except MovimientoValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/movimientos/lote", response_model=MovimientoLoteOut, status_code=201)
async def registrar_movimientos_lote(
    body: MovimientoLoteCreate,
    db: AsyncSession = Depends(get_db),
    usuario_id: int = Depends(get_current_user_id),
    sucursal_id: int = Depends(get_sucursal_activa),
):
    """Varios movimientos del mismo tipo en una sola llamada.

    La recepcion de mercaderia (y el conteo fisico, y la venta de varios
    productos) no deja de ser un documento: si una linea falla no se guarda
    ninguna y el 400 trae el detalle de cada fila, listo para mostrarse. Es
    tambien el nucleo que usara el reconocimiento (RF-10), que registra las
    entradas detectadas en una unica captura.
    """
    try:
        resultados, movimientos = await _servicio(db).registrar_lote(
            tipo=body.tipo,
            items=body.items,
            usuario_id=usuario_id,
            sucursal_id=sucursal_id,
            origen=body.origen,
            sesion_id=body.sesion_id,
            razon_movimiento_id=body.razon_movimiento_id,
            sucursal_destino_id=body.sucursal_destino_id,
        )
    except MovimientoValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    errores = "\n".join(
        resultado.detalle for resultado in resultados if not resultado.correcto
    )
    if errores:
        raise HTTPException(status_code=400, detail=errores)

    return MovimientoLoteOut(
        tipo=body.tipo,
        guardados=len(movimientos),
        resultados=resultados,
    )
