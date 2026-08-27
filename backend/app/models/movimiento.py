from sqlalchemy import (
    Column,
    Integer,
    String,
    ForeignKey,
    DateTime,
    CheckConstraint,
    func,
)
from sqlalchemy.orm import relationship

from app.db.base import Base


class Movimiento(Base):
    __tablename__ = "movimientos"
    __table_args__ = (
        CheckConstraint(
            "tipo IN ('entrada', 'salida', 'ajuste')", name="chk_movimiento_tipo"
        ),
        CheckConstraint("cantidad_anterior >= 0", name="chk_cantidad_anterior_no_negativa"),
        CheckConstraint("cantidad > 0", name="chk_movimiento_cantidad_positiva"),
        CheckConstraint(
            "stock_resultante >= 0", name="chk_stock_resultante_no_negativo"
        ),
        CheckConstraint(
            "origen IN ('manual', 'ia')", name="chk_movimiento_origen"
        ),
        CheckConstraint(
            "(tipo = 'entrada' AND stock_resultante = cantidad_anterior + cantidad) "
            "OR (tipo = 'salida' AND stock_resultante = cantidad_anterior - cantidad) "
            "OR (tipo = 'ajuste')",
            name="chk_consistencia_movimiento",
        ),
    )

    id = Column(Integer, primary_key=True, index=True)
    producto_id = Column(Integer, ForeignKey("productos.id"), nullable=False)
    usuario_id = Column(Integer, ForeignKey("usuarios.id"))
    sesion_id = Column(
        Integer, ForeignKey("sesiones_camara.id", ondelete="SET NULL")
    )
    tipo = Column(String(20), nullable=False)
    cantidad_anterior = Column(Integer, nullable=False)
    cantidad = Column(Integer, nullable=False)
    stock_resultante = Column(Integer, nullable=False)
    origen = Column(String(10), nullable=False)
    creado_en = Column(DateTime(timezone=True), nullable=False, server_default=func.now())

    producto = relationship("Producto", back_populates="movimientos")
    usuario = relationship("Usuario", back_populates="movimientos")
    sesion = relationship("SesionCamara", back_populates="movimientos")