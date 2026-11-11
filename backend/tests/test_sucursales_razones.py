import asyncio
from types import SimpleNamespace
from unittest.mock import AsyncMock, create_autospec

import pytest
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.razon_movimiento import RazonMovimiento
from app.models.sucursal import Sucursal
from app.schemas.configuracion import (
    RazonMovimientoCreate,
    RazonMovimientoUpdate,
    SucursalUpdate,
)
from app.schemas.movimiento import MovimientoLoteItem
from app.schemas.producto import ProductoCreate
from app.services.configuracion_service import (
    ConfiguracionService,
    ConfiguracionValidationError,
)
from app.services.inventario_service import InventarioService, MovimientoValidationError


def razon(**cambios):
    datos = dict(
        id=5, nombre="Salida por falla", tipo_movimiento="salida",
        sistema=False, requiere_sucursal_destino=False, activo=True,
    )
    return SimpleNamespace(**(datos | cambios))


def servicio(db_get=None, stock=10):
    db = create_autospec(AsyncSession, instance=True)
    if db_get is not None:
        db.get.side_effect = db_get
    producto_repo = SimpleNamespace(
        obtener_por_ids=AsyncMock(
            return_value=[SimpleNamespace(id=1, nombre="Esmalte", activo=True)]
        ),
        obtener_stocks=AsyncMock(return_value={1: stock}),
    )
    movimiento_repo = SimpleNamespace(
        db=db,
        crear_lote=AsyncMock(side_effect=lambda **kw: [SimpleNamespace(id=99)]),
    )
    return InventarioService(producto_repo, movimiento_repo, yolo=None), movimiento_repo


def lote(svc, **cambios):
    datos = dict(
        tipo="salida",
        items=[MovimientoLoteItem(producto_id=1, cantidad=2)],
        usuario_id=1,
        sucursal_id=1,
    )
    return asyncio.run(svc.registrar_lote(**(datos | cambios)))


def test_movimiento_manual_sin_razon_se_rechaza():
    svc, repo = servicio()
    with pytest.raises(MovimientoValidationError, match="obligatoria"):
        lote(svc)
    repo.crear_lote.assert_not_awaited()


def test_razon_del_sistema_no_se_elige_a_mano():
    svc, repo = servicio(db_get=[razon(nombre="Venta", sistema=True)])
    with pytest.raises(MovimientoValidationError, match="asigna el sistema"):
        lote(svc, razon_movimiento_id=5)
    repo.crear_lote.assert_not_awaited()


def test_razon_de_otro_tipo_se_rechaza():
    svc, _ = servicio(db_get=[razon(nombre="Ajuste por desglose", tipo_movimiento="ajuste")])
    with pytest.raises(MovimientoValidationError, match="es de ajuste"):
        lote(svc, razon_movimiento_id=5)


def test_razon_desactivada_se_rechaza():
    svc, _ = servicio(db_get=[razon(activo=False)])
    with pytest.raises(MovimientoValidationError, match="desactivada"):
        lote(svc, razon_movimiento_id=5)


def test_razon_normal_registra_en_la_sucursal_activa():
    svc, repo = servicio(db_get=[razon()])
    resultados, movimientos = lote(svc, razon_movimiento_id=5, sucursal_id=3)
    assert all(r.correcto for r in resultados)
    assert len(movimientos) == 1
    llamada = repo.crear_lote.await_args.kwargs
    assert llamada["sucursal_id"] == 3
    assert llamada["razon_movimiento_id"] == 5
    assert llamada["confirmar"] is True
    assert llamada["sucursal_relacionada_id"] is None


def test_traspaso_exige_sucursal_destino_distinta():
    traspaso = razon(nombre="Salida a sucursal", requiere_sucursal_destino=True)
    svc, _ = servicio(db_get=[traspaso])
    with pytest.raises(MovimientoValidationError, match="sucursal destino"):
        lote(svc, razon_movimiento_id=5)

    svc, _ = servicio(db_get=[traspaso])
    with pytest.raises(MovimientoValidationError, match="distinta"):
        lote(svc, razon_movimiento_id=5, sucursal_destino_id=1)

    svc, _ = servicio(db_get=[traspaso, SimpleNamespace(id=2, activo=False)])
    with pytest.raises(MovimientoValidationError, match="desactivada"):
        lote(svc, razon_movimiento_id=5, sucursal_destino_id=2)


def test_destino_en_razon_que_no_es_traspaso_se_rechaza():
    svc, _ = servicio(db_get=[razon()])
    with pytest.raises(MovimientoValidationError, match="no envía"):
        lote(svc, razon_movimiento_id=5, sucursal_destino_id=2)


def test_traspaso_registra_salida_y_entrada_en_una_transaccion():
    traspaso = razon(nombre="Salida a sucursal", requiere_sucursal_destino=True)
    svc, repo = servicio(db_get=[traspaso, SimpleNamespace(id=2, activo=True)])
    lote(svc, razon_movimiento_id=5, sucursal_destino_id=2)

    salida, entrada = (c.kwargs for c in repo.crear_lote.await_args_list)
    # La salida no confirma sola: si la entrada fallara, se deshacen las dos.
    assert salida["tipo"] == "salida"
    assert salida["sucursal_id"] == 1
    assert salida["sucursal_relacionada_id"] == 2
    assert salida["confirmar"] is False
    assert entrada["tipo"] == "entrada"
    assert entrada["sucursal_id"] == 2
    assert entrada["sucursal_relacionada_id"] == 1
    assert entrada["productos_y_cantidades"] == [(1, 2)]
    assert entrada.get("confirmar", True) is True


def test_traspaso_sin_stock_no_registra_nada():
    traspaso = razon(nombre="Salida a sucursal", requiere_sucursal_destino=True)
    svc, repo = servicio(db_get=[traspaso, SimpleNamespace(id=2, activo=True)], stock=1)
    resultados, movimientos = lote(svc, razon_movimiento_id=5, sucursal_destino_id=2)
    assert movimientos == []
    assert "disponible 1" in resultados[0].detalle
    repo.crear_lote.assert_not_awaited()


def test_ia_sin_razon_usa_la_del_sistema():
    svc, repo = servicio()
    lote(svc, tipo="entrada", origen="ia")
    # No consulta ninguna razón: va la subconsulta de la razón del sistema.
    repo.db.get.assert_not_awaited()
    assert repo.crear_lote.await_args.kwargs["razon_movimiento_id"] is not None


def test_cantidad_inicial_por_defecto_cero_y_no_negativa():
    datos = dict(nombre="Esmalte", precio_compra="5", precio_venta="8")
    assert ProductoCreate(**datos).cantidad_inicial == 0
    assert ProductoCreate(**datos, cantidad_inicial=12).cantidad_inicial == 12
    with pytest.raises(ValidationError):
        ProductoCreate(**datos, cantidad_inicial=-1)


def config(db_get, predeterminada_id=1):
    db = create_autospec(AsyncSession, instance=True)
    db.get.side_effect = db_get
    db.execute.return_value = SimpleNamespace(scalar_one_or_none=lambda: predeterminada_id)
    return ConfiguracionService(db), db


def test_no_se_desactiva_la_sucursal_predeterminada():
    svc, db = config([Sucursal(id=1, nombre="Centro", activo=True)])
    with pytest.raises(ConfiguracionValidationError, match="predeterminada"):
        asyncio.run(svc.actualizar_sucursal(1, SucursalUpdate(activo=False)))
    db.commit.assert_not_awaited()


def test_predeterminada_tiene_que_estar_activa():
    svc, db = config([Sucursal(id=2, nombre="Norte", activo=False)])
    with pytest.raises(ConfiguracionValidationError, match="desactivada"):
        asyncio.run(svc.definir_sucursal_predeterminada(2))
    db.commit.assert_not_awaited()


def test_razon_del_sistema_no_se_edita():
    svc, db = config([RazonMovimiento(id=11, nombre="Venta", tipo_movimiento="salida", sistema=True)])
    with pytest.raises(ConfiguracionValidationError, match="sistema"):
        asyncio.run(svc.actualizar_razon(11, RazonMovimientoUpdate(activo=False)))
    db.commit.assert_not_awaited()


def test_solo_una_salida_puede_ir_a_otra_sucursal():
    svc, db = config([])
    with pytest.raises(ConfiguracionValidationError, match="salida"):
        asyncio.run(svc.crear_razon(RazonMovimientoCreate(
            nombre="Ingreso desde sucursal", tipo_movimiento="entrada",
            requiere_sucursal_destino=True,
        )))
    db.commit.assert_not_awaited()


def test_nombre_de_razon_vacio_se_rechaza():
    with pytest.raises(ValidationError):
        RazonMovimientoCreate(nombre="   ", tipo_movimiento="salida")
