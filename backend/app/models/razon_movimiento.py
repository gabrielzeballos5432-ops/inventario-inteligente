from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    Index,
    Integer,
    String,
    func,
    select,
    text,
)

from app.db.base import Base


class RazonMovimiento(Base):
    """Motivo de un movimiento de inventario (entrada, salida o ajuste).

    Las razones con `sistema = true` las asigna el propio backend (venta,
    compra, anulación, stock inicial, detección IA, traspaso): no aparecen en
    el selector manual y no se pueden editar ni desactivar. `codigo` identifica
    las razones creadas por la migración para que el seed sea idempotente
    aunque el administrador las renombre.
    """

    __tablename__ = "razon_movimiento"
    __table_args__ = (
        CheckConstraint(
            "tipo_movimiento IN ('entrada', 'salida', 'ajuste')",
            name="chk_razon_movimiento_tipo",
        ),
        # Solo una salida puede mandar mercadería a otra sucursal.
        CheckConstraint(
            "NOT requiere_sucursal_destino OR tipo_movimiento = 'salida'",
            name="chk_razon_movimiento_destino_salida",
        ),
        Index(
            "uq_razon_movimiento_nombre_tipo",
            text("lower(nombre)"),
            "tipo_movimiento",
            unique=True,
        ),
    )

    id = Column(Integer, primary_key=True, index=True)
    codigo = Column(String(40), unique=True)
    nombre = Column(String(100), nullable=False)
    tipo_movimiento = Column(String(20), nullable=False)
    sistema = Column(Boolean, nullable=False, default=False, server_default=text("false"))
    requiere_sucursal_destino = Column(
        Boolean, nullable=False, default=False, server_default=text("false")
    )
    activo = Column(Boolean, nullable=False, default=True, server_default=text("true"))
    creado_en = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    actualizado_en = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )


# Razones que crea la migración (y el seed, si faltan): (codigo, nombre, tipo,
# sistema, requiere_sucursal_destino).
RAZONES_PREDEFINIDAS: list[tuple[str, str, str, bool, bool]] = [
    ("ingreso_proveedor", "Ingreso desde proveedor", "entrada", False, False),
    ("devolucion_sucursal", "Devolución de sucursal", "entrada", False, False),
    ("devolucion_cliente", "Devolución de cliente", "entrada", False, False),
    ("reposicion_falla", "Reposición por falla", "entrada", False, False),
    ("salida_sucursal", "Salida a sucursal", "salida", False, True),
    ("salida_falla", "Salida por falla", "salida", False, False),
    ("salida_cambio_cliente", "Salida por cambio a cliente", "salida", False, False),
    ("salida_tester", "Salida para tester", "salida", False, False),
    ("salida_extravio", "Salida por extravío", "salida", False, False),
    ("ajuste_desglose", "Ajuste por desglose", "ajuste", False, False),
    # Del sistema: se asignan solas en los movimientos automáticos.
    ("venta", "Venta", "salida", True, False),
    ("anulacion_venta", "Anulación de venta", "entrada", True, False),
    ("compra", "Compra", "entrada", True, False),
    ("stock_inicial", "Stock inicial", "entrada", True, False),
    ("deteccion_ia_entrada", "Detección IA", "entrada", True, False),
    ("deteccion_ia_salida", "Detección IA", "salida", True, False),
    ("traspaso_entrada", "Ingreso por traspaso", "entrada", True, False),
    # Movimientos registrados antes de que existieran las razones.
    ("historico_entrada", "Registro previo", "entrada", True, False),
    ("historico_salida", "Registro previo", "salida", True, False),
    ("historico_ajuste", "Registro previo", "ajuste", True, False),
]


def razon_sistema(codigo: str):
    """Subconsulta con el id de una razón por su código.

    Se asigna directo a `Movimiento.razon_movimiento_id`: el INSERT resuelve el
    id en la base sin una consulta extra desde Python. Si el código no
    existiera, el NOT NULL de la columna rechaza el movimiento.
    """
    return (
        select(RazonMovimiento.id)
        .where(RazonMovimiento.codigo == codigo)
        .scalar_subquery()
    )
