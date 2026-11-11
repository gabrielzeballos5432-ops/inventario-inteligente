from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db
from app.core.security import get_current_user_id
from app.core.sucursal import get_sucursal_activa
from app.repositories.producto_repository import ProductoRepository
from app.repositories.movimiento_repository import MovimientoRepository
from app.repositories.sesion_repository import SesionRepository
from app.repositories.deteccion_repository import DeteccionRepository
from app.services.inventario_service import InventarioService
from app.yolo.inference_service import InferenceService
from app.schemas.inferencia import InferenciaResponse

router = APIRouter(prefix="/api/inference", tags=["Inferencia"])


@router.post("/", response_model=InferenciaResponse)
async def realizar_inferencia(
    imagen: UploadFile = File(...),
    tipo_operacion: str = Form("entrada"),
    db: AsyncSession = Depends(get_db),
    usuario_id: int = Depends(get_current_user_id),
    sucursal_id: int = Depends(get_sucursal_activa),
):
    if tipo_operacion not in ("entrada", "salida", "conteo"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="tipo_operacion debe ser 'entrada', 'salida' o 'conteo'",
        )

    if not imagen.content_type or not imagen.content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El archivo debe ser una imagen",
        )

    image_bytes = await imagen.read()

    if len(image_bytes) > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="La imagen no debe exceder 10MB",
        )

    try:
        producto_repo = ProductoRepository(db)
        movimiento_repo = MovimientoRepository(db)
        sesion_repo = SesionRepository(db)
        deteccion_repo = DeteccionRepository(db)
        yolo = InferenceService()
        service = InventarioService(
            producto_repo,
            movimiento_repo,
            yolo,
            sesion_repo=sesion_repo,
            deteccion_repo=deteccion_repo,
        )
        return await service.procesar_inferencia(
            image_bytes,
            usuario_id,
            sucursal_id,
            imagen_url=imagen.filename,
            tipo_operacion=tipo_operacion,
        )
    except RuntimeError as exc:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc