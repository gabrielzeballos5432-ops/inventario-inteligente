from datetime import date, time

import pytest
from pydantic import ValidationError

from app.schemas.movimiento import MovimientoCreate, MovimientoLoteCreate
from app.schemas.producto import ProductoCreate
from app.schemas.sueldo import LiquidacionSueldoCreate, RegistroHoraManualCreate
from app.schemas.venta import PagoVentaCreate, VentaCreate


@pytest.mark.parametrize("campo", ["precio_compra", "precio_venta", "precio_mayor"])
@pytest.mark.parametrize("valor", ["0", "-1"])
def test_producto_rechaza_precio_no_positivo(campo, valor):
    datos = dict(nombre="Tinte", precio_compra="8", precio_venta="18")
    datos[campo] = valor
    with pytest.raises(ValidationError) as error:
        ProductoCreate(**datos)
    assert error.value.errors()[0]["loc"] == (campo,)


@pytest.mark.parametrize("campo", ["precio_compra", "precio_venta"])
def test_producto_exige_precios(campo):
    datos = dict(nombre="Tinte", precio_compra="8", precio_venta="18")
    del datos[campo]
    with pytest.raises(ValidationError) as error:
        ProductoCreate(**datos)
    assert error.value.errors()[0]["type"] == "missing"


def test_producto_admite_stock_minimo_cero():
    producto = ProductoCreate(
        nombre="Tinte", precio_compra="8", precio_venta="18", stock_minimo=0
    )
    assert producto.stock_minimo == 0
    assert producto.precio_mayor is None


@pytest.mark.parametrize("tipo", ["entrada", "salida"])
def test_movimiento_rechaza_cero_en_entrada_y_salida(tipo):
    with pytest.raises(ValidationError, match="mayor a 0"):
        MovimientoCreate(producto_id=1, tipo=tipo, cantidad=0)


def test_movimiento_ajuste_admite_cero():
    assert MovimientoCreate(producto_id=1, tipo="ajuste", cantidad=0).cantidad == 0


def test_lote_rechaza_lista_vacia():
    with pytest.raises(ValidationError) as error:
        MovimientoLoteCreate(tipo="entrada", items=[])
    assert error.value.errors()[0]["type"] == "too_short"


@pytest.mark.parametrize("metodo", ["efectivo", "qr"])
def test_pago_admite_metodos_soportados(metodo):
    assert PagoVentaCreate(metodo_pago=metodo, monto="1").metodo_pago == metodo


@pytest.mark.parametrize("monto", ["0", "-1"])
def test_pago_rechaza_monto_no_positivo(monto):
    with pytest.raises(ValidationError):
        PagoVentaCreate(metodo_pago="qr", monto=monto)


def test_pago_rechaza_metodo_desconocido():
    with pytest.raises(ValidationError):
        PagoVentaCreate(metodo_pago="tarjeta", monto="1")


def test_venta_exige_detalles():
    with pytest.raises(ValidationError):
        VentaCreate(detalles=[])


@pytest.mark.parametrize("salida", [time(8), time(7)])
def test_asistencia_rechaza_salida_no_posterior(salida):
    with pytest.raises(ValidationError, match="posterior"):
        RegistroHoraManualCreate(
            usuario_id=1, fecha=date(2026, 10, 29),
            hora_entrada=time(8), hora_salida=salida,
        )


def test_asistencia_admite_jornada_abierta():
    registro = RegistroHoraManualCreate(
        usuario_id=1, fecha=date(2026, 10, 29), hora_entrada=time(8)
    )
    assert registro.hora_salida is None


def test_liquidacion_rechaza_periodo_invertido():
    with pytest.raises(ValidationError, match="anterior"):
        LiquidacionSueldoCreate(
            usuario_id=1, fecha_inicio=date(2026, 10, 29), fecha_fin=date(2026, 10, 1)
        )


def test_liquidacion_admite_un_dia():
    datos = LiquidacionSueldoCreate(
        usuario_id=1, fecha_inicio=date(2026, 10, 29), fecha_fin=date(2026, 10, 29)
    )
    assert datos.fecha_inicio == datos.fecha_fin
