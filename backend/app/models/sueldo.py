from sqlalchemy import (
    CheckConstraint,
    Column,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Time,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.orm import relationship

from app.db.base import Base


class RegistroHora(Base):
    __tablename__ = "registro_hora"
    __table_args__ = (
        CheckConstraint(
            "hora_salida IS NULL OR hora_salida > hora_entrada",
            name="chk_registro_hora_intervalo",
        ),
        UniqueConstraint("usuario_id", "fecha", name="uq_registro_hora_usuario_fecha"),
        Index("idx_registro_hora_fecha", "fecha"),
    )

    id = Column(Integer, primary_key=True)
    usuario_id = Column(Integer, ForeignKey("usuario.id"), nullable=False)
    fecha = Column(Date, nullable=False)
    hora_entrada = Column(Time, nullable=False)
    hora_salida = Column(Time)
    confirmado_por_usuario_id = Column(Integer, ForeignKey("usuario.id"))
    fecha_confirmacion = Column(DateTime(timezone=True))

    usuario = relationship(
        "Usuario", foreign_keys=[usuario_id], back_populates="registros_hora"
    )
    confirmado_por = relationship("Usuario", foreign_keys=[confirmado_por_usuario_id])


class LiquidacionSueldo(Base):
    __tablename__ = "liquidacion_sueldo"
    __table_args__ = (
        CheckConstraint("fecha_fin >= fecha_inicio", name="chk_liquidacion_periodo"),
        CheckConstraint(
            "horas_trabajadas >= 0", name="chk_liquidacion_horas_no_negativas"
        ),
        CheckConstraint(
            "pago_por_hora_aplicado > 0",
            name="chk_liquidacion_tarifa_positiva",
        ),
        CheckConstraint(
            "porcentaje_comision_aplicado BETWEEN 0 AND 100",
            name="chk_liquidacion_porcentaje_comision",
        ),
        CheckConstraint("total_pago_horas >= 0", name="chk_liquidacion_pago_horas"),
        CheckConstraint("total_comision >= 0", name="chk_liquidacion_comision"),
        CheckConstraint("total_bonos >= 0", name="chk_liquidacion_bonos"),
        CheckConstraint("total_pagado >= 0", name="chk_liquidacion_total"),
        CheckConstraint(
            "estado IN ('pendiente', 'pagado')", name="chk_liquidacion_estado"
        ),
        UniqueConstraint(
            "usuario_id",
            "fecha_inicio",
            "fecha_fin",
            name="uq_liquidacion_usuario_periodo",
        ),
        Index("idx_liquidacion_usuario_periodo", "usuario_id", "fecha_inicio", "fecha_fin"),
    )

    id = Column(Integer, primary_key=True)
    usuario_id = Column(Integer, ForeignKey("usuario.id"), nullable=False)
    fecha_inicio = Column(Date, nullable=False)
    fecha_fin = Column(Date, nullable=False)
    horas_trabajadas = Column(Numeric(8, 2), nullable=False)
    pago_por_hora_aplicado = Column(Numeric(10, 2), nullable=False)
    porcentaje_comision_aplicado = Column(Numeric(5, 2), nullable=False)
    total_pago_horas = Column(Numeric(12, 2), nullable=False)
    total_comision = Column(Numeric(12, 2), nullable=False)
    total_bonos = Column(Numeric(12, 2), nullable=False, default=0, server_default=text("0"))
    total_pagado = Column(Numeric(12, 2), nullable=False)
    estado = Column(
        String(20),
        nullable=False,
        default="pendiente",
        server_default=text("'pendiente'"),
    )
    fecha_pago = Column(DateTime(timezone=True))
    creado_en = Column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    usuario = relationship("Usuario", back_populates="liquidaciones_sueldo")
    bonos = relationship("BonoSueldo", back_populates="liquidacion_sueldo")
