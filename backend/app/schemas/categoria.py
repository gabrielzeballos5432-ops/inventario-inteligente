from pydantic import BaseModel, ConfigDict, Field, field_validator
from typing import Optional

from app.schemas.comunes import nombre_obligatorio


class CategoriaCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=100)
    padre_id: Optional[int] = None

    @field_validator("nombre")
    @classmethod
    def validar_nombre(cls, valor: str) -> str:
        return nombre_obligatorio(valor)


class CategoriaUpdate(BaseModel):
    nombre: Optional[str] = Field(default=None, min_length=1, max_length=100)
    padre_id: Optional[int] = None
    activo: Optional[bool] = None

    @field_validator("nombre")
    @classmethod
    def validar_nombre(cls, valor: Optional[str]) -> Optional[str]:
        return None if valor is None else nombre_obligatorio(valor)


class CategoriaOut(BaseModel):
    id: int
    nombre: str
    padre_id: Optional[int] = None
    activo: bool

    model_config = ConfigDict(from_attributes=True)