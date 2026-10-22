from pydantic import BaseModel, ConfigDict, Field
from typing import Optional


class MarcaCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=100)


class MarcaUpdate(BaseModel):
    nombre: Optional[str] = Field(default=None, min_length=1, max_length=100)
    activo: Optional[bool] = None


class MarcaOut(BaseModel):
    id: int
    nombre: str
    activo: bool

    model_config = ConfigDict(from_attributes=True)