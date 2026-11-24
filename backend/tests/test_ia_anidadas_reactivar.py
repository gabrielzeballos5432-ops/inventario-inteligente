import asyncio
from types import SimpleNamespace
from unittest.mock import AsyncMock

from app.schemas.movimiento import MovimientoLoteItem
from app.services.inventario_service import InventarioService
from app.yolo.inference_service import descartar_anidadas


def caja(x1, y1, x2, y2, confianza):
    return {"x1": x1, "y1": y1, "x2": x2, "y2": y2, "confianza": confianza}


def test_la_mitad_del_frasco_dentro_del_frasco_entero_cuenta_una_vez():
    # El caso real del celular: el iluminador entero (65 %) y su mitad de
    # arriba (76 %) dentro; contaba 2.
    entero = caja(0.40, 0.08, 0.70, 0.73, 0.65)
    mitad = caja(0.40, 0.09, 0.69, 0.57, 0.76)
    quedan = descartar_anidadas([mitad, entero])
    assert len(quedan) == 1
    # Queda la caja grande, con la confianza mas alta de las dos.
    assert (quedan[0]["y2"], quedan[0]["confianza"]) == (0.73, 0.76)


def test_dos_unidades_una_al_lado_de_otra_se_cuentan_las_dos():
    a = caja(0.10, 0.2, 0.40, 0.9, 0.8)
    b = caja(0.38, 0.2, 0.68, 0.9, 0.7)  # se tocan apenas
    assert len(descartar_anidadas([a, b])) == 2


def test_una_unidad_detras_de_otra_no_se_pierde():
    delante = caja(0.30, 0.30, 0.60, 0.95, 0.8)
    # Asoma por arriba y a la derecha: buena parte queda fuera de la otra.
    detras = caja(0.45, 0.10, 0.75, 0.70, 0.6)
    assert len(descartar_anidadas([delante, detras])) == 2


def test_no_modifica_las_cajas_recibidas():
    entero = caja(0.0, 0.0, 1.0, 1.0, 0.5)
    mitad = caja(0.0, 0.0, 1.0, 0.5, 0.9)
    descartar_anidadas([entero, mitad])
    assert entero["confianza"] == 0.5


def servicio(activo):
    producto = SimpleNamespace(id=21, nombre="Iluminador líquido", activo=activo)
    producto_repo = SimpleNamespace(
        obtener_por_ids=AsyncMock(return_value=[producto]),
        obtener_stocks=AsyncMock(return_value={21: 0}),
    )
    # Razon manual valida, para que el lote a mano llegue a revisar las filas.
    compra = SimpleNamespace(
        id=5, nombre="Compra a proveedor", tipo_movimiento="entrada",
        sistema=False, requiere_sucursal_destino=False, activo=True,
    )
    movimiento_repo = SimpleNamespace(
        db=SimpleNamespace(get=AsyncMock(return_value=compra)),
        crear_lote=AsyncMock(side_effect=lambda **kw: [SimpleNamespace(id=99)]),
    )
    svc = InventarioService(producto_repo, movimiento_repo, yolo=None)
    return svc, producto, movimiento_repo


def lote(svc, **cambios):
    datos = dict(
        tipo="entrada",
        items=[MovimientoLoteItem(producto_id=21, cantidad=1)],
        usuario_id=1,
        sucursal_id=1,
        origen="ia",
        sesion_id=7,
    )
    return asyncio.run(svc.registrar_lote(**(datos | cambios)))


def test_la_entrada_confirmada_por_ia_reactiva_el_producto_dado_de_baja():
    svc, producto, repo = servicio(activo=False)
    resultados, movimientos = lote(svc)
    assert producto.activo is True
    assert resultados[0].correcto and resultados[0].reactivado
    assert len(movimientos) == 1
    repo.crear_lote.assert_awaited_once()


def test_un_producto_activo_no_se_marca_como_reactivado():
    svc, producto, _ = servicio(activo=True)
    resultados, _ = lote(svc)
    assert resultados[0].reactivado is False


def test_a_mano_un_producto_dado_de_baja_se_sigue_rechazando():
    svc, producto, repo = servicio(activo=False)
    resultados, movimientos = lote(svc, origen="manual", razon_movimiento_id=5)
    assert producto.activo is False
    assert "dado de baja" in resultados[0].detalle
    assert resultados[0].reactivado is False
    assert movimientos == []
    repo.crear_lote.assert_not_awaited()


def test_una_salida_por_ia_no_reactiva():
    svc, producto, _ = servicio(activo=False)
    resultados, movimientos = lote(svc, tipo="salida")
    assert producto.activo is False
    assert movimientos == []
