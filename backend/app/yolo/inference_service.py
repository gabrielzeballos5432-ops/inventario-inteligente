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

    def cargar_modelo(self) -> None:
        ruta = settings.YOLO_MODEL_PATH
        if not Path(ruta).exists():
            logger.warning("Modelo YOLO no encontrado en %s. Desactivando deteccion.", ruta)
            self._modelo = None
            return
        logger.info("Cargando modelo YOLO desde %s", ruta)
        self._modelo = YOLO(ruta)
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
            raise RuntimeError("Modelo YOLO no disponible: no se encontro el archivo de pesos")

        imagen = Image.open(io.BytesIO(image_bytes))
        img_array = np.array(imagen)
        if img_array.shape[-1] == 4:
            img_array = cv2.cvtColor(img_array, cv2.COLOR_RGBA2RGB)

        resultados = self.modelo(img_array, conf=settings.YOLO_CONFIDENCE_THRESHOLD)

        detecciones: list[dict] = []
        conteo: dict[int, int] = {}

        for r in resultados:
            if r.boxes is None:
                continue
            for box in r.boxes:
                cls_id = int(box.cls[0].item())
                confianza = float(box.conf[0].item())
                producto_id = MAPA_CLASES_YOLO.get(cls_id)
                if producto_id is None:
                    logger.warning("Clase YOLO %d no mapeada a producto", cls_id)
                    continue
                conteo[producto_id] = conteo.get(producto_id, 0) + 1

        for producto_id, cantidad in conteo.items():
            detecciones.append({
                "producto_id": producto_id,
                "cantidad": cantidad,
                "confianza": confianza,
            })

        return detecciones
