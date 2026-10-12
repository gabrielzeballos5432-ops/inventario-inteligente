import io
import logging
from pathlib import Path
from typing import Optional

import cv2
import numpy as np
from PIL import Image
from ultralytics import YOLO

from app.core.config import settings

logger = logging.getLogger(__name__)

MAPA_CLASES_YOLO: dict[int, int] = {
    # key: id de clase del modelo YOLO (entrenado)
    # value: id del producto en la BD
    # Se puede sobreescribir via la variable de entorno YOLO_CLASS_MAP
    # EJEMPLO -- el usuario debe ajustar segun su modelo entrenado
    0: 1,  # tinte negro -> producto_id=1
    1: 2,  # tinte marron -> producto_id=2
    2: 3,  # peroxido 20v -> producto_id=3
    3: 4,  # peroxido 30v -> producto_id=4
    4: 5,  # shampoo -> producto_id=5
    5: 6,  # acondicionador -> producto_id=6
}


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

        imagen = Image.open(io.BytesIO(image_bytes))
        img_array = np.array(imagen)
        if img_array.shape[-1] == 4:
            img_array = cv2.cvtColor(img_array, cv2.COLOR_RGBA2RGB)

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