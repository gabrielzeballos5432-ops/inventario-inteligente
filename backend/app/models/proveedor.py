from sqlalchemy import Column, Index, Integer, String, Boolean, text
from sqlalchemy.orm import relationship

from app.db.base import Base


class Proveedor(Base):
    __tablename__ = "proveedores"

    # Antes esta tabla no tenia ninguna restriccion de unicidad, lo que
    # permitia registrar el mismo proveedor varias veces. Se aplica el mismo
    # criterio que en categorias y marcas: indice unico sobre LOWER(nombre).
    # La expresion va como texto porque __table_args__ se evalua antes de que
    # exista el atributo `nombre`.
    __table_args__ = (
        Index("uq_proveedores_nombre_lower", text("lower(nombre)"), unique=True),
    )

    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(150), nullable=False)
    contacto = Column(String(100))
    telefono = Column(String(20))
    email = Column(String(100))
    activo = Column(Boolean, nullable=False, default=True)

    productos = relationship("Producto", back_populates="proveedor")