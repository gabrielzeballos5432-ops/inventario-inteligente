from sqlalchemy import Column, Index, Integer, String, Boolean, text
from sqlalchemy.orm import relationship

from app.db.base import Base


class Marca(Base):
    __tablename__ = "marca"

    # Mismo criterio que categorias: la unicidad va en un indice sobre
    # LOWER(nombre) porque el UNIQUE de la columna distingue mayusculas y
    # permitiria registrar "Loreal" y "loreal" como dos marcas distintas.
    # La expresion va como texto porque __table_args__ se evalua antes de que
    # exista el atributo `nombre`.
    __table_args__ = (
        Index("uq_marca_nombre_lower", text("lower(nombre)"), unique=True),
    )

    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(100), nullable=False)
    activo = Column(Boolean, nullable=False, default=True)

    productos = relationship("Producto", back_populates="marca")