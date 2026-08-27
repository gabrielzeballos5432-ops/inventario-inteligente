from sqlalchemy import Column, Integer, String, Boolean, ForeignKey
from sqlalchemy.orm import relationship

from app.db.base import Base


class Categoria(Base):
    __tablename__ = "categorias"

    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(100), unique=True, nullable=False)
    padre_id = Column(Integer, ForeignKey("categorias.id", ondelete="SET NULL"))
    activo = Column(Boolean, nullable=False, default=True)

    padre = relationship("Categoria", remote_side=[id], back_populates="hijas")
    hijas = relationship("Categoria", back_populates="padre")
    productos = relationship("Producto", back_populates="categoria")