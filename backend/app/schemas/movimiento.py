from pydantic import BaseModel, Field, model_validator
from typing import Optional
from datetime import datetime


class MovimientoOut(BaseModel):
    id: int
    producto_id: int
    producto_nombre: Optional[str] = None
    sucursal_id: Optional[int] = None
    sucursal_nombre: Optional[str] = None
    razon_movimiento_id: Optional[int] = None
    razon_nombre: Optional[str] = None
    # En un traspaso: destino (salida) u origen (entrada).
    sucursal_relacionada_id: Optional[int] = None
    sucursal_relacionada_nombre: Optional[str] = None
    usuario_id: Optional[int] = None
    usuario_nombre: Optional[str] = None
    sesion_id: Optional[int] = None
    venta_detalle_id: Optional[int] = None
    compra_detalle_id: Optional[int] = None
    tipo: str
    cantidad_anterior: int
    cantidad: int
    stock_resultante: int
    origen: str
    creado_en: Optional[datetime] = None

    class Config:
        from_attributes = True


class MovimientoCreate(BaseModel):
    producto_id: int
    tipo: str = Field(pattern="^(entrada|salida|ajuste)$")
    # El ajuste fija el stock exacto, por eso admite 0. Entrada y salida no:
    # lo impide el validador de abajo.
    cantidad: int = Field(ge=0)
    origen: str = Field(default="manual", pattern="^(manual|ia)$")
    sesion_id: Optional[int] = None
    # Obligatoria en los movimientos manuales; la valida el servicio para
    # devolver un mensaje claro (la IA usa una razón del sistema).
    razon_movimiento_id: Optional[int] = None
    # Solo para razones que envían a otra sucursal ("Salida a sucursal").
    sucursal_destino_id: Optional[int] = None

    @model_validator(mode="after")
    def _validar_cantidad(self) -> "MovimientoCreate":
        if self.tipo in ("entrada", "salida") and self.cantidad <= 0:
            raise ValueError(
                "La cantidad debe ser mayor a 0 para entrada y salida"
            )
        return self


class MovimientoLoteItem(BaseModel):
    producto_id: int
    # El ajuste fija el stock exacto, por eso aqui se admite 0 (fija el stock en
    # cero). Entrada y salida exigen > 0, pero la validacion se hace en el
    # servicio linea a linea para poder devolver numero de fila y nombre del
    # producto, en vez de un 422 generico que no dice que corregir.
    cantidad: int = Field(ge=0)


class MovimientoLoteCreate(BaseModel):
    tipo: str = Field(pattern="^(entrada|salida|ajuste)$")
    # Un lote vacio no tiene sentido: min_length devuelve un 422 con mensaje
    # claro y no deja pasar una recepcion sin lineas.
    items: list[MovimientoLoteItem] = Field(min_length=1)
    # "ia" queda reservado al flujo de reconocimiento (RF-10): una captura
    # detecta varios productos y se guarda todo junto con su sesion de camara.
    origen: str = Field(default="manual", pattern="^(manual|ia)$")
    sesion_id: Optional[int] = None
    # Una razón para todo el lote (mismo tipo, mismo motivo).
    razon_movimiento_id: Optional[int] = None
    sucursal_destino_id: Optional[int] = None
    # La genera la app (cola offline): reenviar el mismo lote con la misma
    # clave devuelve el ya registrado en lugar de mover el stock otra vez.
    clave_idempotencia: Optional[str] = Field(default=None, min_length=8, max_length=100)


class MovimientoLoteResultado(BaseModel):
    fila: int
    producto_id: int
    producto_nombre: Optional[str] = None
    movimiento_id: Optional[int] = None
    correcto: bool
    detalle: Optional[str] = None
    # El producto estaba dado de baja y esta entrada (confirmada desde la
    # deteccion IA) lo volvio a activar.
    reactivado: bool = False


class MovimientoLoteOut(BaseModel):
    tipo: str
    guardados: int
    resultados: list[MovimientoLoteResultado]
    # True si el lote ya estaba registrado con esa clave de idempotencia: la
    # respuesta describe los movimientos de aquel envio, no crea otros.
    repetido: bool = False

def movimiento_out(m) -> MovimientoOut:
    """Arma la salida desde un Movimiento con sus relaciones ya cargadas
    (ver `opciones_detalle_movimiento` en el repositorio)."""
    return MovimientoOut(
        id=m.id,
        producto_id=m.producto_id,
        producto_nombre=m.producto.nombre if m.producto else None,
        sucursal_id=m.sucursal_id,
        sucursal_nombre=m.sucursal.nombre if m.sucursal else None,
        razon_movimiento_id=m.razon_movimiento_id,
        razon_nombre=m.razon.nombre if m.razon else None,
        sucursal_relacionada_id=m.sucursal_relacionada_id,
        sucursal_relacionada_nombre=(
            m.sucursal_relacionada.nombre if m.sucursal_relacionada else None
        ),
        usuario_id=m.usuario_id,
        usuario_nombre=m.usuario.nombre if m.usuario else None,
        sesion_id=m.sesion_id,
        venta_detalle_id=m.venta_detalle_id,
        compra_detalle_id=m.compra_detalle_id,
        tipo=m.tipo,
        cantidad_anterior=m.cantidad_anterior,
        cantidad=m.cantidad,
        stock_resultante=m.stock_resultante,
        origen=m.origen,
        creado_en=m.creado_en,
    )
