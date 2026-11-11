from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    func,
    text,
)
from sqlalchemy.orm import relationship

from app.db.base import Base


class Cliente(Base):
    __tablename__ = "cliente"
    __table_args__ = (
        Index("uq_cliente_email_lower", text("lower(email)"), unique=True),
    )

    id = Column(Integer, primary_key=True)
    nombre = Column(String(150), nullable=False)
    telefono = Column(String(30))
    email = Column(String(150))
    creado_en = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    activo = Column(Boolean, nullable=False, default=True, server_default=text("true"))

    ventas = relationship("Venta", back_populates="cliente")


class SesionCaja(Base):
    __tablename__ = "sesion_caja"
    __table_args__ = (
        CheckConstraint("monto_inicial >= 0", name="chk_sesion_caja_monto_inicial"),
        CheckConstraint(
            "monto_efectivo_contado IS NULL OR monto_efectivo_contado >= 0",
            name="chk_sesion_caja_monto_contado",
        ),
        CheckConstraint(
            "monto_esperado_cierre IS NULL OR monto_esperado_cierre >= 0",
            name="chk_sesion_caja_monto_esperado",
        ),
        CheckConstraint(
            "fecha_cierre IS NULL OR fecha_cierre >= fecha_apertura",
            name="chk_sesion_caja_fechas",
        ),
        CheckConstraint(
            "estado IN ('abierta', 'cerrada')", name="chk_sesion_caja_estado"
        ),
        Index(
            "uq_sesion_caja_usuario_abierta",
            "usuario_apertura_id",
            unique=True,
            postgresql_where=text("estado = 'abierta'"),
        ),
        Index("idx_sesion_caja_fecha", "fecha_apertura"),
    )

    id = Column(Integer, primary_key=True)
    usuario_apertura_id = Column(Integer, ForeignKey("usuario.id"), nullable=False)
    # La caja es de un local: las ventas y pagos en efectivo solo se ligan a
    # una sesión de la misma sucursal, para que el cierre de cada local cuadre.
    sucursal_id = Column(Integer, ForeignKey("sucursal.id"), nullable=False)
    usuario_cierre_id = Column(Integer, ForeignKey("usuario.id"))
    fecha_apertura = Column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    fecha_cierre = Column(DateTime(timezone=True))
    monto_inicial = Column(Numeric(12, 2), nullable=False, default=0)
    monto_esperado_cierre = Column(Numeric(12, 2))
    monto_efectivo_contado = Column(Numeric(12, 2))
    observacion_cierre = Column(String(250))
    estado = Column(
        String(20), nullable=False, default="abierta", server_default=text("'abierta'")
    )

    usuario_apertura = relationship(
        "Usuario", foreign_keys=[usuario_apertura_id], back_populates="sesiones_caja"
    )
    usuario_cierre = relationship("Usuario", foreign_keys=[usuario_cierre_id])
    ventas = relationship("Venta", back_populates="sesion_caja")
    pagos_venta = relationship("PagoVenta", back_populates="sesion_caja")
    pagos_gasto = relationship("PagoGasto", back_populates="sesion_caja")
