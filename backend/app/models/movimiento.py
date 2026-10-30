from sqlalchemy import (
    Column,
    Integer,
    String,
    ForeignKey,
    DateTime,
    CheckConstraint,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import relationship

from app.db.base import Base


class Movimiento(Base):
    __tablename__ = "movimiento"
    __table_args__ = (
        CheckConstraint(
            "tipo IN ('entrada', 'salida', 'ajuste')", name="chk_movimiento_tipo"
        ),
        CheckConstraint("cantidad_anterior >= 0", name="chk_cantidad_anterior_no_negativa"),
        # El ajuste fija el stock exacto, por eso 0 es una cantidad valida para
        # ese tipo (producto agotado); entrada y salida exigen > 0. Validar
        # tambien aqui, no solo en el schema de Pydantic.
        CheckConstraint(
            "(cantidad > 0 OR tipo = 'ajuste')",
            name="chk_movimiento_cantidad_positiva",
        ),
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
        UniqueConstraint("venta_detalle_id", name="uq_movimiento_venta_detalle"),
        UniqueConstraint("compra_detalle_id", name="uq_movimiento_compra_detalle"),
        CheckConstraint(
            "movimiento_revertido_id IS NULL OR tipo IN ('entrada', 'salida')",
            name="chk_movimiento_reversion_tipo",
        ),
        CheckConstraint(
            "venta_detalle_id IS NULL OR compra_detalle_id IS NULL",
            name="chk_movimiento_un_solo_documento",
        ),
    )

    id = Column(Integer, primary_key=True, index=True)
    producto_id = Column(Integer, ForeignKey("producto.id"), nullable=False)
    usuario_id = Column(Integer, ForeignKey("usuario.id"))
    sesion_id = Column(
        Integer, ForeignKey("sesion_camara.id", ondelete="SET NULL")
    )
    venta_detalle_id = Column(
        Integer, ForeignKey("venta_detalle.id", ondelete="RESTRICT")
    )
    compra_detalle_id = Column(
        Integer, ForeignKey("compra_detalle.id", ondelete="RESTRICT")
    )
    movimiento_revertido_id = Column(
        Integer, ForeignKey("movimiento.id", ondelete="RESTRICT")
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
    venta_detalle = relationship("VentaDetalle", back_populates="movimientos")
    compra_detalle = relationship("CompraDetalle", back_populates="movimiento")
    movimiento_revertido = relationship(
        "Movimiento", remote_side=[id], back_populates="reversiones"
    )
    reversiones = relationship("Movimiento", back_populates="movimiento_revertido")