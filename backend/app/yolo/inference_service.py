import io
import logging
import threading
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

# Una caja que queda al menos en esta proporcion dentro de otra mas grande del
# mismo producto es la misma unidad vista dos veces (p. ej. la mitad de arriba
# del frasco y el frasco entero). El NMS de YOLO no la quita porque mide la
# superposicion contra la union de ambas, que con una caja chica queda baja.
UMBRAL_ANIDADA = 0.85


def _area(c: dict) -> float:
    return max(0.0, c["x2"] - c["x1"]) * max(0.0, c["y2"] - c["y1"])


def descartar_anidadas(cajas: list[dict], umbral: float = UMBRAL_ANIDADA) -> list[dict]:
    """Quita las cajas contenidas en otra mas grande del mismo producto.

    Se conserva la caja grande (cubre la unidad completa) con la confianza
    mas alta de las dos. Dos unidades reales, una al lado de otra, nunca
    quedan una dentro de la otra, asi que no se pierde ninguna.
    """
    quedan: list[dict] = []
    for caja in sorted(cajas, key=_area, reverse=True):
        area = _area(caja)
        contenedora = None
        for grande in quedan:
            ancho = min(caja["x2"], grande["x2"]) - max(caja["x1"], grande["x1"])
            alto = min(caja["y2"], grande["y2"]) - max(caja["y1"], grande["y1"])
            interseccion = max(0.0, ancho) * max(0.0, alto)
            if area > 0 and interseccion / area >= umbral:
                contenedora = grande
                break
        if contenedora is None:
            quedan.append(dict(caja))
        else:
            contenedora["confianza"] = max(contenedora["confianza"], caja["confianza"])
    return quedan


class InferenceService:
    _modelo: Optional[YOLO] = None
    # La vista previa en vivo corre el modelo en un hilo aparte; el predictor
    # de Ultralytics no admite dos llamadas a la vez sobre el mismo modelo.
    _candado = threading.Lock()

    @property
    def mapa_clases(self) -> dict[int, int]:
        if settings.YOLO_CLASS_MAP:
            return settings.YOLO_CLASS_MAP
        return MAPA_CLASES_YOLO

    @property
    def modelo_disponible(self) -> bool:
        # El modelo se carga en la primera deteccion; mientras tanto basta
        # con que el archivo exista. Si no, /api/health decia "IA pendiente"
        # aunque el modelo estuviera instalado.
        return InferenceService._modelo is not None or Path(settings.YOLO_MODEL_PATH).exists()

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

        with InferenceService._candado:
            resultados = self.modelo(img_array, conf=settings.YOLO_CONFIDENCE_THRESHOLD)

        cajas_por_producto: dict[int, list[dict]] = {}
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
                # Proporcion de la foto (0 a 1): la app dibuja el recuadro sin
                # conocer la resolucion con que se proceso.
                x1, y1, x2, y2 = (float(v) for v in box.xyxyn[0].tolist())
                caja = {"x1": x1, "y1": y1, "x2": x2, "y2": y2, "confianza": confianza}
                cajas_por_producto.setdefault(producto_id, []).append(caja)

        detecciones = []
        for producto_id, cajas in cajas_por_producto.items():
            # Se cuenta despues de quitar las cajas repetidas: la cantidad es
            # siempre el numero de recuadros que ve el usuario.
            cajas = descartar_anidadas(cajas)
            detecciones.append(
                {
                    "producto_id": producto_id,
                    "cantidad": len(cajas),
                    "confianza": max(c["confianza"] for c in cajas),
                    "cajas": cajas,
                }
            )
        return detecciones