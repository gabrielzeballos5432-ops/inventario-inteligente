from sqlalchemy import Column, Integer, ForeignKey, DateTime, CheckConstraint, func
from sqlalchemy.orm import relationship

from app.db.base import Base


class Inventario(Base):
    __tablename__ = "inventario"
    __table_args__ = (
        CheckConstraint("cantidad >= 0", name="chk_inventario_cantidad_no_negativa"),
    )

    id = Column(Integer, primary_key=True, index=True)
    producto_id = Column(
        Integer,
        ForeignKey("producto.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    cantidad = Column(Integer, nullable=False, default=0)
    actualizado_en = Column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    producto = relationship("Producto", back_populates="inventario")