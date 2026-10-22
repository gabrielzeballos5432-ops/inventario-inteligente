from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db
from app.core.security import get_current_user_id
from app.repositories.producto_repository import ProductoRepository
from app.repositories.movimiento_repository import MovimientoRepository
from app.services.inventario_service import InventarioService
from app.yolo.inference_service import InferenceService
from app.schemas.producto import ProductoStockOut
from app.schemas.movimiento import (
    MovimientoCreate,
    MovimientoLoteCreate,
    MovimientoLoteOut,
    MovimientoOut,
)

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


@router.post("/movimiento", response_model=MovimientoOut, status_code=201)
async def registrar_movimiento(
    body: MovimientoCreate,
    db: AsyncSession = Depends(get_db),
    usuario_id: int = Depends(get_current_user_id),
):
    # Una salida no puede dejar el stock en negativo. El repositorio lo
    # recortaria en silencio a 0 (max(0, ...)), asi que se rechaza aqui con un
    # mensaje que dice cuanto hay disponible en vez de guardar un movimiento
    # que no refleja la realidad.
    if body.tipo == "salida":
        producto_repo = ProductoRepository(db)
        stock = await producto_repo.obtener_stock(body.producto_id)
        if body.cantidad > stock:
            raise HTTPException(
                status_code=400,
                detail=f"No hay stock suficiente: disponible {stock}",
            )

    movimiento_repo = MovimientoRepository(db)
    movimiento = await movimiento_repo.crear_movimiento(
        producto_id=body.producto_id,
        usuario_id=usuario_id,
        tipo=body.tipo,
        cantidad=body.cantidad,
        origen=body.origen,
        sesion_id=body.sesion_id,
    )

    producto_repo = ProductoRepository(db)
    producto = await producto_repo.obtener_por_id(body.producto_id)
    return MovimientoOut(
        id=movimiento.id,
        producto_id=movimiento.producto_id,
        producto_nombre=producto.nombre if producto else None,
        usuario_id=movimiento.usuario_id,
        sesion_id=movimiento.sesion_id,
        tipo=movimiento.tipo,
        cantidad_anterior=movimiento.cantidad_anterior,
        cantidad=movimiento.cantidad,
        stock_resultante=movimiento.stock_resultante,
        origen=movimiento.origen,
        creado_en=movimiento.creado_en,
    )


@router.post("/movimientos/lote", response_model=MovimientoLoteOut, status_code=201)
async def registrar_movimientos_lote(
    body: MovimientoLoteCreate,
    db: AsyncSession = Depends(get_db),
    usuario_id: int = Depends(get_current_user_id),
):
    """Varios movimientos del mismo tipo en una sola llamada.

    La recepcion de mercaderia (y el conteo fisico, y la venta de varios
    productos) no deja de ser un documento: si una linea falla no se guarda
    ninguna y el 400 trae el detalle de cada fila, listo para mostrarse. Es
    tambien el nucleo que usara el reconocimiento (RF-10), que registra las
    entradas detectadas en una unica captura.
    """
    producto_repo = ProductoRepository(db)
    movimiento_repo = MovimientoRepository(db)
    service = InventarioService(
        producto_repo, movimiento_repo, InferenceService()
    )
    resultados, movimientos = await service.registrar_lote(
        tipo=body.tipo,
        items=body.items,
        usuario_id=usuario_id,
        origen=body.origen,
        sesion_id=body.sesion_id,
    )
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