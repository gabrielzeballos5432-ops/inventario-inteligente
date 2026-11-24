from pydantic import BaseModel, ConfigDict, Field, EmailStr, field_validator
from typing import Optional

from app.schemas.comunes import nombre_obligatorio


class ProveedorCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=150)
    contacto: Optional[str] = Field(default=None, max_length=100)
    telefono: Optional[str] = Field(default=None, max_length=20)
    email: Optional[EmailStr] = None

    @field_validator("nombre")
    @classmethod
    def validar_nombre(cls, valor: str) -> str:
        return nombre_obligatorio(valor)

    @field_validator("email")
    @classmethod
    def validar_largo_email(cls, valor: Optional[str]) -> Optional[str]:
        # La columna es VARCHAR(100) y EmailStr no tiene tope propio.
        if valor is not None and len(valor) > 100:
            raise ValueError("El correo admite hasta 100 caracteres")
        return valor


class ProveedorUpdate(BaseModel):
    nombre: Optional[str] = Field(default=None, min_length=1, max_length=150)
    contacto: Optional[str] = Field(default=None, max_length=100)
    telefono: Optional[str] = Field(default=None, max_length=20)
    email: Optional[EmailStr] = None
    activo: Optional[bool] = None

    @field_validator("nombre")
    @classmethod
    def validar_nombre(cls, valor: Optional[str]) -> Optional[str]:
        return None if valor is None else nombre_obligatorio(valor)

    @field_validator("email")
    @classmethod
    def validar_largo_email(cls, valor: Optional[str]) -> Optional[str]:
        # La columna es VARCHAR(100) y EmailStr no tiene tope propio.
        if valor is not None and len(valor) > 100:
            raise ValueError("El correo admite hasta 100 caracteres")
        return valor


class ProveedorOut(BaseModel):
    id: int
    nombre: str
    contacto: Optional[str] = None
    telefono: Optional[str] = None
    email: Optional[str] = None
    activo: bool

    model_config = ConfigDict(from_attributes=True)