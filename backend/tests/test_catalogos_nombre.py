"""Marcas, proveedores y categorias: nombre en blanco, renombrar contra uno
desactivado y traduccion de los errores de integridad."""

import asyncio
import json
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest
from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy.exc import IntegrityError

from app.main import manejar_error_integridad
from app.routers import categorias, marcas, proveedores
from app.schemas.categoria import CategoriaCreate, CategoriaUpdate
from app.schemas.marca import MarcaCreate, MarcaUpdate
from app.schemas.proveedor import ProveedorCreate, ProveedorUpdate


@pytest.mark.parametrize(
    "schema",
    [MarcaCreate, MarcaUpdate, ProveedorCreate, ProveedorUpdate, CategoriaCreate, CategoriaUpdate],
)
def test_nombre_en_blanco_se_rechaza(schema):
    with pytest.raises(ValidationError) as error:
        schema(nombre="   ")
    assert "El nombre no puede quedar en blanco" in str(error.value)


def test_nombre_se_guarda_sin_espacios():
    assert MarcaCreate(nombre="  Revlon ").nombre == "Revlon"
    assert ProveedorCreate(nombre=" Andina ").nombre == "Andina"


def _repo(monkeypatch, modulo, clase, actual, conflicto):
    repo = SimpleNamespace(
        obtener_por_id=AsyncMock(return_value=actual),
        obtener_por_nombre=AsyncMock(return_value=conflicto),
        guardar=AsyncMock(side_effect=lambda x: x),
    )
    monkeypatch.setattr(modulo, clase, lambda db: repo)
    return repo


def test_renombrar_marca_a_una_desactivada_explica_como_reactivarla(monkeypatch):
    async def _caso():
        actual = SimpleNamespace(id=1, nombre="Loreal", activo=True)
        inactiva = SimpleNamespace(id=2, nombre="Revlon", activo=False)
        repo = _repo(monkeypatch, marcas, "MarcaRepository", actual, inactiva)
        with pytest.raises(HTTPException) as error:
            await marcas.actualizar_marca(1, MarcaUpdate(nombre="Revlon"), (1, "admin"), None)
        assert error.value.status_code == 400
        assert "desactivada" in error.value.detail
        repo.guardar.assert_not_awaited()

    asyncio.run(_caso())


def test_renombrar_marca_solo_por_mayusculas_se_acepta(monkeypatch):
    async def _caso():
        actual = SimpleNamespace(id=1, nombre="loreal", activo=True)
        _repo(monkeypatch, marcas, "MarcaRepository", actual, actual)
        resultado = await marcas.actualizar_marca(1, MarcaUpdate(nombre="Loreal"), (1, "admin"), None)
        assert resultado.nombre == "Loreal"

    asyncio.run(_caso())


def test_marca_con_nombre_null_no_borra_el_nombre(monkeypatch):
    async def _caso():
        actual = SimpleNamespace(id=1, nombre="Loreal", activo=True)
        _repo(monkeypatch, marcas, "MarcaRepository", actual, None)
        resultado = await marcas.actualizar_marca(1, MarcaUpdate(nombre=None), (1, "admin"), None)
        assert resultado.nombre == "Loreal"

    asyncio.run(_caso())


def test_renombrar_proveedor_a_uno_desactivado(monkeypatch):
    async def _caso():
        actual = SimpleNamespace(id=1, nombre="Andina", contacto=None, telefono=None, email=None, activo=True)
        inactivo = SimpleNamespace(id=2, nombre="Sur", activo=False)
        _repo(monkeypatch, proveedores, "ProveedorRepository", actual, inactivo)
        with pytest.raises(HTTPException) as error:
            await proveedores.actualizar_proveedor(1, ProveedorUpdate(nombre="Sur"), (1, "admin"), None)
        assert "desactivado" in error.value.detail

    asyncio.run(_caso())


def test_renombrar_categoria_a_una_desactivada(monkeypatch):
    async def _caso():
        actual = SimpleNamespace(id=1, nombre="Uñas", padre_id=None, activo=True)
        inactiva = SimpleNamespace(id=2, nombre="Cabello", activo=False)
        _repo(monkeypatch, categorias, "CategoriaRepository", actual, inactiva)
        with pytest.raises(HTTPException) as error:
            await categorias.actualizar_categoria(1, CategoriaUpdate(nombre="Cabello"), (1, "admin"), None)
        assert "desactivada" in error.value.detail

    asyncio.run(_caso())


def _integridad(mensaje, sqlstate=None):
    origen = Exception(mensaje)
    origen.sqlstate = sqlstate
    return IntegrityError("INSERT ...", {}, origen)


async def _detalle(exc):
    respuesta = await manejar_error_integridad(SimpleNamespace(url=SimpleNamespace(path="/x")), exc)
    return respuesta.status_code, json.loads(respuesta.body)["detail"]


@pytest.mark.parametrize(
    "indice,esperado",
    [("uq_marca_nombre_lower", "marca"), ("uq_proveedor_nombre_lower", "proveedor")],
)
def test_duplicado_de_marca_y_proveedor_con_mensaje_propio(indice, esperado):
    async def _caso():
        codigo, detalle = await _detalle(_integridad(f'viola "{indice}"', "23505"))
        assert codigo == 409
        assert f"Ya existe un{'a' if esperado == 'marca' else ''} {esperado}" in detalle

    asyncio.run(_caso())


def test_not_null_no_se_presenta_como_valor_repetido():
    async def _caso():
        _, detalle = await _detalle(_integridad('null en la columna "nombre"', "23502"))
        assert "ya esta en uso" not in detalle
        assert "obligatorio" in detalle

    asyncio.run(_caso())
