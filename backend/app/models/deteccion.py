from sqlalchemy import (
    Column,
    Integer,
    ForeignKey,
    DateTime,
    Numeric,
    CheckConstraint,
    Text,
    func,
)
from sqlalchemy.orm import relationship

from app.db.base import Base


class Deteccion(Base):
    __tablename__ = "deteccion"
    __table_args__ = (
        CheckConstraint("confianza BETWEEN 0 AND 1", name="chk_confianza_rango"),
    )

    id = Column(Integer, primary_key=True, index=True)
    sesion_id = Column(
        Integer,
        ForeignKey("sesion_camara.id", ondelete="CASCADE"),
        nullable=False,
    )
    producto_id = Column(Integer, ForeignKey("producto.id"))
    confianza = Column(Numeric(5, 4), nullable=False)
    imagen_url = Column(Text)
    detectado_en = Column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    sesion = relationship("SesionCamara", back_populates="detecciones")
    producto = relationship("Producto", back_populates="detecciones")