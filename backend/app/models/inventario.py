from sqlalchemy import Column, Integer, ForeignKey, DateTime, func
from sqlalchemy.orm import relationship

from app.db.base import Base


class Inventario(Base):
    __tablename__ = "inventario"

    id = Column(Integer, primary_key=True, index=True)
    producto_id = Column(
        Integer, ForeignKey("productos.id"), unique=True, nullable=False
    )
    cantidad = Column(Integer, nullable=False, default=0)
    actualizado_en = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    producto = relationship("Producto", back_populates="inventario")
