import io
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import create_autospec

from fastapi import FastAPI
from fastapi.testclient import TestClient
from PIL import Image
import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db
from app.core.security import require_admin
from app.routers import compras
from app.schemas.lectura_compra import LecturaCompraOut, LineaCompraLeida
from app.services import lectura_compra_service as servicio


@pytest.mark.parametrize("texto,esperado", [
    ("12,00", "12"), ("1.000", "1000"), ("288.580", "288580"),
    ("971,57", "971.57"), ("1.234,56", "1234.56"), ("12.50", "12.50"),
])
def test_importes_en_notacion_del_comprobante(texto, esperado):
    assert servicio.importe_impreso(texto) == Decimal(esperado)


def test_interpreta_cantidades_costos_y_total_sin_inventar_moneda():
    lectura = servicio.interpretar_comprobante([
        "DOCUMENTO #: FCV-V200074242", "VASABA SPA",
        "(Codigo)/Descripcion", "BOD UN Cant. Precio Dcto. Total",
        "KK-72 DECORACION DE UNAS POLVO", "000 UN 12,00x1.000 =12.000",
        "JP-JT09 UNAS POSTIZAS VARIOS COLORES", "12PCS",
        "000 UN 12,00x600 =7.200", "TOTAL : 19.200",
    ])
    assert lectura.numero_factura == "FCV-V200074242"
    assert lectura.proveedor_nombre == "VASABA SPA"
    assert lectura.moneda_codigo is None
    assert lectura.total_impreso == lectura.subtotal_calculado == Decimal("19200")
    assert lectura.detalles[0].cantidad == 12
    assert lectura.detalles[0].codigo == "KK-72"
    assert lectura.detalles[0].costo_unitario_moneda == Decimal("1000")
    assert lectura.detalles[0].producto_id is None
    assert "12PCS" in lectura.detalles[1].descripcion


def test_advierte_lineas_incompletas_y_subtotales_inconsistentes():
    lectura = servicio.interpretar_comprobante([
        "CLP", "A-1 Producto", "12,00x600 =7.000", "TOTAL: 20.000",
    ])
    assert lectura.moneda_codigo == "CLP"
    assert any("subtotal" in aviso for aviso in lectura.advertencias)
    assert any("total impreso" in aviso for aviso in lectura.advertencias)


def test_conserva_descripcion_con_palabras_que_contienen_cant():
    lectura = servicio.interpretar_comprobante([
        "A-1 Producto refrescante", "12,00x600 =7.200", "TOTAL: 7.200",
    ])
    assert lectura.detalles[0].descripcion == "A-1 Producto refrescante"


@pytest.mark.parametrize("renglones", [
    ["TOTAL: 20.000"], ["Producto", "0,50x600 =300"],
])
def test_rechaza_comprobante_sin_lineas_utilizables(renglones):
    with pytest.raises(servicio.LecturaCompraError, match="No se identificaron"):
        servicio.interpretar_comprobante(renglones)


def test_reconstruye_fila_con_columnas_ocr_separadas():
    assert servicio.agrupar_renglones([
        {"texto": "12,00", "caja": [30, 30, 60, 40]},
        {"texto": "Producto", "caja": [0, 0, 60, 10]},
        {"texto": "x600 =7.200", "caja": [65, 31, 120, 41]},
    ]) == ["Producto", "12,00 x600 =7.200"]


def test_servicio_informa_instalacion_ausente(monkeypatch, tmp_path):
    monkeypatch.setenv("OCR_PYTHON", str(tmp_path / "inexistente.exe"))
    with pytest.raises(servicio.LecturaCompraError) as error:
        servicio.leer_comprobante(b"foto")
    assert error.value.estado == 503


def test_servicio_rechaza_archivo_que_no_es_imagen(monkeypatch):
    import sys
    monkeypatch.setenv("OCR_PYTHON", sys.executable)
    with pytest.raises(servicio.LecturaCompraError, match="imagen válida"):
        servicio.leer_comprobante(b"no soy una imagen")


def test_servicio_usa_proceso_local_y_elimina_archivo_temporal(monkeypatch):
    import sys
    from pathlib import Path
    monkeypatch.setenv("OCR_PYTHON", sys.executable)
    rutas = []

    def ejecutar(argumentos, **opciones):
        rutas.append(Path(argumentos[-1]))
        assert rutas[0].is_file()
        assert opciones["timeout"] == 240
        return SimpleNamespace(
            returncode=0, stderr="",
            stdout='[{"texto":"12x600 =7.200","confianza":0.8,"caja":[0,0,100,10]}]',
        )

    monkeypatch.setattr(servicio.subprocess, "run", ejecutar)
    contenido = io.BytesIO()
    Image.new("RGB", (20, 20)).save(contenido, format="PNG")
    lectura = servicio.leer_comprobante(contenido.getvalue())
    assert lectura.subtotal_calculado == Decimal("7200")
    assert any("baja confianza" in aviso for aviso in lectura.advertencias)
    assert not rutas[0].exists()


def test_endpoint_sugiere_solo_coincidencias_exactas_y_no_escribe_bd(monkeypatch):
    db = create_autospec(AsyncSession, instance=True)
    producto = SimpleNamespace(id=5, sku="KK-72", codigo_barras=None, nombre="Decoración")
    proveedor = SimpleNamespace(id=2, nombre="Vasaba SPA")
    db.execute.side_effect = [
        SimpleNamespace(scalars=lambda: [producto]),
        SimpleNamespace(scalars=lambda: [proveedor]),
    ]
    lectura = LecturaCompraOut(
        proveedor_nombre="VASABA SPA", subtotal_calculado=Decimal("7200"),
        detalles=[LineaCompraLeida(
            descripcion="KK-72 Decoracion", codigo="KK-72",
            cantidad=12, costo_unitario_moneda=Decimal("600"),
        )], advertencias=[], texto_detectado="texto",
    )
    monkeypatch.setattr(compras, "leer_comprobante", lambda _: lectura)
    app = FastAPI()
    app.include_router(compras.compras_router)
    app.dependency_overrides[require_admin] = lambda: (1, "administrador")
    app.dependency_overrides[get_db] = lambda: db
    with TestClient(app) as cliente:
        respuesta = cliente.post(
            "/api/compras/leer-comprobante",
            files={"imagen": ("foto.jpg", b"foto", "image/jpeg")},
        )
    assert respuesta.status_code == 200
    assert respuesta.json()["detalles"][0]["producto_id"] == 5
    assert respuesta.json()["proveedor_id"] == 2
    db.add.assert_not_called()
    db.commit.assert_not_awaited()


@pytest.mark.parametrize("estado,mensaje", [
    (503, "PaddleOCR no está instalado."),
    (422, "No se identificaron líneas."),
    (429, "Ya se está leyendo un comprobante."),
])
def test_endpoint_informa_errores_del_lector(monkeypatch, estado, mensaje):
    def rechazar(_):
        raise servicio.LecturaCompraError(mensaje, estado)

    monkeypatch.setattr(compras, "leer_comprobante", rechazar)
    db = create_autospec(AsyncSession, instance=True)
    app = FastAPI()
    app.include_router(compras.compras_router)
    app.dependency_overrides[require_admin] = lambda: (1, "administrador")
    app.dependency_overrides[get_db] = lambda: db
    with TestClient(app) as cliente:
        respuesta = cliente.post(
            "/api/compras/leer-comprobante",
            files={"imagen": ("foto.jpg", b"foto", "image/jpeg")},
        )
    assert respuesta.status_code == estado
    assert respuesta.json()["detail"] == mensaje
    db.execute.assert_not_awaited()
    db.commit.assert_not_awaited()


def test_rechaza_lecturas_simultaneas_sin_liberar_otro_trabajo():
    assert servicio._OCUPADO.acquire(blocking=False)
    try:
        with pytest.raises(servicio.LecturaCompraError) as error:
            servicio.leer_comprobante(b"foto")
        assert error.value.estado == 429
        assert servicio._OCUPADO.locked()
    finally:
        servicio._OCUPADO.release()


def test_endpoint_rechaza_archivo_grande_antes_de_ejecutar_ocr(monkeypatch):
    from unittest.mock import Mock

    motor = Mock()
    monkeypatch.setattr(compras, "leer_comprobante", motor)
    db = create_autospec(AsyncSession, instance=True)
    app = FastAPI()
    app.include_router(compras.compras_router)
    app.dependency_overrides[require_admin] = lambda: (1, "administrador")
    app.dependency_overrides[get_db] = lambda: db
    with TestClient(app) as cliente:
        respuesta = cliente.post(
            "/api/compras/leer-comprobante",
            files={"imagen": ("grande.jpg", b"x" * (12 * 1024 * 1024 + 1), "image/jpeg")},
        )
    assert respuesta.status_code == 413
    motor.assert_not_called()
    db.execute.assert_not_awaited()
