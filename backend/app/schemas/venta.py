from datetime import datetime
from decimal import Decimal
from typing import Annotated, Literal, Optional

from pydantic import BaseModel, Field

ClaveIdempotencia = Annotated[str, Field(min_length=8, max_length=100)]


class VentaDetalleCreate(BaseModel):
    producto_id: int = Field(gt=0)
    cantidad: int = Field(gt=0)
    precio_unitario_negociado: Decimal = Field(
        ge=0, max_digits=10, decimal_places=2
    )
    tipo_promocion: Optional[Literal["oferta", "combo", "liquidacion"]] = None
    observacion_promocion: Optional[str] = Field(default=None, max_length=200)
    # Monto acordado por la línea completa. Si se envía, manda sobre
    # cantidad x precio unitario (el precio unitario puede quedar redondeado).
    total_linea: Optional[
        Annotated[Decimal, Field(ge=0, max_digits=12, decimal_places=2)]
    ] = None


class PagoVentaCreate(BaseModel):
    metodo_pago: Literal["efectivo", "qr"]
    monto: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    referencia: Optional[str] = Field(default=None, max_length=100)


class VentaCreate(BaseModel):
    tipo_venta: Literal["minorista", "mayorista"] = "minorista"
    cliente_id: Optional[int] = Field(default=None, gt=0)
    sesion_caja_id: Optional[int] = Field(default=None, gt=0)
    clave_idempotencia: Optional[ClaveIdempotencia] = None
    detalles: list[VentaDetalleCreate] = Field(min_length=1)
    pagos: list[PagoVentaCreate] = Field(default_factory=list)


class VentaAnular(BaseModel):
    motivo: str = Field(min_length=3, max_length=250)


class VentaDetalleOut(BaseModel):
    id: int
    producto_id: int
    producto_nombre: str
    producto_sku: Optional[str] = None
    cantidad: int
    precio_lista_unitario: Decimal
    precio_unitario_negociado: Decimal
    total_linea: Decimal
    costo_unitario_bob_aplicado: Optional[Decimal] = None
    costo_total_bob_aplicado: Optional[Decimal] = None
    tipo_promocion: Optional[str] = None
    observacion_promocion: Optional[str] = None

    class Config:
        from_attributes = True


class PagoVentaOut(BaseModel):
    id: int
    fecha_creacion: datetime
    metodo_pago: str
    monto: Decimal
    estado: str
    referencia: Optional[str] = None

    class Config:
        from_attributes = True


class VentaOut(BaseModel):
    id: int
    fecha_creacion: datetime
    usuario_id: int
    cliente_id: Optional[int] = None
    sesion_caja_id: Optional[int] = None
    tipo_venta: str
    total: Decimal
    estado: str
    anulada_en: Optional[datetime] = None
    anulada_por_usuario_id: Optional[int] = None
    motivo_anulacion: Optional[str] = None
    detalles: list[VentaDetalleOut]
    pagos: list[PagoVentaOut]

    class Config:
        from_attributes = True
