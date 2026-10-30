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


class SesionCamara(Base):
    __tablename__ = "sesion_camara"
    __table_args__ = (
        CheckConstraint(
            "tipo_operacion IN ('entrada', 'salida', 'conteo')",
            name="chk_sesion_tipo_operacion",
        ),
        CheckConstraint(
            "productos_detectados >= 0", name="chk_productos_detectados_no_negativo"
        ),
        CheckConstraint(
            "fecha_fin IS NULL OR fecha_fin >= fecha_inicio", name="chk_fechas_sesion"
        ),
    )

    id = Column(Integer, primary_key=True, index=True)
    usuario_id = Column(Integer, ForeignKey("usuario.id"))
    tipo_operacion = Column(String(50), nullable=False)
    fecha_inicio = Column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    fecha_fin = Column(DateTime(timezone=True))
    productos_detectados = Column(Integer, nullable=False, default=0)

    usuario = relationship("Usuario", back_populates="sesiones_camara")
    movimientos = relationship("Movimiento", back_populates="sesion")
    detecciones = relationship("Deteccion", back_populates="sesion")