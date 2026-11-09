from decimal import Decimal

from pydantic import BaseModel


class LineaCompraLeida(BaseModel):
    descripcion: str
    codigo: str | None = None
    producto_id: int | None = None
    cantidad: int
    costo_unitario_moneda: Decimal
    subtotal_impreso: Decimal | None = None


class LecturaCompraOut(BaseModel):
    numero_factura: str | None = None
    proveedor_nombre: str | None = None
    proveedor_id: int | None = None
    moneda_codigo: str | None = None
    total_impreso: Decimal | None = None
    subtotal_calculado: Decimal
    detalles: list[LineaCompraLeida]
    advertencias: list[str]
    texto_detectado: str
