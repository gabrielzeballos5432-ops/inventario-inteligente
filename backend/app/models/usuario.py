from sqlalchemy import (
    Column,
    Integer,
    String,
    Boolean,
    ForeignKey,
    DateTime,
    Index,
    func,
)
from sqlalchemy.orm import relationship

from app.db.base import Base


class Usuario(Base):
    __tablename__ = "usuarios"

    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(100), nullable=False)
    email = Column(String(100), nullable=False)
    password_hash = Column(String(255), nullable=False)
    rol_id = Column(Integer, ForeignKey("roles.id"), nullable=False)
    activo = Column(Boolean, nullable=False, default=True)
    creado_en = Column(DateTime(timezone=True), nullable=False, server_default=func.now())

    rol = relationship("Rol", back_populates="usuarios")
    movimientos = relationship("Movimiento", back_populates="usuario")
    sesiones_camara = relationship("SesionCamara", back_populates="usuario")


Index("uq_usuarios_email_lower", func.lower(Usuario.email), unique=True)