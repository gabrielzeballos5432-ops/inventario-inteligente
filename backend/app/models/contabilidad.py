from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    func,
    text,
)
from sqlalchemy.orm import relationship

from app.db.base import Base


class BonoSueldo(Base):
    __tablename__ = "bono_sueldo"
    __table_args__ = (
        CheckConstraint(
            "tipo_bono IN ('live', 'almuerzo', 'navidad', 'otro')",
            name="chk_bono_sueldo_tipo",
        ),
        CheckConstraint("monto > 0", name="chk_bono_sueldo_monto"),
        Index("idx_bono_sueldo_usuario_fecha", "usuario_id", "fecha_registro"),
    )

    id = Column(Integer, primary_key=True)
    usuario_id = Column(Integer, ForeignKey("usuario.id"), nullable=False)
    liquidacion_sueldo_id = Column(
        Integer, ForeignKey("liquidacion_sueldo.id", ondelete="RESTRICT")
    )
    tipo_bono = Column(String(20), nullable=False)
    descripcion = Column(String(250))
    monto = Column(Numeric(12, 2), nullable=False)
    fecha_registro = Column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    usuario = relationship("Usuario", back_populates="bonos_sueldo")
    liquidacion_sueldo = relationship(
        "LiquidacionSueldo", back_populates="bonos"
    )


class CategoriaGasto(Base):
    __tablename__ = "categoria_gasto"
    __table_args__ = (
        Index("uq_categoria_gasto_nombre_lower", text("lower(nombre)"), unique=True),
        CheckConstraint(
            "periodicidad IN ('sin_periodicidad', 'mensual', 'semanal', 'anual')",
            name="chk_categoria_gasto_periodicidad",
        ),
        CheckConstraint(
            "tipo_importe IN ('fijo', 'variable')", name="chk_categoria_gasto_tipo_importe",
        ),
        CheckConstraint(
            "monto_habitual IS NULL OR (monto_habitual > 0 AND tipo_importe = 'fijo')",
            name="chk_categoria_gasto_monto",
        ),
    )

    id = Column(Integer, primary_key=True)
    nombre = Column(String(100), nullable=False)
    periodicidad = Column(String(20), nullable=False, server_default=text("'sin_periodicidad'"))
    tipo_importe = Column(String(10), nullable=False, server_default=text("'variable'"))
    monto_habitual = Column(Numeric(14, 2))
    activo = Column(Boolean, nullable=False, server_default=text("true"), default=True)


class Gasto(Base):
    __tablename__ = "gasto"
    __table_args__ = (
        CheckConstraint("monto > 0", name="chk_gasto_monto"),
        CheckConstraint("monto_bob > 0", name="chk_gasto_monto_bob"),
        CheckConstraint("tipo_cambio_ext > 0", name="chk_gasto_tipo_cambio_ext"),
        CheckConstraint("tipo_cambio_bob > 0", name="chk_gasto_tipo_cambio_bob"),
        CheckConstraint(
            "periodo_hasta IS NULL OR periodo_desde IS NULL "
            "OR periodo_hasta >= periodo_desde",
            name="chk_gasto_periodo",
        ),
        CheckConstraint(
            "estado IN ('pendiente', 'pagado', 'anulado')",
            name="chk_gasto_estado",
        ),
        Index("idx_gasto_periodo_categoria", "periodo_desde", "categoria"),
        Index("idx_gasto_proveedor", "proveedor_id"),
        Index("idx_gasto_categoria_gasto", "categoria_gasto_id"),
    )

    id = Column(Integer, primary_key=True)
    categoria = Column(String(100), nullable=False)
    categoria_gasto_id = Column(Integer, ForeignKey("categoria_gasto.id", ondelete="RESTRICT"))
    concepto = Column(String(200), nullable=False)
    proveedor_id = Column(Integer, ForeignKey("proveedor.id"))
    usuario_id = Column(Integer, ForeignKey("usuario.id"), nullable=False)
    fecha_documento = Column(Date)
    periodo_desde = Column(Date)
    periodo_hasta = Column(Date)
    numero_documento = Column(String(100))
    moneda_codigo = Column(String(3), ForeignKey("moneda.codigo"), nullable=False)
    monto = Column(Numeric(18, 4), nullable=False)
    tipo_cambio_ext = Column(Numeric(18, 6), nullable=False)
    tipo_cambio_bob = Column(Numeric(18, 6), nullable=False)
    monto_bob = Column(Numeric(14, 2), nullable=False)
    soporte_url = Column(Text)
    anulado_en = Column(DateTime(timezone=True))
    anulada_por_usuario_id = Column(Integer, ForeignKey("usuario.id"))
    motivo_anulacion = Column(String(250))
    estado = Column(
        String(20),
        nullable=False,
        default="pendiente",
        server_default=text("'pendiente'"),
    )
    fecha_creacion = Column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    proveedor = relationship("Proveedor")
    usuario = relationship(
        "Usuario",
        foreign_keys=[usuario_id],
        back_populates="gastos_registrados",
    )
    moneda = relationship("Moneda")
    anulada_por = relationship("Usuario", foreign_keys=[anulada_por_usuario_id])
    pagos = relationship(
        "PagoGasto", back_populates="gasto", cascade="all, delete-orphan"
    )


class PagoGasto(Base):
    __tablename__ = "pago_gasto"
    __table_args__ = (
        CheckConstraint("monto > 0", name="chk_pago_gasto_monto"),
        CheckConstraint("monto_bob > 0", name="chk_pago_gasto_monto_bob"),
        CheckConstraint(
            "metodo_pago IN ('efectivo', 'transferencia', 'qr', 'otro')",
            name="chk_pago_gasto_metodo",
        ),
        Index("idx_pago_gasto_gasto_fecha", "gasto_id", "fecha_pago"),
        Index("idx_pago_gasto_sesion", "sesion_caja_id"),
    )

    id = Column(Integer, primary_key=True)
    gasto_id = Column(Integer, ForeignKey("gasto.id", ondelete="RESTRICT"), nullable=False)
    sesion_caja_id = Column(Integer, ForeignKey("sesion_caja.id"))
    fecha_pago = Column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    monto = Column(Numeric(18, 4), nullable=False)
    monto_bob = Column(Numeric(14, 2), nullable=False)
    metodo_pago = Column(String(30), nullable=False)
    referencia = Column(String(150))

    gasto = relationship("Gasto", back_populates="pagos")
    sesion_caja = relationship("SesionCaja", back_populates="pagos_gasto")
