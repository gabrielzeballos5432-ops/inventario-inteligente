import asyncio
from datetime import date
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock, create_autospec

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.caja import SesionCaja
from app.schemas.caja import SesionCajaAbrir
from app.services.caja_service import CajaService, CajaValidationError
from app.services.contabilidad_service import ContabilidadService


def sesion(**cambios):
    datos = dict(id=7, usuario_apertura_id=1, estado="abierta", sucursal_id=1)
    return SimpleNamespace(**(datos | cambios))


def db_con(*resultados):
    db = create_autospec(AsyncSession, instance=True)
    db.execute.side_effect = list(resultados)
    return db


def test_abrir_caja_queda_en_la_sucursal_activa():
    db = create_autospec(AsyncSession, instance=True)
    db.get.return_value = SimpleNamespace(activo=True)
    db.execute.return_value = Mock(scalar_one_or_none=Mock(return_value=None))
    asyncio.run(CajaService(db).abrir(1, SesionCajaAbrir(monto_inicial="50"), 3))
    abierta = db.add.call_args.args[0]
    assert isinstance(abierta, SesionCaja)
    assert abierta.sucursal_id == 3


def test_caja_de_otra_sucursal_se_rechaza():
    db = db_con(Mock(scalar_one_or_none=Mock(return_value=sesion(sucursal_id=1))))
    with pytest.raises(CajaValidationError, match="otra sucursal"):
        asyncio.run(CajaService(db).validar_caja_venta(1, 7, sucursal_id=2))


def test_caja_de_la_misma_sucursal_se_acepta():
    db = db_con(Mock(scalar_one_or_none=Mock(return_value=sesion(sucursal_id=2))))
    assert asyncio.run(CajaService(db).validar_caja_venta(1, 7, sucursal_id=2)).id == 7


def test_pago_en_efectivo_sin_caja_en_la_sucursal_del_gasto():
    gasto = SimpleNamespace(
        id=1, estado="pendiente", moneda_codigo="BOB", monto=Decimal("100"),
        tipo_cambio_ext=Decimal("1"), tipo_cambio_bob=Decimal("1"), sucursal_id=2,
    )
    db = SimpleNamespace(
        execute=AsyncMock(side_effect=[
            Mock(scalar_one_or_none=Mock(return_value=gasto)),
            Mock(scalar_one=Mock(return_value=Decimal("0"))),
            # No hay caja abierta del usuario en la sucursal 2.
            Mock(scalar_one_or_none=Mock(return_value=None)),
        ]),
        get=AsyncMock(return_value=SimpleNamespace(decimales=2)),
        add_all=Mock(), commit=AsyncMock(),
    )
    from app.schemas.contabilidad import PagoGastoCreate
    from app.services.contabilidad_service import ContabilidadValidationError
    with pytest.raises(ContabilidadValidationError, match="sucursal del gasto"):
        asyncio.run(ContabilidadService(db).registrar_pagos_gasto(
            1, [PagoGastoCreate(metodo_pago="efectivo", monto="20")], 1
        ))
    db.commit.assert_not_awaited()


def reporte(sucursal_id):
    liquidacion = SimpleNamespace(
        fecha_inicio=date(2026, 11, 1), fecha_fin=date(2026, 11, 30),
        total_pagado=Decimal("3000"),
    )
    db = db_con(
        Mock(scalar_one=Mock(return_value=Decimal("1000"))),
        Mock(one=Mock(return_value=(Decimal("600"), 2, 2))),
        Mock(scalar_one=Mock(return_value=Decimal("100"))),
        Mock(scalars=Mock(return_value=[liquidacion])),
    )
    return asyncio.run(ContabilidadService(db).reporte_financiero(
        date(2026, 11, 1), date(2026, 11, 30), sucursal_id
    ))


def test_reporte_de_todas_las_sucursales_incluye_sueldos():
    datos = reporte(None)
    assert datos["sueldos_y_bonos_bob"] == Decimal("3000.00")
    assert datos["utilidad_operativa_bob"] == Decimal("-2700.00")
    assert datos["sucursal_id"] is None


def test_reporte_de_una_sucursal_no_le_carga_los_sueldos_del_negocio():
    datos = reporte(2)
    assert datos["sueldos_y_bonos_bob"] == Decimal("0.00")
    assert datos["utilidad_operativa_bob"] == Decimal("300.00")
    assert datos["sucursal_id"] == 2
    assert "todas las sucursales" in datos["nota"]


def test_pago_en_efectivo_no_puede_superar_el_efectivo_de_la_caja():
    from unittest.mock import patch
    from app.schemas.contabilidad import PagoGastoCreate
    from app.services.contabilidad_service import ContabilidadValidationError
    gasto = SimpleNamespace(
        id=1, estado="pendiente", moneda_codigo="BOB", monto=Decimal("2000"),
        tipo_cambio_ext=Decimal("1"), tipo_cambio_bob=Decimal("1"), sucursal_id=1,
    )
    db = SimpleNamespace(
        execute=AsyncMock(side_effect=[
            Mock(scalar_one_or_none=Mock(return_value=gasto)),
            Mock(scalar_one=Mock(return_value=Decimal("0"))),
            Mock(scalar_one_or_none=Mock(return_value=7)),
        ]),
        get=AsyncMock(return_value=SimpleNamespace(decimales=2)),
        add_all=Mock(), commit=AsyncMock(),
    )
    with patch(
        "app.services.contabilidad_service.CajaService.validar_caja_venta",
        new_callable=AsyncMock, return_value=sesion(),
    ), patch(
        "app.services.contabilidad_service.CajaService.efectivo_en_caja",
        new_callable=AsyncMock, return_value=Decimal("130"),
    ):
        with pytest.raises(ContabilidadValidationError, match="disponible Bs 130.00"):
            asyncio.run(ContabilidadService(db).registrar_pagos_gasto(
                1, [PagoGastoCreate(metodo_pago="efectivo", monto="2000")], 1
            ))
    db.add_all.assert_not_called()
    db.commit.assert_not_awaited()
