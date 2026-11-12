import io
import logging
from pathlib import Path
from typing import Optional

import numpy as np
from PIL import Image, ImageOps
from ultralytics import YOLO

from app.core.config import settings

logger = logging.getLogger(__name__)

# Clase del modelo -> id del producto en la BD. Los ids dependen de cada base,
# asi que se configuran en .env con YOLO_CLASS_MAP (p. ej. {"0": 25, "1": 26}).
# Sin configuracion no se asigna nada: una deteccion sin mapa se ignora con un
# aviso en el log, en vez de sumar stock a un producto equivocado.
MAPA_CLASES_YOLO: dict[int, int] = {}


class InferenceService:
    _modelo: Optional[YOLO] = None

    @property
    def mapa_clases(self) -> dict[int, int]:
        if settings.YOLO_CLASS_MAP:
            return settings.YOLO_CLASS_MAP
        return MAPA_CLASES_YOLO

    @property
    def modelo_disponible(self) -> bool:
        return InferenceService._modelo is not None

    def cargar_modelo(self) -> None:
        ruta = settings.YOLO_MODEL_PATH
        if not Path(ruta).exists():
            logger.warning(
                "Modelo YOLO no encontrado en %s. La deteccion quedara desactivada. "
                "Coloca tu modelo entrenado en esa ruta o ajusta YOLO_MODEL_PATH.",
                ruta,
            )
            InferenceService._modelo = None
            return
        logger.info("Cargando modelo YOLO desde %s", ruta)
        InferenceService._modelo = YOLO(ruta)
        logger.info("Modelo YOLO cargado exitosamente")

    @property
    def modelo(self) -> YOLO:
        if self._modelo is None:
            self.cargar_modelo()
        return self._modelo

    def detectar(self, image_bytes: bytes) -> list[dict]:
        if self._modelo is None:
            self.cargar_modelo()
        if self._modelo is None:
            raise RuntimeError(
                "Modelo YOLO no disponible: no se encontro el archivo de pesos en "
                f"{settings.YOLO_MODEL_PATH}"
            )

        # La camara del celular suele guardar la foto "de costado" con una
        # marca EXIF que dice como girarla. Sin aplicarla, el modelo recibe la
        # imagen girada 90 grados.
        imagen = ImageOps.exif_transpose(Image.open(io.BytesIO(image_bytes)))
        # Ultralytics interpreta un arreglo numpy como BGR (convencion de
        # OpenCV). Pasarle RGB intercambia rojo y azul y el modelo, entrenado
        # con colores reales, falla mas: se invierten los canales.
        img_array = np.ascontiguousarray(np.array(imagen.convert("RGB"))[:, :, ::-1])

        resultados = self.modelo(img_array, conf=settings.YOLO_CONFIDENCE_THRESHOLD)

        detecciones_por_producto: dict[int, dict] = {}
        mapa = self.mapa_clases

        for r in resultados:
            if r.boxes is None:
                continue
            for box in r.boxes:
                cls_id = int(box.cls[0].item())
                confianza = float(box.conf[0].item())
                producto_id = mapa.get(cls_id)
                if producto_id is None:
                    logger.warning("Clase YOLO %d no mapeada a producto", cls_id)
                    continue
                actual = detecciones_por_producto.get(producto_id)
                if actual is None:
                    detecciones_por_producto[producto_id] = {
                        "producto_id": producto_id,
                        "cantidad": 1,
                        "confianza": confianza,
                    }
                else:
                    actual["cantidad"] += 1
                    actual["confianza"] = max(actual["confianza"], confianza)

        return list(detecciones_por_producto.values())