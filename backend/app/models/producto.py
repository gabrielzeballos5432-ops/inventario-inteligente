from sqlalchemy import Column, Integer, String, Float, Boolean, ForeignKey, DateTime, func
from sqlalchemy.orm import relationship

from app.db.base import Base


class Producto(Base):
    __tablename__ = "productos"

    id = Column(Integer, primary_key=True, index=True)
    codigo_barras = Column(String(50), unique=True, nullable=True)
    nombre = Column(String(200), nullable=False)
    descripcion = Column(String(500))
    precio_venta = Column(Float, nullable=False, default=0.0)
    precio_costo = Column(Float, default=0.0)
    categoria_id = Column(Integer, ForeignKey("categorias.id"), nullable=True)
    imagen_url = Column(String(500))
    stock_minimo = Column(Integer, default=5)
    activo = Column(Boolean, default=True)
    creado_en = Column(DateTime(timezone=True), server_default=func.now())

    categoria = relationship("Categoria", back_populates="productos")
    inventario = relationship("Inventario", back_populates="producto", uselist=False)
    movimientos = relationship("Movimiento", back_populates="producto")
