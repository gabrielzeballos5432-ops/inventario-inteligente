from pydantic import BaseModel, ConfigDict, Field, field_validator
from typing import Optional

from app.schemas.comunes import nombre_obligatorio


class MarcaCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=100)

    @field_validator("nombre")
    @classmethod
    def validar_nombre(cls, valor: str) -> str:
        return nombre_obligatorio(valor)


class MarcaUpdate(BaseModel):
    nombre: Optional[str] = Field(default=None, min_length=1, max_length=100)
    activo: Optional[bool] = None

    @field_validator("nombre")
    @classmethod
    def validar_nombre(cls, valor: Optional[str]) -> Optional[str]:
        return None if valor is None else nombre_obligatorio(valor)


class MarcaOut(BaseModel):
    id: int
    nombre: str
    activo: bool

    model_config = ConfigDict(from_attributes=True)
