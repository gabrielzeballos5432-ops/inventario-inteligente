from sqlalchemy import (
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    Index,
    Numeric,
    String,
    func,
    text,
)
from sqlalchemy.orm import relationship

from app.db.base import Base


class Venta(Base):
    __tablename__ = "venta"
    __table_args__ = (
        CheckConstraint("total >= 0", name="chk_venta_total_no_negativo"),
        CheckConstraint(
            "tipo_venta IN ('minorista', 'mayorista')",
            name="chk_venta_tipo",
        ),
        CheckConstraint(
            "estado IN ('completada', 'anulada')",
            name="chk_venta_estado",
        ),
        Index("idx_venta_cliente", "cliente_id"),
        Index("idx_venta_sesion_caja", "sesion_caja_id"),
    )

    id = Column(Integer, primary_key=True, index=True)
    fecha_creacion = Column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    usuario_id = Column(Integer, ForeignKey("usuario.id"), nullable=False)
    sucursal_id = Column(Integer, ForeignKey("sucursal.id"), nullable=False)
    cliente_id = Column(Integer, ForeignKey("cliente.id"))
    sesion_caja_id = Column(Integer, ForeignKey("sesion_caja.id"))
    clave_idempotencia = Column(String(100))
    huella_solicitud = Column(String(64))
    tipo_venta = Column(
        String(20), nullable=False, default="minorista", server_default=text("'minorista'")
    )
    total = Column(Numeric(12, 2), nullable=False)
    estado = Column(
        String(20),
        nullable=False,
        default="completada",
        server_default=text("'completada'"),
    )
    anulada_en = Column(DateTime(timezone=True))
    anulada_por_usuario_id = Column(Integer, ForeignKey("usuario.id"))
    motivo_anulacion = Column(String(250))

    usuario = relationship(
        "Usuario", foreign_keys=[usuario_id], back_populates="ventas"
    )
    cliente = relationship("Cliente", back_populates="ventas")
    sesion_caja = relationship("SesionCaja", back_populates="ventas")
    anulada_por = relationship("Usuario", foreign_keys=[anulada_por_usuario_id])
    detalles = relationship("VentaDetalle", back_populates="venta")
    pagos = relationship("PagoVenta", back_populates="venta")


Index(
    "uq_venta_clave_idempotencia",
    Venta.usuario_id,
    Venta.clave_idempotencia,
    unique=True,
    postgresql_where=Venta.clave_idempotencia.is_not(None),
)


class VentaDetalle(Base):
    __tablename__ = "venta_detalle"
    __table_args__ = (
        CheckConstraint("cantidad > 0", name="chk_venta_detalle_cantidad_positiva"),
        CheckConstraint(
            "precio_lista_unitario >= 0",
            name="chk_venta_detalle_precio_lista_no_negativo",
        ),
        CheckConstraint(
            "precio_unitario_negociado >= 0",
            name="chk_venta_detalle_precio_negociado_no_negativo",
        ),
        CheckConstraint(
            "total_linea >= 0", name="chk_venta_detalle_total_no_negativo"
        ),
        CheckConstraint(
            "costo_unitario_bob_aplicado IS NULL OR costo_unitario_bob_aplicado >= 0",
            name="chk_venta_detalle_costo_unitario",
        ),
        CheckConstraint(
            "costo_total_bob_aplicado IS NULL OR costo_total_bob_aplicado >= 0",
            name="chk_venta_detalle_costo_total",
        ),
        CheckConstraint(
            "tipo_promocion IS NULL OR tipo_promocion IN "
            "('oferta', 'combo', 'liquidacion')",
            name="chk_venta_detalle_tipo_promocion",
        ),
    )

    id = Column(Integer, primary_key=True, index=True)
    venta_id = Column(
        Integer, ForeignKey("venta.id", ondelete="RESTRICT"), nullable=False
    )
    producto_id = Column(
        Integer, ForeignKey("producto.id", ondelete="RESTRICT"), nullable=False
    )
    producto_nombre = Column(String(200), nullable=False)
    producto_sku = Column(String(50))
    cantidad = Column(Integer, nullable=False)
    precio_lista_unitario = Column(Numeric(10, 2), nullable=False)
    precio_unitario_negociado = Column(Numeric(10, 2), nullable=False)
    total_linea = Column(Numeric(12, 2), nullable=False)
    costo_unitario_bob_aplicado = Column(Numeric(14, 4))
    costo_total_bob_aplicado = Column(Numeric(14, 2))
    tipo_promocion = Column(String(20))
    observacion_promocion = Column(String(200))

    venta = relationship("Venta", back_populates="detalles")
    producto = relationship("Producto", back_populates="ventas_detalle")
    movimientos = relationship("Movimiento", back_populates="venta_detalle")


class PagoVenta(Base):
    __tablename__ = "pago_venta"
    __table_args__ = (
        CheckConstraint("monto > 0", name="chk_pago_venta_monto_positivo"),
        CheckConstraint(
            "metodo_pago IN ('efectivo', 'qr')",
            name="chk_pago_venta_metodo",
        ),
        CheckConstraint(
            "estado IN ('confirmado', 'anulado')",
            name="chk_pago_venta_estado",
        ),
        Index("idx_pago_venta_sesion_caja", "sesion_caja_id"),
    )

    id = Column(Integer, primary_key=True, index=True)
    venta_id = Column(
        Integer, ForeignKey("venta.id", ondelete="RESTRICT"), nullable=False
    )
    fecha_creacion = Column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    metodo_pago = Column(String(20), nullable=False)
    monto = Column(Numeric(12, 2), nullable=False)
    estado = Column(
        String(20),
        nullable=False,
        default="confirmado",
        server_default=text("'confirmado'"),
    )
    referencia = Column(String(100))
    sesion_caja_id = Column(Integer, ForeignKey("sesion_caja.id"))

    venta = relationship("Venta", back_populates="pagos")
    sesion_caja = relationship("SesionCaja", back_populates="pagos_venta")
