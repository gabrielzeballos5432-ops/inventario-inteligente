import asyncio
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock, create_autospec

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.venta import VentaCreate, VentaDetalleCreate
from app.services.venta_service import VentaService, VentaValidationError, _total_linea


def venta(**cambios):
    datos = dict(
        detalles=[dict(producto_id=1, cantidad=3, precio_unitario_negociado="3.33")],
        pagos=[dict(metodo_pago="qr", monto="9.99")],
    )
    return VentaCreate(**(datos | cambios))


def test_total_linea_calcula_precio_por_cantidad():
    assert _total_linea(venta().detalles[0]) == Decimal("9.99")


@pytest.mark.parametrize("total", ["9.96", "10.02"])
def test_total_linea_admite_limites_de_redondeo(total):
    detalle = VentaDetalleCreate(
        producto_id=1, cantidad=3, precio_unitario_negociado="3.33", total_linea=total
    )
    assert _total_linea(detalle) == Decimal(total)


@pytest.mark.parametrize("total", ["9.95", "10.03"])
def test_total_linea_rechaza_diferencia_fuera_de_tolerancia(total):
    detalle = VentaDetalleCreate(
        producto_id=1, cantidad=3, precio_unitario_negociado="3.33", total_linea=total
    )
    with pytest.raises(VentaValidationError, match="no corresponde"):
        _total_linea(detalle)


def test_huella_no_depende_de_la_clave_idempotencia():
    assert VentaService._huella(venta(clave_idempotencia="clave-uno")) == (
        VentaService._huella(venta(clave_idempotencia="clave-dos"))
    )


def test_huella_cambia_si_cambia_la_operacion():
    assert VentaService._huella(venta()) != VentaService._huella(
        venta(tipo_venta="mayorista")
    )


def test_claves_distintas_rechazan_antes_de_consultar():
    db = create_autospec(AsyncSession, instance=True)
    with pytest.raises(VentaValidationError, match="no coincide"):
        asyncio.run(VentaService(db).registrar(
            venta(clave_idempotencia="clave-uno"), 1, "clave-dos", sucursal_id=1
        ))
    db.execute.assert_not_awaited()
    db.add.assert_not_called()


def test_reintento_con_misma_huella_devuelve_venta_sin_escribir():
    db = create_autospec(AsyncSession, instance=True)
    servicio = VentaService(db)
    datos = venta(clave_idempotencia="clave-uno")
    existente = SimpleNamespace(huella_solicitud=servicio._huella(datos))
    servicio._obtener_por_clave = AsyncMock(return_value=existente)
    assert asyncio.run(servicio.registrar(datos, 1, sucursal_id=1)) is existente
    servicio._obtener_por_clave.assert_awaited_once_with("clave-uno", 1)
    db.add.assert_not_called()
    db.commit.assert_not_awaited()


def test_clave_reutilizada_con_otros_datos_rechaza():
    db = create_autospec(AsyncSession, instance=True)
    servicio = VentaService(db)
    servicio._obtener_por_clave = AsyncMock(
        return_value=SimpleNamespace(huella_solicitud="otra-huella")
    )
    with pytest.raises(VentaValidationError, match="otros datos"):
        asyncio.run(servicio.registrar(venta(clave_idempotencia="clave-uno"), 1, sucursal_id=1))
    db.add.assert_not_called()
    db.commit.assert_not_awaited()
