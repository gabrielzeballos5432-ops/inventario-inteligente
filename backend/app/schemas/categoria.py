from pydantic import BaseModel, ConfigDict, Field
from typing import Optional


class CategoriaCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=100)
    padre_id: Optional[int] = None


class CategoriaUpdate(BaseModel):
    nombre: Optional[str] = Field(default=None, min_length=1, max_length=100)
    padre_id: Optional[int] = None
    activo: Optional[bool] = None


class CategoriaOut(BaseModel):
    id: int
    nombre: str
    padre_id: Optional[int] = None
    activo: bool

    model_config = ConfigDict(from_attributes=True)