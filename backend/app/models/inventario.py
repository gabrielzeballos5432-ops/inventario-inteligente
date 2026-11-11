from sqlalchemy import (
    Column,
    Integer,
    ForeignKey,
    DateTime,
    CheckConstraint,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import relationship

from app.db.base import Base


class Inventario(Base):
    __tablename__ = "inventario"
    __table_args__ = (
        CheckConstraint("cantidad >= 0", name="chk_inventario_cantidad_no_negativa"),
        # El stock se lleva por sucursal: un producto tiene una fila por local.
        UniqueConstraint(
            "producto_id", "sucursal_id", name="uq_inventario_producto_sucursal"
        ),
    )

    id = Column(Integer, primary_key=True, index=True)
    producto_id = Column(
        Integer,
        ForeignKey("producto.id", ondelete="CASCADE"),
        nullable=False,
    )
    sucursal_id = Column(
        Integer, ForeignKey("sucursal.id", ondelete="RESTRICT"), nullable=False
    )
    cantidad = Column(Integer, nullable=False, default=0)
    actualizado_en = Column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    producto = relationship("Producto", back_populates="inventarios")
    sucursal = relationship("Sucursal")