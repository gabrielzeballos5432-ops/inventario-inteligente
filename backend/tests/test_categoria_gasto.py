import asyncio
import importlib.util
from decimal import Decimal
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock

import pytest
from pydantic import ValidationError

from app.models.contabilidad import CategoriaGasto
from app.schemas.contabilidad import CategoriaGastoCreate, CategoriaGastoUpdate, GastoCreate
from app.services.contabilidad_service import ContabilidadService, ContabilidadValidationError


@pytest.mark.parametrize("periodo", ["mensual", "semanal", "anual", "sin_periodicidad"])
@pytest.mark.parametrize("tipo", ["fijo", "variable"])
def test_periodo_e_importe_independientes(periodo, tipo):
    datos = CategoriaGastoCreate(nombre=" Luz ", periodicidad=periodo, tipo_importe=tipo)
    assert datos.nombre == "Luz"
    assert datos.monto_habitual is None


@pytest.mark.parametrize("monto", ["0", "-1", "1.123"])
def test_monto_habitual_invalido(monto):
    with pytest.raises(ValidationError):
        CategoriaGastoCreate(nombre="Wifi", periodicidad="mensual", tipo_importe="fijo", monto_habitual=monto)


def test_variable_no_admite_monto_habitual():
    with pytest.raises(ValidationError, match="variable"):
        CategoriaGastoCreate(nombre="Luz", periodicidad="mensual", tipo_importe="variable", monto_habitual="10")


def test_nombre_vacio_y_periodo_desconocido():
    for nombre, periodo in [("  ", "mensual"), ("Wifi", "diario")]:
        with pytest.raises(ValidationError):
            CategoriaGastoCreate(nombre=nombre, periodicidad=periodo, tipo_importe="fijo")


def _db():
    return SimpleNamespace(
        get=AsyncMock(), execute=AsyncMock(return_value=Mock()), commit=AsyncMock(),
        refresh=AsyncMock(), add=Mock(),
    )


def test_editar_mismo_nombre_y_reactivar():
    db = _db()
    categoria = CategoriaGasto(id=1, nombre="wifi", activo=False)
    db.get.return_value = categoria
    db.execute.return_value.scalars.return_value.all.return_value = []
    datos = CategoriaGastoUpdate(
        nombre="Wifi", periodicidad="mensual", tipo_importe="fijo",
        monto_habitual="100", activo=True,
    )
    salida = asyncio.run(ContabilidadService(db).guardar_categoria_gasto(datos, 1))
    assert salida is categoria and categoria.activo
    assert categoria.monto_habitual == Decimal("100")
    assert "categoria_gasto.id !=" in str(db.execute.call_args.args[0])
    db.commit.assert_awaited_once()


def test_nombre_duplicado_no_guarda():
    db = _db()
    db.execute.return_value.scalars.return_value.all.return_value = [
        CategoriaGasto(id=2, nombre="Wifi", activo=True),
    ]
    datos = CategoriaGastoCreate(nombre="Wifi", periodicidad="mensual", tipo_importe="fijo")
    with pytest.raises(ContabilidadValidationError, match="Ya existe"):
        asyncio.run(ContabilidadService(db).guardar_categoria_gasto(datos))
    db.commit.assert_not_awaited()


def test_alta_reactiva_mismo_id_con_nombre_normalizado_y_configuracion_nueva():
    db = _db()
    categoria = CategoriaGasto(id=2, nombre="Wifi   hogar", activo=False)
    db.execute.return_value.scalars.return_value.all.return_value = [categoria]
    datos = CategoriaGastoCreate(
        nombre="  WIFI   hogar  ", periodicidad="mensual",
        tipo_importe="fijo", monto_habitual="150",
    )
    salida = asyncio.run(ContabilidadService(db).guardar_categoria_gasto(datos))
    assert salida is categoria
    assert categoria.id == 2 and categoria.activo
    assert categoria.nombre == "WIFI hogar"
    assert categoria.monto_habitual == Decimal("150")
    db.add.assert_not_called()
    db.commit.assert_awaited_once()


def test_baja_logica_conserva_categoria():
    db = _db()
    categoria = CategoriaGasto(id=1, nombre="Wifi", activo=True)
    db.get.return_value = categoria
    asyncio.run(ContabilidadService(db).eliminar_categoria_gasto(1))
    assert not categoria.activo
    db.commit.assert_awaited_once()


@pytest.mark.parametrize("categoria", [None, CategoriaGasto(id=1, activo=False)])
def test_no_registra_gastos_con_categoria_inactiva_o_inexistente(categoria):
    db = _db()
    db.execute.return_value.scalar_one_or_none.return_value = categoria
    datos = GastoCreate(
        categoria_gasto_id=1, concepto="Wifi", moneda_codigo="BOB",
        monto="100", tipo_cambio_ext="1", tipo_cambio_bob="1",
    )
    with pytest.raises(ContabilidadValidationError, match="inactiva"):
        asyncio.run(ContabilidadService(db).registrar_gasto(datos, 1, 1))
    db.commit.assert_not_awaited()


def test_gasto_guarda_nombre_historico_y_monto_editado():
    db = _db()
    db.execute.return_value.scalar_one_or_none.return_value = CategoriaGasto(
        id=1, nombre="Wifi", activo=True, monto_habitual=Decimal("100")
    )
    db.get.return_value = SimpleNamespace(activa=True, decimales=2)
    servicio = ContabilidadService(db)
    servicio.obtener_gasto = AsyncMock(return_value={})
    datos = GastoCreate(
        categoria_gasto_id=1, concepto="Wifi", moneda_codigo="BOB",
        monto="125", tipo_cambio_ext="1", tipo_cambio_bob="1",
    )
    asyncio.run(servicio.registrar_gasto(datos, 1, 1))
    gasto = db.add.call_args.args[0]
    assert gasto.sucursal_id == 1
    assert gasto.categoria == "Wifi"
    assert gasto.categoria_gasto_id == 1
    assert gasto.monto_bob == Decimal("125.00")


def test_gasto_legacy_sigue_admitido_y_categoria_obligatoria():
    base = dict(concepto="Luz", moneda_codigo="BOB", monto="10", tipo_cambio_ext="1", tipo_cambio_bob="1")
    assert GastoCreate(categoria="servicio", **base).categoria_gasto_id is None
    with pytest.raises(ValidationError, match="Selecciona"):
        GastoCreate(**base)


def test_migracion_envia_sentencias_separadas_para_asyncpg():
    ruta = Path(__file__).resolve().parents[1] / "alembic" / "versions" / "20261101_01_categoria_gasto.py"
    spec = importlib.util.spec_from_file_location("migracion_categoria_gasto", ruta)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    operaciones = Mock()
    operaciones.get_context.return_value = SimpleNamespace(as_sql=True)
    modulo.op = operaciones
    modulo.upgrade()
    assert operaciones.execute.call_count == 3
    for llamada in operaciones.execute.call_args_list:
        assert ";" not in llamada.args[0].strip().rstrip(";")
