import asyncio
from decimal import Decimal
from unittest.mock import create_autospec

import pytest
from app.models.caja import SesionCaja
from app.models.rol import Rol
from app.models.usuario import Usuario
from app.repositories.usuario_repository import UsuarioRepository
from app.services.caja_service import CajaService
from app.services.usuario_service import UsuarioService


@pytest.mark.parametrize(
    "esperado,contado,diferencia",
    [("100", "100", "0.00"), ("100", "95", "-5.00"), ("100", "103.50", "3.50")],
)
def test_caja_calcula_diferencia(esperado, contado, diferencia):
    sesion = SesionCaja(
        id=1, monto_esperado_cierre=Decimal(esperado),
        monto_efectivo_contado=Decimal(contado),
    )
    assert CajaService._salida(sesion)["monto_diferencia_cierre"] == Decimal(diferencia)


@pytest.mark.parametrize(
    "esperado,contado", [(None, None), (Decimal("100"), None), (None, Decimal("100"))]
)
def test_caja_sin_datos_de_cierre_no_inventa_diferencia(esperado, contado):
    sesion = SesionCaja(
        id=1, monto_esperado_cierre=esperado, monto_efectivo_contado=contado
    )
    assert CajaService._salida(sesion)["monto_diferencia_cierre"] is None


@pytest.mark.parametrize("cache", ["coincidente", "obsoleta", "ausente"])
def test_usuario_serializa_rol_sin_consulta_lazy(cache):
    repo = create_autospec(UsuarioRepository, instance=True)
    actual = Rol(id=1, nombre="administrador")
    usuario = Usuario(
        id=1, nombre="Prueba", email="prueba@example.com", rol_id=1, activo=True
    )
    if cache == "coincidente":
        usuario.rol = actual
    elif cache == "obsoleta":
        usuario.rol = Rol(id=2, nombre="vendedor")
    repo.obtener_rol_por_id.return_value = actual
    resultado = asyncio.run(UsuarioService(repo).to_out(usuario))
    assert resultado["rol_id"] == 1
    assert resultado["rol_nombre"] == "administrador"
    if cache == "coincidente":
        repo.obtener_rol_por_id.assert_not_awaited()
    else:
        repo.obtener_rol_por_id.assert_awaited_once_with(1)
