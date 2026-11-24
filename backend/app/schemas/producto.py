from pydantic import BaseModel, Field, field_validator
from typing import Annotated, Optional
from decimal import Decimal

from app.schemas.comunes import nombre_obligatorio

# Los topes son los de las columnas. Sin ellos un valor fuera de rango
# llegaba a PostgreSQL y el usuario veia un error del servidor.
Precio = Annotated[
    Decimal, Field(gt=0, le=Decimal("99999999.99"), max_digits=10, decimal_places=2)
]
EnteroStock = Annotated[int, Field(ge=0, le=2_147_483_647)]
Codigo = Annotated[Optional[str], Field(default=None, max_length=50)]


def _codigo_opcional(valor: Optional[str]) -> Optional[str]:
    """Codigo vacio -> None: sku y codigo_barras son UNIQUE, y "" se repetiria
    entre productos sin codigo."""
    if valor is None:
        return None
    texto = valor.strip()
    if not texto:
        return None
    if any(c.isspace() for c in texto):
        raise ValueError("El codigo no puede tener espacios")
    return texto


class _ValidaProducto(BaseModel):
    @field_validator("sku", "codigo_barras", check_fields=False)
    @classmethod
    def validar_codigo(cls, valor: Optional[str]) -> Optional[str]:
        return _codigo_opcional(valor)

    @field_validator("nombre", check_fields=False)
    @classmethod
    def validar_nombre(cls, valor: Optional[str]) -> Optional[str]:
        if valor is None:
            return None
        texto = nombre_obligatorio(valor)
        if not any(c.isalpha() for c in texto):
            raise ValueError("El nombre debe incluir letras, no solo numeros")
        return texto

    @field_validator("descripcion", check_fields=False)
    @classmethod
    def validar_descripcion(cls, valor: Optional[str]) -> Optional[str]:
        if valor is None:
            return None
        return valor.strip() or None


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
    precio_mayor: Optional[Decimal] = None
    stock_minimo: int
    activo: bool

    class Config:
        from_attributes = True


class ProductoCreate(_ValidaProducto):
    sku: Codigo
    codigo_barras: Codigo
    nombre: str = Field(max_length=200)
    descripcion: Optional[str] = Field(default=None, max_length=500)
    categoria_id: Optional[int] = None
    marca_id: Optional[int] = None
    proveedor_id: Optional[int] = None
    # Los precios tienen que ser mayores a 0: un producto con precio 0 falsea
    # la valorizacion del inventario y el margen. El stock minimo si admite 0.
    precio_compra: Precio
    precio_venta: Precio
    precio_mayor: Optional[Precio] = None
    stock_minimo: EnteroStock = 5
    # Stock con el que arranca el producto en la sucursal activa. Si es > 0 se
    # registra una entrada automática con la razón "Stock inicial".
    cantidad_inicial: int = Field(default=0, ge=0, le=2_147_483_647)


class ProductoUpdate(_ValidaProducto):
    sku: Codigo
    codigo_barras: Codigo
    nombre: Optional[str] = Field(default=None, max_length=200)
    descripcion: Optional[str] = Field(default=None, max_length=500)
    categoria_id: Optional[int] = None
    marca_id: Optional[int] = None
    proveedor_id: Optional[int] = None
    precio_compra: Optional[Precio] = None
    precio_venta: Optional[Precio] = None
    precio_mayor: Optional[Precio] = None
    stock_minimo: Optional[EnteroStock] = None
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