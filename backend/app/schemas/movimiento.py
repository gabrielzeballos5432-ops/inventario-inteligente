from pydantic import BaseModel, Field, model_validator
from typing import Optional
from datetime import datetime


class MovimientoOut(BaseModel):
    id: int
    producto_id: int
    producto_nombre: Optional[str] = None
    usuario_id: Optional[int] = None
    usuario_nombre: Optional[str] = None
    sesion_id: Optional[int] = None
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


class MovimientoLoteResultado(BaseModel):
    fila: int
    producto_id: int
    producto_nombre: Optional[str] = None
    movimiento_id: Optional[int] = None
    correcto: bool
    detalle: Optional[str] = None


class MovimientoLoteOut(BaseModel):
    tipo: str
    guardados: int
    resultados: list[MovimientoLoteResultado]