import asyncio
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.schemas.movimiento import MovimientoLoteCreate, MovimientoLoteItem
from app.services.inventario_service import InventarioService, MovimientoValidationError

CLAVE = "lote-0001-abcdef"


def mov(id, producto_id, cantidad, tipo="entrada"):
    m = SimpleNamespace(id=id, producto_id=producto_id, cantidad=cantidad, tipo=tipo)
    m.producto = SimpleNamespace(nombre=f"P{producto_id}")
    return m


def servicio(previos=()):
    producto_repo = SimpleNamespace(
        obtener_por_ids=AsyncMock(return_value=[
            SimpleNamespace(id=1, nombre="P1", activo=True),
            SimpleNamespace(id=2, nombre="P2", activo=True),
        ]),
        obtener_stocks=AsyncMock(return_value={1: 5, 2: 5}),
    )
    razon = SimpleNamespace(
        id=5, nombre="Compra", tipo_movimiento="entrada",
        sistema=False, requiere_sucursal_destino=False, activo=True,
    )
    movimiento_repo = SimpleNamespace(
        db=SimpleNamespace(get=AsyncMock(return_value=razon)),
        obtener_por_clave=AsyncMock(return_value=list(previos)),
        crear_lote=AsyncMock(
            side_effect=lambda **kw: [
                SimpleNamespace(id=90 + i) for i, _ in enumerate(kw["productos_y_cantidades"])
            ]
        ),
    )
    return InventarioService(producto_repo, movimiento_repo, yolo=None), movimiento_repo


ITEMS = [MovimientoLoteItem(producto_id=1, cantidad=3), MovimientoLoteItem(producto_id=2, cantidad=1)]


def test_el_primer_envio_guarda_la_clave_en_los_movimientos():
    svc, repo = servicio()
    assert asyncio.run(svc.lote_ya_registrado(CLAVE, 1, "entrada", ITEMS)) is None
    asyncio.run(svc.registrar_lote(
        tipo="entrada", items=ITEMS, usuario_id=1, sucursal_id=1,
        razon_movimiento_id=5, clave_idempotencia=CLAVE,
    ))
    assert repo.crear_lote.await_args.kwargs["clave_idempotencia"] == CLAVE


def test_el_reenvio_del_mismo_lote_devuelve_el_guardado_sin_mover_stock():
    # La respuesta se perdio y la cola offline reenvia: no debe duplicarse.
    svc, repo = servicio(previos=[mov(10, 1, 3), mov(11, 2, 1)])
    resultados = asyncio.run(svc.lote_ya_registrado(CLAVE, 1, "entrada", ITEMS))
    assert [(r.fila, r.producto_id, r.movimiento_id, r.correcto) for r in resultados] == [
        (1, 1, 10, True), (2, 2, 11, True),
    ]
    assert resultados[0].producto_nombre == "P1"
    repo.crear_lote.assert_not_awaited()
    repo.obtener_por_clave.assert_awaited_once_with(CLAVE, 1)


@pytest.mark.parametrize("tipo, items", [
    ("salida", ITEMS),
    ("entrada", [MovimientoLoteItem(producto_id=1, cantidad=9), MovimientoLoteItem(producto_id=2, cantidad=1)]),
    ("entrada", [MovimientoLoteItem(producto_id=1, cantidad=3)]),
])
def test_la_misma_clave_con_otro_contenido_se_rechaza(tipo, items):
    svc, _ = servicio(previos=[mov(10, 1, 3), mov(11, 2, 1)])
    with pytest.raises(MovimientoValidationError, match="ya se usó"):
        asyncio.run(svc.lote_ya_registrado(CLAVE, 1, tipo, items))


def test_la_entrada_del_destino_de_un_traspaso_no_lleva_la_clave():
    # Si la llevara, chocaria con el indice unico (mismo usuario, clave y producto).
    svc, repo = servicio()
    repo.db.get = AsyncMock(side_effect=[
        SimpleNamespace(id=6, nombre="Salida a sucursal", tipo_movimiento="salida",
                        sistema=False, requiere_sucursal_destino=True, activo=True),
        SimpleNamespace(id=2, nombre="Sucursal 2", activo=True),
    ])
    asyncio.run(svc.registrar_lote(
        tipo="salida", items=ITEMS, usuario_id=1, sucursal_id=1,
        razon_movimiento_id=6, sucursal_destino_id=2, clave_idempotencia=CLAVE,
    ))
    origen, destino = repo.crear_lote.await_args_list
    assert origen.kwargs["clave_idempotencia"] == CLAVE
    assert destino.kwargs.get("clave_idempotencia") is None


def test_la_clave_muy_corta_se_rechaza_en_el_schema():
    with pytest.raises(ValueError):
        MovimientoLoteCreate(tipo="entrada", items=ITEMS, clave_idempotencia="abc")
