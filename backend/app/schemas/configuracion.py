from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator


def _texto_obligatorio(valor: str) -> str:
    limpio = valor.strip()
    if not limpio:
        raise ValueError("El nombre no puede quedar vacío.")
    return limpio


class SucursalOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nombre: str
    direccion: Optional[str] = None
    telefono: Optional[str] = None
    activo: bool
    predeterminada: bool = False


class SucursalCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=100)
    direccion: Optional[str] = Field(default=None, max_length=200)
    telefono: Optional[str] = Field(default=None, max_length=30)

    @field_validator("nombre")
    @classmethod
    def validar_nombre(cls, valor: str) -> str:
        return _texto_obligatorio(valor)


class SucursalUpdate(BaseModel):
    nombre: Optional[str] = Field(default=None, min_length=1, max_length=100)
    direccion: Optional[str] = Field(default=None, max_length=200)
    telefono: Optional[str] = Field(default=None, max_length=30)
    activo: Optional[bool] = None

    @field_validator("nombre")
    @classmethod
    def validar_nombre(cls, valor: Optional[str]) -> Optional[str]:
        return None if valor is None else _texto_obligatorio(valor)


class ConfiguracionOut(BaseModel):
    sucursal_predeterminada_id: int
    sucursal_predeterminada: SucursalOut
    actualizado_en: Optional[datetime] = None


class ConfiguracionUpdate(BaseModel):
    sucursal_predeterminada_id: int


class RazonMovimientoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    codigo: Optional[str] = None
    nombre: str
    tipo_movimiento: str
    sistema: bool
    requiere_sucursal_destino: bool
    activo: bool
    creado_en: Optional[datetime] = None
    actualizado_en: Optional[datetime] = None


class RazonMovimientoCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=100)
    tipo_movimiento: str = Field(pattern="^(entrada|salida|ajuste)$")
    requiere_sucursal_destino: bool = False

    @field_validator("nombre")
    @classmethod
    def validar_nombre(cls, valor: str) -> str:
        return _texto_obligatorio(valor)


class RazonMovimientoUpdate(BaseModel):
    # El tipo no se edita: los movimientos ya registrados con esta razón
    # quedarían contando otra historia. Para otro tipo se crea otra razón.
    nombre: Optional[str] = Field(default=None, min_length=1, max_length=100)
    requiere_sucursal_destino: Optional[bool] = None
    activo: Optional[bool] = None

    @field_validator("nombre")
    @classmethod
    def validar_nombre(cls, valor: Optional[str]) -> Optional[str]:
        return None if valor is None else _texto_obligatorio(valor)
