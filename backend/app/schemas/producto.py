from pydantic import BaseModel
from typing import Optional
from decimal import Decimal


class CategoriaOut(BaseModel):
    id: int
    nombre: str
    padre_id: Optional[int] = None

    class Config:
        from_attributes = True


class ProductoOut(BaseModel):
    id: int
    sku: Optional[str] = None
    codigo_barras: Optional[str] = None
    nombre: str
    descripcion: Optional[str] = None
    categoria_id: Optional[int] = None
    categoria: Optional[CategoriaOut] = None
    marca_id: Optional[int] = None
    proveedor_id: Optional[int] = None
    precio_compra: Decimal
    precio_venta: Decimal
    stock_minimo: int
    activo: bool

    class Config:
        from_attributes = True


class ProductoCreate(BaseModel):
    sku: Optional[str] = None
    codigo_barras: Optional[str] = None
    nombre: str
    descripcion: Optional[str] = None
    categoria_id: Optional[int] = None
    marca_id: Optional[int] = None
    proveedor_id: Optional[int] = None
    precio_compra: Decimal = 0
    precio_venta: Decimal = 0
    stock_minimo: int = 5


class ProductoUpdate(BaseModel):
    sku: Optional[str] = None
    codigo_barras: Optional[str] = None
    nombre: Optional[str] = None
    descripcion: Optional[str] = None
    categoria_id: Optional[int] = None
    marca_id: Optional[int] = None
    proveedor_id: Optional[int] = None
    precio_compra: Optional[Decimal] = None
    precio_venta: Optional[Decimal] = None
    stock_minimo: Optional[int] = None
    activo: Optional[bool] = None


class ProductoStockOut(ProductoOut):
    stock_actual: int = 0
    stock_bajo: bool = False


class ValorizacionOut(BaseModel):
    productos_activos: int = 0
    unidades_totales: int = 0
    productos_stock_bajo: int = 0
    valorizado_costo: Decimal = Decimal("0")
    valorizado_venta: Decimal = Decimal("0")