import asyncio
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import create_autospec

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.compra import CompraCreate
from app.services.compra_service import CompraService, CompraValidationError, _unidad_minima


def compra(**cambios):
    datos = dict(
        proveedor_id=1, moneda_codigo="BOB", tipo_cambio_ext="1", tipo_cambio_bob="1",
        detalles=[dict(producto_id=1, cantidad=2, costo_unitario_moneda="10")],
    )
    return CompraCreate(**(datos | cambios))


@pytest.mark.parametrize("decimales,esperado", [(0, "1"), (2, "0.01"), (4, "0.0001")])
def test_unidad_minima_segun_moneda(decimales, esperado):
    assert _unidad_minima(decimales) == Decimal(esperado)


def test_compra_rechaza_producto_repetido_sin_consultas():
    db = create_autospec(AsyncSession, instance=True)
    datos = compra()
    datos.detalles.append(datos.detalles[0].model_copy())
    with pytest.raises(CompraValidationError, match="repetir"):
        asyncio.run(CompraService(db).registrar(datos, 1))
    db.get.assert_not_awaited()
    db.add.assert_not_called()


@pytest.mark.parametrize("moneda", [None, SimpleNamespace(activa=False)])
def test_compra_rechaza_moneda_inexistente_o_inactiva(moneda):
    db = create_autospec(AsyncSession, instance=True)
    db.get.return_value = moneda
    with pytest.raises(CompraValidationError, match="moneda no existe"):
        asyncio.run(CompraService(db).registrar(compra(), 1))
    db.add.assert_not_called()
    db.commit.assert_not_awaited()


@pytest.mark.parametrize(
    "cambios,mensaje",
    [
        (dict(moneda_codigo="USD", tipo_cambio_ext="2"), "debe ser 1"),
        (dict(tipo_cambio_ext="2", tipo_cambio_bob="1"), "misma cotización"),
        (dict(descuento_moneda="0.001"), "máximo 2 decimales"),
    ],
)
def test_compra_rechaza_cotizacion_o_precision_invalida(cambios, mensaje):
    db = create_autospec(AsyncSession, instance=True)
    db.get.return_value = SimpleNamespace(activa=True, decimales=2)
    with pytest.raises(CompraValidationError, match=mensaje):
        asyncio.run(CompraService(db).registrar(compra(**cambios), 1))
    db.execute.assert_not_awaited()
    db.add.assert_not_called()


@pytest.mark.parametrize("proveedor", [None, SimpleNamespace(activo=False)])
def test_compra_rechaza_proveedor_inexistente_o_inactivo(proveedor):
    db = create_autospec(AsyncSession, instance=True)
    db.get.side_effect = [SimpleNamespace(activa=True, decimales=2), proveedor]
    with pytest.raises(CompraValidationError, match="proveedor no existe"):
        asyncio.run(CompraService(db).registrar(compra(), 1))
    db.add.assert_not_called()
    db.commit.assert_not_awaited()
