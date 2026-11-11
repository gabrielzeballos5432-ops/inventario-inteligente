from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    func,
    text,
)
from sqlalchemy.orm import relationship

from app.db.base import Base


class Sucursal(Base):
    """Local físico del salón. El catálogo de productos es único; el stock,
    las ventas, las compras y los movimientos van por sucursal."""

    __tablename__ = "sucursal"
    # Mismo criterio que categoria: la unicidad del nombre no distingue
    # mayúsculas. La expresión va como texto porque __table_args__ se evalúa
    # antes de que exista el atributo `nombre`.
    __table_args__ = (
        Index("uq_sucursal_nombre_lower", text("lower(nombre)"), unique=True),
    )

    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(100), nullable=False)
    direccion = Column(String(200))
    telefono = Column(String(30))
    activo = Column(Boolean, nullable=False, default=True, server_default=text("true"))
    creado_en = Column(DateTime(timezone=True), nullable=False, server_default=func.now())


class ConfiguracionSistema(Base):
    """Configuración global: una sola fila (id = 1)."""

    __tablename__ = "configuracion_sistema"
    __table_args__ = (
        CheckConstraint("id = 1", name="chk_configuracion_sistema_unica"),
    )

    id = Column(Integer, primary_key=True, default=1)
    sucursal_predeterminada_id = Column(
        Integer, ForeignKey("sucursal.id", ondelete="RESTRICT"), nullable=False
    )
    actualizado_en = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    sucursal_predeterminada = relationship("Sucursal")
