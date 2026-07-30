from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class MovimientoOut(BaseModel):
    id: int
    producto_id: int
    producto_nombre: Optional[str] = None
    usuario_id: int
    usuario_nombre: Optional[str] = None
    tipo: str
    cantidad: int
    stock_resultante: int
    origen: Optional[str] = None
    creado_en: Optional[datetime] = None

    class Config:
        from_attributes = True


class MovimientoCreate(BaseModel):
    producto_id: int
    tipo: str
    cantidad: int
    origen: str = "app"
