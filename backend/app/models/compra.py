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
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.orm import relationship

from app.db.base import Base


class Moneda(Base):
    __tablename__ = "moneda"
    __table_args__ = (
        CheckConstraint("decimales BETWEEN 0 AND 4", name="chk_moneda_decimales"),
    )

    codigo = Column(String(3), primary_key=True)
    nombre = Column(String(80), nullable=False)
    simbolo = Column(String(10))
    pais = Column(String(80))
    decimales = Column(Integer, nullable=False, default=2, server_default=text("2"))
    activa = Column(Boolean, nullable=False, default=True, server_default=text("true"))

    compras = relationship("Compra", back_populates="moneda")


class Compra(Base):
    __tablename__ = "compra"
    __table_args__ = (
        CheckConstraint("subtotal_moneda >= 0", name="chk_compra_subtotal"),
        CheckConstraint("descuento_moneda >= 0", name="chk_compra_descuento"),
        CheckConstraint(
            "descuento_moneda <= subtotal_moneda",
            name="chk_compra_descuento_no_supera_subtotal",
        ),
        CheckConstraint(
            "base_costo_adicional_moneda >= 0",
            name="chk_compra_base_adicional",
        ),
        CheckConstraint(
            "porcentaje_manipulacion_envio >= 0",
            name="chk_compra_porcentaje_manipulacion",
        ),
        CheckConstraint(
            "costo_manipulacion_envio_moneda >= 0",
            name="chk_compra_costo_manipulacion",
        ),
        CheckConstraint("total_moneda >= 0", name="chk_compra_total_moneda"),
        CheckConstraint("total_bob >= 0", name="chk_compra_total_bob"),
        CheckConstraint("tipo_cambio_ext > 0", name="chk_compra_tipo_cambio_ext"),
        CheckConstraint("tipo_cambio_bob > 0", name="chk_compra_tipo_cambio_bob"),
        CheckConstraint(
            "estado IN ('registrada', 'anulada')", name="chk_compra_estado"
        ),
        Index("idx_compra_proveedor_fecha", "proveedor_id", "fecha_creacion"),
        Index("idx_compra_fecha", "fecha_creacion"),
    )

    id = Column(Integer, primary_key=True)
    proveedor_id = Column(Integer, ForeignKey("proveedor.id"), nullable=True)
    usuario_id = Column(Integer, ForeignKey("usuario.id"), nullable=False)
    moneda_codigo = Column(String(3), ForeignKey("moneda.codigo"), nullable=False)
    tipo_cambio_ext = Column(Numeric(18, 6), nullable=False)
    tipo_cambio_bob = Column(Numeric(18, 6), nullable=False)
    numero_factura = Column(String(100))
    fecha_factura = Column(Date)
    subtotal_moneda = Column(Numeric(18, 4), nullable=False)
    descuento_moneda = Column(
        Numeric(18, 4), nullable=False, default=0, server_default=text("0")
    )
    base_costo_adicional_moneda = Column(Numeric(18, 4), nullable=False)
    porcentaje_manipulacion_envio = Column(
        Numeric(5, 2), nullable=False, default=0, server_default=text("0")
    )
    costo_manipulacion_envio_moneda = Column(Numeric(18, 4), nullable=False)
    total_moneda = Column(Numeric(18, 4), nullable=False)
    total_bob = Column(Numeric(14, 2), nullable=False)
    imagen_factura_url = Column(Text)
    estado = Column(
        String(20),
        nullable=False,
        default="registrada",
        server_default=text("'registrada'"),
    )
    fecha_creacion = Column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    proveedor = relationship("Proveedor", back_populates="compras")
    usuario = relationship("Usuario", back_populates="compras")
    moneda = relationship("Moneda", back_populates="compras")
    detalles = relationship(
        "CompraDetalle", back_populates="compra", cascade="all, delete-orphan"
    )


class CompraDetalle(Base):
    __tablename__ = "compra_detalle"
    __table_args__ = (
        CheckConstraint("cantidad > 0", name="chk_compra_detalle_cantidad"),
        CheckConstraint(
            "costo_unitario_moneda >= 0",
            name="chk_compra_detalle_costo_unitario",
        ),
        CheckConstraint(
            "subtotal_linea_moneda >= 0",
            name="chk_compra_detalle_subtotal_linea",
        ),
        CheckConstraint(
            "costo_unitario_final_bob >= 0",
            name="chk_compra_detalle_costo_final_bob",
        ),
        UniqueConstraint("compra_id", "producto_id", name="uq_compra_producto"),
        Index("idx_compra_detalle_producto", "producto_id"),
    )

    id = Column(Integer, primary_key=True)
    compra_id = Column(
        Integer, ForeignKey("compra.id", ondelete="RESTRICT"), nullable=False
    )
    producto_id = Column(
        Integer, ForeignKey("producto.id", ondelete="RESTRICT"), nullable=False
    )
    descripcion_factura = Column(String(250))
    cantidad = Column(Integer, nullable=False)
    costo_unitario_moneda = Column(Numeric(18, 6), nullable=False)
    subtotal_linea_moneda = Column(Numeric(18, 4), nullable=False)
    costo_unitario_final_bob = Column(Numeric(14, 4), nullable=False)

    compra = relationship("Compra", back_populates="detalles")
    producto = relationship("Producto", back_populates="compras_detalle")
    movimiento = relationship("Movimiento", back_populates="compra_detalle", uselist=False)
