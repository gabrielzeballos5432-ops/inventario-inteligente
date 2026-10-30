from datetime import date, datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class MonedaCreate(BaseModel):
    codigo: str = Field(min_length=3, max_length=3, pattern=r"^[A-Z]{3}$")
    nombre: str = Field(min_length=1, max_length=80)
    simbolo: Optional[str] = Field(default=None, max_length=10)
    pais: Optional[str] = Field(default=None, max_length=80)
    decimales: int = Field(default=2, ge=0, le=4)


class MonedaOut(MonedaCreate):
    activa: bool

    model_config = ConfigDict(from_attributes=True)


class MonedaEstadoUpdate(BaseModel):
    activa: bool


class CompraDetalleCreate(BaseModel):
    producto_id: int = Field(gt=0, le=2_147_483_647)
    cantidad: int = Field(gt=0, le=2_147_483_647)
    costo_unitario_moneda: Decimal = Field(ge=0, max_digits=18, decimal_places=6)
    descripcion_factura: Optional[str] = Field(default=None, max_length=250)


class CompraCreate(BaseModel):
    proveedor_id: int = Field(gt=0, le=2_147_483_647)
    moneda_codigo: str = Field(min_length=3, max_length=3, pattern=r"^[A-Z]{3}$")
    tipo_cambio_ext: Decimal = Field(gt=0, max_digits=18, decimal_places=6)
    tipo_cambio_bob: Decimal = Field(gt=0, max_digits=18, decimal_places=6)
    numero_factura: Optional[str] = Field(default=None, max_length=100)
    fecha_factura: Optional[date] = None
    descuento_moneda: Decimal = Field(default=Decimal("0"), ge=0, max_digits=18, decimal_places=4)
    porcentaje_manipulacion_envio: Decimal = Field(
        default=Decimal("0"), ge=0, le=100, max_digits=5, decimal_places=2
    )
    imagen_factura_url: Optional[str] = None
    detalles: list[CompraDetalleCreate] = Field(min_length=1)


class CompraDetalleOut(BaseModel):
    id: int
    producto_id: int
    descripcion_factura: Optional[str]
    cantidad: int
    costo_unitario_moneda: Decimal
    subtotal_linea_moneda: Decimal
    costo_unitario_final_bob: Decimal

    model_config = ConfigDict(from_attributes=True)


class CompraOut(BaseModel):
    id: int
    proveedor_id: int
    usuario_id: int
    moneda_codigo: str
    tipo_cambio_ext: Decimal
    tipo_cambio_bob: Decimal
    numero_factura: Optional[str]
    fecha_factura: Optional[date]
    subtotal_moneda: Decimal
    descuento_moneda: Decimal
    base_costo_adicional_moneda: Decimal
    porcentaje_manipulacion_envio: Decimal
    costo_manipulacion_envio_moneda: Decimal
    total_moneda: Decimal
    total_bob: Decimal
    imagen_factura_url: Optional[str]
    estado: str
    fecha_creacion: datetime
    detalles: list[CompraDetalleOut]

    model_config = ConfigDict(from_attributes=True)
