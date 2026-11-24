from pydantic import BaseModel
from typing import Optional


class CajaOut(BaseModel):
    """Recuadro de una unidad detectada, en proporcion de la foto (0 a 1).

    Las coordenadas son sobre la foto ya enderezada (`exif_transpose`), con
    el origen arriba a la izquierda: la app las multiplica por el tamano con
    que muestra la imagen, sin depender de la resolucion original.
    """

    x1: float
    y1: float
    x2: float
    y2: float
    confianza: float


class DeteccionOut(BaseModel):
    producto_id: int
    producto_nombre: str
    confianza: float
    cantidad: int
    # Un recuadro por unidad contada: cantidad == len(cajas).
    cajas: list[CajaOut] = []


class InferenciaResponse(BaseModel):
    detecciones: list[DeteccionOut]
    total_productos: int
    movimientos_creados: int = 0
    sesion_id: Optional[int] = None