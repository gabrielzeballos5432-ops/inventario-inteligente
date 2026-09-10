from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class MovimientoOut(BaseModel):
    id: int
    producto_id: int
    producto_nombre: Optional[str] = None
    usuario_id: Optional[int] = None
    usuario_nombre: Optional[str] = None
    sesion_id: Optional[int] = None
    tipo: str
    cantidad_anterior: int
    cantidad: int
    stock_resultante: int
    origen: str
    creado_en: Optional[datetime] = None

    class Config:
        from_attributes = True


class MovimientoCreate(BaseModel):
    producto_id: int
    tipo: str = Field(pattern="^(entrada|salida|ajuste)$")
    cantidad: int = Field(gt=0)
    origen: str = Field(default="manual", pattern="^(manual|ia)$")
    sesion_id: Optional[int] = None