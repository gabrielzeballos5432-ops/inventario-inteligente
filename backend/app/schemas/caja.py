from datetime import datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class SesionCajaAbrir(BaseModel):
    monto_inicial: Decimal = Field(ge=0, max_digits=12, decimal_places=2)


class SesionCajaCerrar(BaseModel):
    monto_efectivo_contado: Decimal = Field(ge=0, max_digits=12, decimal_places=2)
    observacion_cierre: Optional[str] = Field(default=None, max_length=250)


class SesionCajaOut(BaseModel):
    id: int
    usuario_apertura_id: int
    sucursal_id: Optional[int] = None
    usuario_cierre_id: Optional[int]
    fecha_apertura: datetime
    fecha_cierre: Optional[datetime]
    monto_inicial: Decimal
    monto_esperado_cierre: Optional[Decimal]
    monto_efectivo_contado: Optional[Decimal]
    monto_diferencia_cierre: Optional[Decimal] = None
    observacion_cierre: Optional[str]
    estado: str

    model_config = ConfigDict(from_attributes=True)


class ClienteCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=150)
    telefono: Optional[str] = Field(default=None, max_length=30)
    email: Optional[str] = Field(default=None, max_length=150)


class ClienteOut(ClienteCreate):
    id: int
    activo: bool
    creado_en: datetime

    model_config = ConfigDict(from_attributes=True)
