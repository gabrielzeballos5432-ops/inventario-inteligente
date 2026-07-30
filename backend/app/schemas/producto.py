from pydantic import BaseModel
from typing import Optional


class CategoriaOut(BaseModel):
    id: int
    nombre: str
    descripcion: Optional[str] = None

    class Config:
        from_attributes = True


class ProductoOut(BaseModel):
    id: int
    codigo_barras: Optional[str] = None
    nombre: str
    descripcion: Optional[str] = None
    precio_venta: float
    precio_costo: Optional[float] = None
    categoria_id: Optional[int] = None
    categoria: Optional[CategoriaOut] = None
    stock_minimo: int
    activo: bool

    class Config:
        from_attributes = True


class ProductoCreate(BaseModel):
    codigo_barras: Optional[str] = None
    nombre: str
    descripcion: Optional[str] = None
    precio_venta: float
    precio_costo: Optional[float] = None
    categoria_id: Optional[int] = None
    stock_minimo: int = 5


class ProductoStockOut(ProductoOut):
    stock_actual: int = 0
    stock_bajo: bool = False
