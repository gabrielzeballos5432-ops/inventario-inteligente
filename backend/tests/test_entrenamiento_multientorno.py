import json
from types import SimpleNamespace
from unittest.mock import Mock

import pytest

from entrenamiento.armar_videos_nuevos import convertir_caja
from entrenamiento import comprobar_predicciones


def test_caja_completa_descuenta_margen():
    assert convertir_caja([0, 4, 0, 296, 125], (1280, 549)) == [0, 0.5, 0.5, 1, 1]


@pytest.mark.parametrize("caja", [
    [2, 4, 0, 296, 125],
    [0, 200, 20, 100, 50],
    [0, 310, 20, 320, 50],
])
def test_rechaza_caja_invalida(caja):
    with pytest.raises(ValueError):
        convertir_caja(caja, (1280, 549))


def test_rechaza_tamano_cero():
    with pytest.raises(ValueError, match="Tamano"):
        convertir_caja([0, 4, 0, 296, 125], (0, 549))


@pytest.mark.parametrize(
    "etiquetas,detecciones,aciertos,fp,omisiones,correcto",
    [
        ("", [], 0, 0, 0, True),
        ("", [(0, [25, 25, 75, 75])], 0, 1, 0, False),
        ("0 .5 .5 .5 .5\n", [], 0, 0, 1, False),
        ("0 .5 .5 .5 .5\n", [(1, [25, 25, 75, 75])], 0, 1, 1, False),
        ("0 .5 .5 .5 .5\n", [(0, [0, 0, 20, 20])], 0, 1, 1, False),
        ("0 .5 .5 .5 .5\n", [(0, [25, 25, 75, 75]), (0, [25, 25, 75, 75])], 1, 1, 0, False),
        ("0 .5 .5 .5 .5\n1 .2 .2 .2 .2\n",
         [(1, [10, 10, 30, 30]), (0, [25, 25, 75, 75])], 2, 0, 0, True),
    ],
)
def test_evalua_fondos_duplicados_clases_y_localizacion(
    tmp_path, monkeypatch, etiquetas, detecciones, aciertos, fp, omisiones, correcto,
):
    dataset = tmp_path / "datos"
    fotos = dataset / "images" / "test"
    etiquetas_dir = dataset / "labels" / "test"
    fotos.mkdir(parents=True)
    etiquetas_dir.mkdir(parents=True)
    (fotos / "prueba.jpg").touch()
    (etiquetas_dir / "prueba.txt").write_text(etiquetas, encoding="ascii")
    cajas = [
        SimpleNamespace(
            cls=Mock(item=Mock(return_value=clase)),
            conf=Mock(item=Mock(return_value=0.9)),
            xyxy=Mock(tolist=Mock(return_value=[coordenadas])),
        )
        for clase, coordenadas in detecciones
    ]
    resultado = SimpleNamespace(boxes=cajas, orig_shape=(100, 100), save=Mock())
    modelo = SimpleNamespace(names={0: "iluminador", 1: "sombra"}, predict=Mock(return_value=[resultado]))
    monkeypatch.setattr(comprobar_predicciones, "YOLO", Mock(return_value=modelo))
    salida = tmp_path / "resultado"
    informe = comprobar_predicciones.comprobar(tmp_path / "peso.pt", dataset, salida, 0.5)
    assert informe["aciertos"] == aciertos
    assert informe["falsos_positivos"] == fp
    assert informe["omisiones"] == omisiones
    assert informe["correctos"] == int(correcto)
    assert informe["fondos"] == int(not etiquetas)
    assert informe["fondos_con_falsas_detecciones"] == int(not etiquetas and bool(detecciones))
    assert json.loads((salida / "predicciones.json").read_text(encoding="utf-8"))["total"] == 1
    modelo.predict.assert_called_once_with(
        source=str(fotos / "prueba.jpg"), conf=0.5, device="cpu", verbose=False,
    )
