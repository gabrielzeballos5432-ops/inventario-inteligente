import asyncio
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock, patch

import pytest
from pydantic import ValidationError

from app.schemas.contabilidad import PagoGastoMixtoCreate
from app.services.contabilidad_service import ContabilidadService, ContabilidadValidationError


@pytest.mark.parametrize("pagos", [
    [], [{"metodo_pago": "otro", "monto": "10"}],
    [{"metodo_pago": "qr", "monto": "10"}] * 2,
    [{"metodo_pago": "efectivo", "monto": "0"}],
])
def test_rechaza_combinaciones_invalidas(pagos):
    with pytest.raises(ValidationError):
        PagoGastoMixtoCreate(pagos=pagos)


@pytest.mark.parametrize("total,previo,estado", [("100", "0", "pagado"), ("50", "20", "pendiente")])
def test_mixto_un_solo_commit_y_caja_solo_efectivo(total, previo, estado):
    gasto = SimpleNamespace(
        id=1, estado="pendiente", moneda_codigo="BOB", monto=Decimal("100"),
        tipo_cambio_ext=Decimal("1"), tipo_cambio_bob=Decimal("1"), sucursal_id=1,
    )
    db = SimpleNamespace(
        execute=AsyncMock(side_effect=[
            Mock(scalar_one_or_none=Mock(return_value=gasto)),
            Mock(scalar_one=Mock(return_value=Decimal(previo))),
            Mock(scalar_one_or_none=Mock(return_value=7)),
        ]),
        get=AsyncMock(return_value=SimpleNamespace(decimales=2)),
        add_all=Mock(), commit=AsyncMock(), refresh=AsyncMock(),
    )
    datos = PagoGastoMixtoCreate(pagos=[
        {"metodo_pago": "efectivo", "monto": "20"},
        {"metodo_pago": "qr", "monto": str(Decimal(total) - 20)},
    ])
    with patch("app.services.contabilidad_service.CajaService.validar_caja_venta", new_callable=AsyncMock):
        pagos = asyncio.run(ContabilidadService(db).registrar_pagos_gasto(1, datos.pagos, 1))
    assert [p.sesion_caja_id for p in pagos] == [7, None]
    assert sum(p.monto_bob for p in pagos) == Decimal(total)
    assert gasto.estado == estado
    db.commit.assert_awaited_once()


def test_sin_caja_no_guarda_ni_la_parte_qr():
    gasto = SimpleNamespace(
        id=1, estado="pendiente", moneda_codigo="BOB", monto=Decimal("100"),
        tipo_cambio_ext=Decimal("1"), tipo_cambio_bob=Decimal("1"), sucursal_id=1,
    )
    db = SimpleNamespace(
        execute=AsyncMock(side_effect=[
            Mock(scalar_one_or_none=Mock(return_value=gasto)),
            Mock(scalar_one=Mock(return_value=Decimal("0"))),
            Mock(scalar_one_or_none=Mock(return_value=None)),
        ]),
        get=AsyncMock(return_value=SimpleNamespace(decimales=2)),
        add_all=Mock(), commit=AsyncMock(),
    )
    datos = PagoGastoMixtoCreate(pagos=[
        {"metodo_pago": "qr", "monto": "30"},
        {"metodo_pago": "efectivo", "monto": "20"},
    ])
    with pytest.raises(ContabilidadValidationError, match="Abre"):
        asyncio.run(ContabilidadService(db).registrar_pagos_gasto(1, datos.pagos, 1))
    db.add_all.assert_not_called()
    db.commit.assert_not_awaited()
