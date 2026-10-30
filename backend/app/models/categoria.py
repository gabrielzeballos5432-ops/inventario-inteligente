from sqlalchemy import Column, Index, Integer, String, Boolean, ForeignKey, text
from sqlalchemy.orm import relationship

from app.db.base import Base


class Categoria(Base):
    __tablename__ = "categoria"

    # El UNIQUE va en un indice sobre LOWER(nombre), no en la columna: un
    # UNIQUE normal en PostgreSQL distingue mayusculas, y eso permitia crear
    # "Uñas", "uñas", "UÑAS" como categorias distintas. Mismo criterio que el
    # ya usado en usuario con uq_usuario_email_lower.
    # La expresion va como texto y no como func.lower(nombre): __table_args__ se
    # evalua al crear la clase, antes de que exista el atributo `nombre`, asi
    # que referenciarlo por su nombre de atributo daria NameError.
    __table_args__ = (
        Index("uq_categoria_nombre_lower", text("lower(nombre)"), unique=True),
    )

    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(100), nullable=False)
    padre_id = Column(Integer, ForeignKey("categoria.id", ondelete="SET NULL"))
    activo = Column(Boolean, nullable=False, default=True)

    padre = relationship("Categoria", remote_side=[id], back_populates="hijas")
    hijas = relationship("Categoria", back_populates="padre")
    productos = relationship("Producto", back_populates="categoria")