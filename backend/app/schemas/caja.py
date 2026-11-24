from datetime import datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator
import re

from app.schemas.comunes import nombre_obligatorio

_CORREO = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


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

    @field_validator("nombre")
    @classmethod
    def validar_nombre(cls, valor: str) -> str:
        return nombre_obligatorio(valor)

    @field_validator("telefono", "email")
    @classmethod
    def vacio_a_nulo(cls, valor: Optional[str]) -> Optional[str]:
        if valor is None:
            return None
        return valor.strip() or None

    @field_validator("email")
    @classmethod
    def validar_email(cls, valor: Optional[str]) -> Optional[str]:
        # Igual que la app: si se escribe, tiene que tener forma de correo.
        if valor is not None and not _CORREO.match(valor):
            raise ValueError("Ingresa un correo valido (ej. nombre@correo.com)")
        return valor


class ClienteOut(BaseModel):
    # No hereda de ClienteCreate: sus validadores correrian al leer y un
    # cliente guardado antes con un correo mal escrito romperia el listado.
    nombre: str
    telefono: Optional[str] = None
    email: Optional[str] = None
    id: int
    activo: bool
    creado_en: datetime

    model_config = ConfigDict(from_attributes=True)
