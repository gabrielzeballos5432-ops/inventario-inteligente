"""Topes de los campos (iguales a las columnas) y mensajes de validacion en
castellano."""

import asyncio
import json
from decimal import Decimal
from types import SimpleNamespace

import pytest
from fastapi.exceptions import RequestValidationError
from pydantic import ValidationError

from app.main import manejar_error_validacion
from app.schemas.caja import ClienteCreate, ClienteOut
from app.schemas.producto import ProductoCreate, ProductoUpdate
from app.schemas.proveedor import ProveedorCreate
from app.schemas.venta import VentaDetalleCreate

BASE = dict(nombre="Tinte 7.1", precio_compra="8", precio_venta="18")


def test_producto_tope_de_precio_numeric_10_2():
    assert ProductoCreate(**{**BASE, "precio_venta": "99999999.99"}).precio_venta == Decimal("99999999.99")
    with pytest.raises(ValidationError):
        ProductoCreate(**{**BASE, "precio_venta": "100000000"})
    with pytest.raises(ValidationError):
        ProductoCreate(**{**BASE, "precio_venta": "18.555"})


@pytest.mark.parametrize("campo", ["sku", "codigo_barras"])
def test_producto_codigo_vacio_es_nulo_y_sin_espacios(campo):
    assert getattr(ProductoCreate(**{**BASE, campo: "   "}), campo) is None
    with pytest.raises(ValidationError):
        ProductoCreate(**{**BASE, campo: "AB 12"})
    with pytest.raises(ValidationError):
        ProductoCreate(**{**BASE, campo: "X" * 51})


def test_producto_nombre_en_blanco_o_solo_numeros():
    with pytest.raises(ValidationError):
        ProductoUpdate(nombre="   ")
    with pytest.raises(ValidationError):
        ProductoCreate(**{**BASE, "nombre": "500"})
    assert ProductoCreate(**{**BASE, "nombre": "  Shampoo 400 ml "}).nombre == "Shampoo 400 ml"


def test_stock_minimo_y_cantidad_no_superan_integer():
    with pytest.raises(ValidationError):
        ProductoCreate(**{**BASE, "stock_minimo": 2_147_483_648})
    with pytest.raises(ValidationError):
        VentaDetalleCreate(producto_id=1, cantidad=2_147_483_648, precio_unitario_negociado="5")


def test_proveedor_email_respeta_la_columna():
    with pytest.raises(ValidationError):
        ProveedorCreate(nombre="Andina", email=("a" * 95) + "@x.com")


def test_cliente_valida_correo_pero_el_listado_no():
    with pytest.raises(ValidationError):
        ClienteCreate(nombre="Ana", email="ana@")
    assert ClienteCreate(nombre="Ana", email="  ", telefono="").email is None
    # Un cliente viejo con correo mal escrito se sigue pudiendo leer.
    viejo = SimpleNamespace(nombre="Ana", telefono=None, email="ana@", id=1, activo=True,
                            creado_en="2026-01-01T00:00:00")
    assert ClienteOut.model_validate(viejo).email == "ana@"


def test_error_422_se_traduce_al_castellano():
    try:
        ProductoCreate(**{**BASE, "precio_venta": "100000000", "sku": "X" * 51})
    except ValidationError as error:
        exc = RequestValidationError(error.errors())
    respuesta = asyncio.run(manejar_error_validacion(None, exc))
    mensajes = {e["loc"][-1]: e["msg"] for e in json.loads(respuesta.body)["detail"]}
    # max_digits salta antes que le: cualquiera de los dos, pero en castellano.
    assert mensajes["precio_venta"] in {
        "El numero es demasiado grande",
        "Debe ser como maximo 99999999.99",
    }
    assert mensajes["sku"] == "Admite hasta 50 caracteres"
