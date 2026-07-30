from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db
from app.core.security import get_current_user_id
from app.repositories.producto_repository import ProductoRepository
from app.repositories.movimiento_repository import MovimientoRepository
from app.services.inventario_service import InventarioService
from app.yolo.inference_service import InferenceService
from app.schemas.producto import ProductoStockOut
from app.schemas.movimiento import MovimientoOut

router = APIRouter(prefix="/api/inventario", tags=["Inventario"])


@router.get("/", response_model=list[ProductoStockOut])
async def obtener_inventario(
    db: AsyncSession = Depends(get_db),
    usuario_id: int = Depends(get_current_user_id),
):
    producto_repo = ProductoRepository(db)
    movimiento_repo = MovimientoRepository(db)
    service = InventarioService(
        producto_repo, movimiento_repo, InferenceService()
    )
    return await service.obtener_inventario()


@router.get("/historial", response_model=list[MovimientoOut])
async def obtener_historial(
    limite: int = 50,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(get_current_user_id),
):
    producto_repo = ProductoRepository(db)
    movimiento_repo = MovimientoRepository(db)
    service = InventarioService(
        producto_repo, movimiento_repo, InferenceService()
    )
    return await service.obtener_historial(limite)


@router.get("/stock-bajo", response_model=list[ProductoStockOut])
async def obtener_stock_bajo(
    db: AsyncSession = Depends(get_db),
    usuario_id: int = Depends(get_current_user_id),
):
    producto_repo = ProductoRepository(db)
    movimiento_repo = MovimientoRepository(db)
    service = InventarioService(
        producto_repo, movimiento_repo, InferenceService()
    )
    inventario = await service.obtener_inventario()
    return [p for p in inventario if p.stock_bajo]
