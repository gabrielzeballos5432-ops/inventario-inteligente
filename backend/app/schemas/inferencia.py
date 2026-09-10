from pydantic import BaseModel
from typing import Optional


class DeteccionOut(BaseModel):
    producto_id: int
    producto_nombre: str
    confianza: float
    cantidad: int


class InferenciaResponse(BaseModel):
    detecciones: list[DeteccionOut]
    total_productos: int
    movimientos_creados: int = 0
    sesion_id: Optional[int] = None