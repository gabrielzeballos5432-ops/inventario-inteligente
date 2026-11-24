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
    __tablename__ = "producto"
    __table_args__ = (
        CheckConstraint("precio_compra >= 0", name="chk_precio_compra_no_negativo"),
        CheckConstraint("precio_venta >= 0", name="chk_precio_venta_no_negativo"),
        CheckConstraint(
            "precio_mayor IS NULL OR precio_mayor > 0", name="chk_precio_mayor_positivo"
        ),
        CheckConstraint("stock_minimo >= 0", name="chk_stock_minimo_no_negativo"),
    )

    id = Column(Integer, primary_key=True, index=True)
    sku = Column(String(50), unique=True)
    codigo_barras = Column(String(50), unique=True)
    nombre = Column(String(200), nullable=False)
    descripcion = Column(Text)
    categoria_id = Column(Integer, ForeignKey("categoria.id"))
    marca_id = Column(Integer, ForeignKey("marca.id"))
    proveedor_id = Column(Integer, ForeignKey("proveedor.id"))
    precio_compra = Column(Numeric(10, 2), nullable=False, default=0)
    precio_venta = Column(Numeric(10, 2), nullable=False, default=0)
    precio_mayor = Column(Numeric(10, 2))
    stock_minimo = Column(Integer, nullable=False, default=5)
    imagen_url = Column(Text)
    activo = Column(Boolean, nullable=False, default=True)
    creado_en = Column(DateTime(timezone=True), nullable=False, server_default=func.now())

    categoria = relationship("Categoria", back_populates="productos")
    marca = relationship("Marca", back_populates="productos")
    proveedor = relationship("Proveedor", back_populates="productos")
    inventarios = relationship("Inventario", back_populates="producto")
    movimientos = relationship("Movimiento", back_populates="producto")
    detecciones = relationship("Deteccion", back_populates="producto")
    ventas_detalle = relationship("VentaDetalle", back_populates="producto")
    compras_detalle = relationship("CompraDetalle", back_populates="producto")