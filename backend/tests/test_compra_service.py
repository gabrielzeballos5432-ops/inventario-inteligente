import asyncio
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock, create_autospec

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.compra import CompraCreate
from app.models.compra import Compra
from app.models.movimiento import Movimiento
from app.services.compra_service import CompraService, CompraValidationError, _unidad_minima


def compra(**cambios):
    datos = dict(
        proveedor_id=1, moneda_codigo="BOB", tipo_cambio_ext="1", tipo_cambio_bob="1",
        detalles=[dict(producto_id=1, cantidad=2, costo_unitario_moneda="10")],
    )
    return CompraCreate(**(datos | cambios))


def test_compra_admite_registro_sin_proveedor():
    assert compra(proveedor_id=None).proveedor_id is None


def test_compra_sin_proveedor_continua_validando_productos():
    db = create_autospec(AsyncSession, instance=True)
    db.get.return_value = SimpleNamespace(activa=True, decimales=2)
    db.execute.return_value = SimpleNamespace(scalars=lambda: [])

    with pytest.raises(CompraValidationError, match="producto 1 no existe"):
        asyncio.run(CompraService(db).registrar(compra(proveedor_id=None), 1))

    assert db.get.await_count == 1
    db.execute.assert_awaited_once()
    db.add.assert_not_called()


@pytest.mark.parametrize("proveedor_id", [None, 1])
def test_compra_actualiza_stock_y_costo_con_o_sin_proveedor(proveedor_id):
    db = create_autospec(AsyncSession, instance=True)
    moneda = SimpleNamespace(codigo="BOB", activa=True, decimales=2)
    db.get.side_effect = (
        [moneda] if proveedor_id is None else [moneda, SimpleNamespace(id=1, activo=True)]
    )
    producto = SimpleNamespace(id=1, activo=True, nombre="Producto", precio_compra=Decimal("10"))
    inventario = SimpleNamespace(producto_id=1, cantidad=5)
    db.execute.side_effect = [
        SimpleNamespace(scalars=lambda: [producto]),
        SimpleNamespace(scalars=lambda: [inventario]),
    ]
    servicio = CompraService(db)
    servicio.obtener = AsyncMock(return_value=None)
    datos = compra(
        proveedor_id=proveedor_id,
        detalles=[dict(producto_id=1, cantidad=2, costo_unitario_moneda="20")],
    )
    asyncio.run(servicio.registrar(datos, 7))
    guardada = next(
        llamada.args[0] for llamada in db.add.call_args_list
        if isinstance(llamada.args[0], Compra)
    )
    assert guardada.proveedor_id == proveedor_id
    assert guardada.usuario_id == 7
    assert guardada.total_bob == Decimal("40")
    assert inventario.cantidad == 7
    assert producto.precio_compra == Decimal("12.86")
    assert any(isinstance(llamada.args[0], Movimiento) for llamada in db.add.call_args_list)
    db.commit.assert_awaited_once()


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
