import io

from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException, status
from PIL import Image
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


def es_imagen(content_type: str | None, datos: bytes) -> bool:
    """Acepta la imagen por su tipo declarado o, si no lo trae, por su contenido.

    La app sube la foto con `MultipartFile.fromBytes`, que la declara como
    `application/octet-stream`: exigir `image/*` rechazaba con 400 toda foto
    tomada desde el celular. Por eso, sin un tipo de imagen, se decide
    abriendo los bytes con Pillow.
    """
    if content_type and content_type.startswith("image/"):
        return True
    try:
        Image.open(io.BytesIO(datos)).verify()
        return True
    except Exception:
        return False


@router.post("/", response_model=InferenciaResponse)
async def realizar_inferencia(
    imagen: UploadFile = File(...),
    tipo_operacion: str = Form("entrada"),
    # False: solo detecta (y guarda la sesion y las detecciones como
    # auditoria) sin mover el stock. La app muestra el resultado para que
    # el usuario lo corrija y lo registra al confirmar, por lote con origen
    # "ia". True conserva el comportamiento anterior: registra al instante.
    registrar: bool = Form(True),
    db: AsyncSession = Depends(get_db),
    usuario_id: int = Depends(get_current_user_id),
    sucursal_id: int = Depends(get_sucursal_activa),
):
    if tipo_operacion not in ("entrada", "salida", "conteo"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="tipo_operacion debe ser 'entrada', 'salida' o 'conteo'",
        )

    image_bytes = await imagen.read()

    if len(image_bytes) > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="La imagen no debe exceder 10MB",
        )

    if not es_imagen(imagen.content_type, image_bytes):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El archivo debe ser una imagen",
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
            registrar=registrar,
        )
    except RuntimeError as exc:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc