from sqlalchemy import (
    CheckConstraint,
    Column,
    Integer,
    String,
    Boolean,
    ForeignKey,
    DateTime,
    Numeric,
    Index,
    func,
)
from sqlalchemy.orm import relationship

from app.db.base import Base


class Usuario(Base):
    __tablename__ = "usuario"
    __table_args__ = (
        CheckConstraint(
            "pago_por_hora IS NULL OR pago_por_hora > 0",
            name="chk_usuario_pago_por_hora",
        ),
        CheckConstraint(
            "porcentaje_comision IS NULL OR porcentaje_comision BETWEEN 0 AND 100",
            name="chk_usuario_porcentaje_comision",
        ),
    )

    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(100), nullable=False)
    email = Column(String(100), nullable=False)
    password_hash = Column(String(255), nullable=False)
    rol_id = Column(Integer, ForeignKey("rol.id"), nullable=False)
    pago_por_hora = Column(Numeric(10, 2))
    porcentaje_comision = Column(Numeric(5, 2))
    activo = Column(Boolean, nullable=False, default=True)
    creado_en = Column(DateTime(timezone=True), nullable=False, server_default=func.now())

    rol = relationship("Rol", back_populates="usuarios")
    movimientos = relationship("Movimiento", back_populates="usuario")
    sesiones_camara = relationship("SesionCamara", back_populates="usuario")
    ventas = relationship(
        "Venta", foreign_keys="Venta.usuario_id", back_populates="usuario"
    )
    compras = relationship("Compra", back_populates="usuario")
    registros_hora = relationship(
        "RegistroHora", foreign_keys="RegistroHora.usuario_id", back_populates="usuario"
    )
    liquidaciones_sueldo = relationship(
        "LiquidacionSueldo", back_populates="usuario"
    )
    sesiones_caja = relationship(
        "SesionCaja",
        foreign_keys="SesionCaja.usuario_apertura_id",
        back_populates="usuario_apertura",
    )
    bonos_sueldo = relationship("BonoSueldo", back_populates="usuario")
    gastos_registrados = relationship(
        "Gasto",
        foreign_keys="Gasto.usuario_id",
        back_populates="usuario",
    )


Index("uq_usuario_email_lower", func.lower(Usuario.email), unique=True)