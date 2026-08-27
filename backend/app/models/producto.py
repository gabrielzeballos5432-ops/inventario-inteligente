from sqlalchemy import (
    Column,
    Integer,
    String,
    Boolean,
    ForeignKey,
    DateTime,
    Numeric,
    CheckConstraint,
    Text,
    func,
)
from sqlalchemy.orm import relationship

from app.db.base import Base


class Producto(Base):
    __tablename__ = "productos"
    __table_args__ = (
        CheckConstraint("precio_compra >= 0", name="chk_precio_compra_no_negativo"),
        CheckConstraint("precio_venta >= 0", name="chk_precio_venta_no_negativo"),
        CheckConstraint("stock_minimo >= 0", name="chk_stock_minimo_no_negativo"),
    )

    id = Column(Integer, primary_key=True, index=True)
    sku = Column(String(50), unique=True)
    codigo_barras = Column(String(50), unique=True)
    nombre = Column(String(200), nullable=False)
    descripcion = Column(Text)
    categoria_id = Column(Integer, ForeignKey("categorias.id"))
    marca_id = Column(Integer, ForeignKey("marcas.id"))
    proveedor_id = Column(Integer, ForeignKey("proveedores.id"))
    precio_compra = Column(Numeric(10, 2), nullable=False, default=0)
    precio_venta = Column(Numeric(10, 2), nullable=False, default=0)
    stock_minimo = Column(Integer, nullable=False, default=5)
    imagen_url = Column(Text)
    activo = Column(Boolean, nullable=False, default=True)
    creado_en = Column(DateTime(timezone=True), nullable=False, server_default=func.now())

    categoria = relationship("Categoria", back_populates="productos")
    marca = relationship("Marca", back_populates="productos")
    proveedor = relationship("Proveedor", back_populates="productos")
    inventario = relationship("Inventario", back_populates="producto", uselist=False)
    movimientos = relationship("Movimiento", back_populates="producto")
    detecciones = relationship("Deteccion", back_populates="producto")