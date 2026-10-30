from pydantic import BaseModel, ConfigDict, EmailStr, Field
from decimal import Decimal
from typing import Annotated, Optional
from datetime import datetime

PagoPorHora = Annotated[
    Decimal, Field(gt=0, max_digits=10, decimal_places=2)
]
PorcentajeComision = Annotated[
    Decimal, Field(ge=0, le=100, max_digits=5, decimal_places=2)
]


class RolOut(BaseModel):
    id: int
    nombre: str
    descripcion: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class UsuarioBase(BaseModel):
    nombre: str = Field(min_length=1, max_length=100)
    email: EmailStr
    rol_id: int
    activo: bool = True
    pago_por_hora: Optional[PagoPorHora] = None
    porcentaje_comision: Optional[PorcentajeComision] = None


class UsuarioCreate(UsuarioBase):
    password: str = Field(min_length=6, max_length=128)


class UsuarioUpdate(BaseModel):
    nombre: Optional[str] = Field(default=None, min_length=1, max_length=100)
    email: Optional[EmailStr] = None
    rol_id: Optional[int] = None
    activo: Optional[bool] = None
    pago_por_hora: Optional[PagoPorHora] = None
    porcentaje_comision: Optional[PorcentajeComision] = None
    password: Optional[str] = Field(default=None, min_length=6, max_length=128)


class UsuarioOut(BaseModel):
    id: int
    nombre: str
    email: EmailStr
    rol_id: int
    rol_nombre: str
    activo: bool
    created_at: Optional[datetime] = None
    pago_por_hora: Optional[Decimal] = None
    porcentaje_comision: Optional[Decimal] = None