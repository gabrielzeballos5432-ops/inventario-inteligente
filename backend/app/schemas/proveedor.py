from pydantic import BaseModel, ConfigDict, Field, EmailStr
from typing import Optional


class ProveedorCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=150)
    contacto: Optional[str] = Field(default=None, max_length=100)
    telefono: Optional[str] = Field(default=None, max_length=20)
    email: Optional[EmailStr] = None


class ProveedorUpdate(BaseModel):
    nombre: Optional[str] = Field(default=None, min_length=1, max_length=150)
    contacto: Optional[str] = Field(default=None, max_length=100)
    telefono: Optional[str] = Field(default=None, max_length=20)
    email: Optional[EmailStr] = None
    activo: Optional[bool] = None


class ProveedorOut(BaseModel):
    id: int
    nombre: str
    contacto: Optional[str] = None
    telefono: Optional[str] = None
    email: Optional[str] = None
    activo: bool

    model_config = ConfigDict(from_attributes=True)