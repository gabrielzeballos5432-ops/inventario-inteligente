import asyncio
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock

import pytest

from app.services.inventario_service import InventarioService


def servicio(detecciones):
    db = SimpleNamespace(commit=AsyncMock())
    producto_repo = SimpleNamespace(
        obtener_por_id=AsyncMock(side_effect=lambda pid: SimpleNamespace(id=pid, nombre=f"P{pid}"))
    )
    movimiento_repo = SimpleNamespace(db=db, crear_movimiento=AsyncMock())
    sesion_repo = SimpleNamespace(
        crear=AsyncMock(return_value=SimpleNamespace(id=7)),
        incrementar_detectados=AsyncMock(),
    )
    deteccion_repo = SimpleNamespace(crear=AsyncMock())
    yolo = SimpleNamespace(detectar=Mock(return_value=detecciones))
    svc = InventarioService(producto_repo, movimiento_repo, yolo, sesion_repo, deteccion_repo)
    return svc, movimiento_repo, sesion_repo, deteccion_repo, db


DOS = [
    {"producto_id": 21, "cantidad": 1, "confianza": 0.8},
    {"producto_id": 22, "cantidad": 2, "confianza": 0.7},
]


def test_solo_detectar_no_mueve_stock_pero_guarda_la_auditoria():
    svc, mov, sesion, det, db = servicio(DOS)
    r = asyncio.run(svc.procesar_inferencia(b"img", 1, 1, registrar=False))
    mov.crear_movimiento.assert_not_awaited()
    assert r.movimientos_creados == 0
    assert r.sesion_id == 7
    assert [d.cantidad for d in r.detecciones] == [1, 2]
    assert det.crear.await_count == 2
    sesion.incrementar_detectados.assert_awaited_once_with(7, 3)
    db.commit.assert_awaited()


def test_registrar_directo_sigue_creando_entradas_ia():
    svc, mov, *_ = servicio(DOS)
    r = asyncio.run(svc.procesar_inferencia(b"img", 1, 1))
    assert mov.crear_movimiento.await_count == 2
    assert r.movimientos_creados == 2
    assert all(c.kwargs["tipo"] == "entrada" and c.kwargs["origen"] == "ia"
               for c in mov.crear_movimiento.await_args_list)


def test_un_conteo_nunca_mueve_el_stock():
    # Antes un conteo se registraba como salida de stock.
    svc, mov, *_ = servicio(DOS)
    r = asyncio.run(svc.procesar_inferencia(b"img", 1, 1, tipo_operacion="conteo"))
    mov.crear_movimiento.assert_not_awaited()
    assert r.movimientos_creados == 0


@pytest.mark.parametrize("existe", [True, False])
def test_modelo_disponible_si_el_archivo_existe_aunque_no_este_cargado(tmp_path, monkeypatch, existe):
    from app.core.config import settings
    from app.yolo.inference_service import InferenceService
    ruta = tmp_path / "best.pt"
    if existe:
        ruta.write_bytes(b"x")
    monkeypatch.setattr(settings, "YOLO_MODEL_PATH", str(ruta))
    monkeypatch.setattr(InferenceService, "_modelo", None)
    assert InferenceService().modelo_disponible is existe


def _jpeg():
    import io
    from PIL import Image
    buf = io.BytesIO()
    Image.new("RGB", (8, 8), "red").save(buf, format="JPEG")
    return buf.getvalue()


def test_la_foto_del_celular_sin_tipo_de_imagen_se_acepta_por_su_contenido():
    # La app la sube como application/octet-stream; antes se rechazaba con 400.
    from app.routers.inferencia import es_imagen
    assert es_imagen("application/octet-stream", _jpeg()) is True
    assert es_imagen(None, _jpeg()) is True
    assert es_imagen("image/jpeg", b"") is True


def test_un_archivo_que_no_es_imagen_se_rechaza():
    from app.routers.inferencia import es_imagen
    assert es_imagen("application/octet-stream", b"%PDF-1.4 no es una foto") is False
    assert es_imagen("text/plain", b"hola") is False


def test_la_respuesta_trae_un_recuadro_por_unidad():
    # La app los dibuja sobre la foto para que se vea que conto la IA.
    caja = {"x1": 0.1, "y1": 0.2, "x2": 0.4, "y2": 0.8, "confianza": 0.8}
    otra = {"x1": 0.5, "y1": 0.2, "x2": 0.9, "y2": 0.8, "confianza": 0.6}
    svc, *_ = servicio([
        {"producto_id": 21, "cantidad": 2, "confianza": 0.8, "cajas": [caja, otra]},
    ])
    r = asyncio.run(svc.procesar_inferencia(b"img", 1, 1, registrar=False))
    cajas = r.detecciones[0].cajas
    assert len(cajas) == r.detecciones[0].cantidad == 2
    assert (cajas[0].x1, cajas[0].y2, cajas[1].confianza) == (0.1, 0.8, 0.6)
    # Asi viajan en el JSON que recibe la app.
    assert r.model_dump()["detecciones"][0]["cajas"][0]["x2"] == 0.4
