import pytest

from entrenamiento.preparar_fotogramas import validar_frecuencia
from entrenamiento.armar_dataset import normalizar_caja, particion_temporal


@pytest.mark.parametrize("valor", [0, -1, float("nan"), float("inf")])
def test_rechaza_frecuencia_invalida(valor):
    with pytest.raises(ValueError, match="frecuencia"):
        validar_frecuencia(valor)


def test_acepta_dos_fotogramas_por_segundo():
    assert validar_frecuencia(2) == 2


@pytest.mark.parametrize("segundo,esperado", [(0, "train"), (5.5, "val"), (8.8, None), (14.5, "test"), (17.7, None), (19, "train")])
def test_separa_bloques_temporales(segundo, esperado):
    assert particion_temporal(segundo) == esperado


def test_normaliza_caja_completa():
    assert normalizar_caja([0, 0, 400, 171]) == (0.5, 0.5, 1, 1)


def test_rechaza_caja_invertida():
    with pytest.raises(ValueError, match="Caja invalida"):
        normalizar_caja([200, 20, 10, 30])
