from datetime import date, datetime
from decimal import Decimal
from typing import Annotated, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

Porcentaje = Annotated[Decimal, Field(ge=0, le=100, max_digits=5, decimal_places=2)]
MontoBob = Annotated[Decimal, Field(gt=0, max_digits=14, decimal_places=2)]


class BonoSueldoCreate(BaseModel):
    usuario_id: int = Field(gt=0)
    liquidacion_sueldo_id: Optional[int] = Field(default=None, gt=0)
    tipo_bono: Literal["live", "almuerzo", "navidad", "otro"]
    descripcion: Optional[str] = Field(default=None, max_length=250)
    monto: MontoBob


class BonoSueldoOut(BaseModel):
    id: int
    usuario_id: int
    liquidacion_sueldo_id: Optional[int]
    tipo_bono: str
    descripcion: Optional[str]
    monto: Decimal
    fecha_registro: datetime

    model_config = ConfigDict(from_attributes=True)


class CategoriaGastoCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=100)
    periodicidad: Literal["sin_periodicidad", "mensual", "semanal", "anual"]
    tipo_importe: Literal["fijo", "variable"]
    monto_habitual: Optional[MontoBob] = None

    @field_validator("nombre")
    @classmethod
    def limpiar_nombre(cls, valor: str) -> str:
        valor = " ".join(valor.split())
        if not valor:
            raise ValueError("Escribe el nombre de la categoría.")
        return valor

    @model_validator(mode="after")
    def validar_monto(self):
        if self.tipo_importe == "variable" and self.monto_habitual is not None:
            raise ValueError("Un importe variable no debe tener monto fijo habitual.")
        return self


class CategoriaGastoUpdate(CategoriaGastoCreate):
    activo: bool = True


class CategoriaGastoOut(CategoriaGastoUpdate):
    id: int
    model_config = ConfigDict(from_attributes=True)


class GastoCreate(BaseModel):
    categoria: Optional[Literal[
        "servicio", "alquiler", "insumo_limpieza", "mantenimiento", "otro"
    ]] = None
    categoria_gasto_id: Optional[int] = Field(default=None, gt=0)
    concepto: str = Field(min_length=1, max_length=200)
    proveedor_id: Optional[int] = Field(default=None, gt=0)
    fecha_documento: Optional[date] = None
    periodo_desde: Optional[date] = None
    periodo_hasta: Optional[date] = None
    numero_documento: Optional[str] = Field(default=None, max_length=100)
    moneda_codigo: str = Field(min_length=3, max_length=3, pattern=r"^[A-Z]{3}$")
    monto: Decimal = Field(gt=0, max_digits=18, decimal_places=4)
    tipo_cambio_ext: Decimal = Field(gt=0, max_digits=18, decimal_places=6)
    tipo_cambio_bob: Decimal = Field(gt=0, max_digits=18, decimal_places=6)
    soporte_url: Optional[str] = None

    @model_validator(mode="after")
    def validar_periodo(self):
        if self.categoria is None and self.categoria_gasto_id is None:
            raise ValueError("Selecciona la categoría del gasto.")
        if (
            self.periodo_desde is not None
            and self.periodo_hasta is not None
            and self.periodo_hasta < self.periodo_desde
        ):
            raise ValueError("El período del gasto no es válido.")
        return self


class PagoGastoCreate(BaseModel):
    monto: Decimal = Field(gt=0, max_digits=18, decimal_places=4)
    metodo_pago: Literal["efectivo", "transferencia", "qr", "otro"]
    sesion_caja_id: Optional[int] = Field(default=None, gt=0)
    referencia: Optional[str] = Field(default=None, max_length=150)


class PagoGastoOut(BaseModel):
    id: int
    gasto_id: int
    sesion_caja_id: Optional[int]
    fecha_pago: datetime
    monto: Decimal
    monto_bob: Decimal
    metodo_pago: str
    referencia: Optional[str]

    model_config = ConfigDict(from_attributes=True)


class PagoGastoMixtoCreate(BaseModel):
    pagos: list[PagoGastoCreate] = Field(min_length=1, max_length=2)

    @model_validator(mode="after")
    def validar_metodos(self):
        metodos = [p.metodo_pago for p in self.pagos]
        if any(m not in ("efectivo", "qr") for m in metodos):
            raise ValueError("Solo se admite efectivo o QR.")
        if len(set(metodos)) != len(metodos):
            raise ValueError("No repitas el método de pago.")
        return self


class GastoOut(BaseModel):
    id: int
    categoria: str
    categoria_gasto_id: Optional[int] = None
    concepto: str
    proveedor_id: Optional[int]
    usuario_id: int
    sucursal_id: Optional[int] = None
    fecha_documento: Optional[date]
    periodo_desde: Optional[date]
    periodo_hasta: Optional[date]
    numero_documento: Optional[str]
    moneda_codigo: str
    monto: Decimal
    tipo_cambio_ext: Decimal
    tipo_cambio_bob: Decimal
    monto_bob: Decimal
    saldo_pendiente_bob: Decimal
    soporte_url: Optional[str]
    anulado_en: Optional[datetime]
    anulada_por_usuario_id: Optional[int]
    motivo_anulacion: Optional[str]
    estado: str
    fecha_creacion: datetime
    pagos: list[PagoGastoOut]

    model_config = ConfigDict(from_attributes=True)


class GastoAnular(BaseModel):
    motivo: str = Field(min_length=3, max_length=250)


class ReporteFinancieroOut(BaseModel):
    fecha_inicio: date
    fecha_fin: date
    ventas_netas_bob: Decimal
    costo_ventas_bob: Optional[Decimal]
    costo_historico_completo: bool
    detalles_sin_costo_historico: int
    ganancia_bruta_bob: Optional[Decimal]
    gastos_operativos_bob: Decimal
    sueldos_y_bonos_bob: Decimal
    utilidad_operativa_bob: Optional[Decimal]
    cargos_adicionales_bob: Decimal
    utilidad_neta_estimada_bob: Optional[Decimal]
    moneda: str = "BOB"
    # None = todas las sucursales.
    sucursal_id: Optional[int] = None
    nota: str
