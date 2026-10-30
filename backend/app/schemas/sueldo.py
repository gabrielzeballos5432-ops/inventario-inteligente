from datetime import date, datetime, time
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, model_validator


class RegistroHoraManualCreate(BaseModel):
    usuario_id: int = Field(gt=0)
    fecha: date
    hora_entrada: time
    hora_salida: Optional[time] = None

    @model_validator(mode="after")
    def validar_intervalo(self):
        if self.hora_salida is not None and self.hora_salida <= self.hora_entrada:
            raise ValueError("La hora de salida debe ser posterior a la entrada.")
        return self


class RegistroHoraOut(BaseModel):
    id: int
    usuario_id: int
    fecha: date
    hora_entrada: time
    hora_salida: Optional[time]
    confirmado_por_usuario_id: Optional[int]
    fecha_confirmacion: Optional[datetime]

    model_config = ConfigDict(from_attributes=True)


class LiquidacionSueldoCreate(BaseModel):
    usuario_id: int = Field(gt=0)
    fecha_inicio: date
    fecha_fin: date

    @model_validator(mode="after")
    def validar_periodo(self):
        if self.fecha_fin < self.fecha_inicio:
            raise ValueError("La fecha de fin no puede ser anterior a la fecha de inicio.")
        return self


class LiquidacionSueldoOut(BaseModel):
    id: int
    usuario_id: int
    fecha_inicio: date
    fecha_fin: date
    horas_trabajadas: Decimal
    pago_por_hora_aplicado: Decimal
    porcentaje_comision_aplicado: Decimal
    total_pago_horas: Decimal
    total_comision: Decimal
    total_bonos: Decimal
    total_pagado: Decimal
    estado: str
    fecha_pago: Optional[datetime]
    creado_en: datetime

    model_config = ConfigDict(from_attributes=True)
