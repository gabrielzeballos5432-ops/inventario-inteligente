import asyncio
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest
from fastapi import HTTPException

from app.core.security import decode_access_token
from app.services.auth_service import AuthService


def servicio(usuario):
    return AuthService(SimpleNamespace(obtener_por_id=AsyncMock(return_value=usuario)))


def test_renovar_entrega_token_con_el_rol_actual():
    # El rol pudo cambiar desde el login: el token nuevo trae el de ahora.
    usuario = SimpleNamespace(
        id=7, nombre="Ana", activo=True, rol=SimpleNamespace(nombre="administrador")
    )
    respuesta = asyncio.run(servicio(usuario).renovar(7))
    datos = decode_access_token(respuesta.access_token)
    assert datos["sub"] == "7"
    assert datos["rol"] == "administrador"
    assert respuesta.rol == "administrador"
    assert "exp" in datos


def test_no_renueva_a_un_usuario_desactivado():
    usuario = SimpleNamespace(
        id=7, nombre="Ana", activo=False, rol=SimpleNamespace(nombre="vendedor")
    )
    with pytest.raises(HTTPException) as error:
        asyncio.run(servicio(usuario).renovar(7))
    assert error.value.status_code == 403


def test_no_renueva_a_un_usuario_que_ya_no_existe():
    with pytest.raises(HTTPException) as error:
        asyncio.run(servicio(None).renovar(7))
    assert error.value.status_code == 401
