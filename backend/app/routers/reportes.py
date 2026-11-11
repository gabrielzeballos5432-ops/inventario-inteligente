import csv
import io
from datetime import datetime
from decimal import Decimal

from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from openpyxl import Workbook
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db
from app.core.security import get_current_user_id, require_admin
from app.models.movimiento import Movimiento
from app.models.producto import Producto
from app.repositories.movimiento_repository import opciones_detalle_movimiento
from app.repositories.producto_repository import ProductoRepository
from app.schemas.producto import ProductoStockOut, ValorizacionOut
from app.schemas.movimiento import MovimientoOut, movimiento_out

# Todos los reportes aceptan `sucursal_id`; sin él cubren todas las sucursales
# (el stock se suma entre sucursales).
FILTRO_SUCURSAL = Query(default=None, description="Sin valor: todas las sucursales")


async def _movimientos(
    db: AsyncSession,
    fecha_desde: datetime | None,
    fecha_hasta: datetime | None,
    sucursal_id: int | None,
    limite: int,
) -> list[Movimiento]:
    query = (
        select(Movimiento)
        .options(*opciones_detalle_movimiento())
        .order_by(Movimiento.creado_en.desc())
    )
    if fecha_desde:
        query = query.where(Movimiento.creado_en >= fecha_desde)
    if fecha_hasta:
        query = query.where(Movimiento.creado_en <= fecha_hasta)
    if sucursal_id is not None:
        query = query.where(Movimiento.sucursal_id == sucursal_id)
    result = await db.execute(query.limit(limite))
    return list(result.scalars().unique().all())

router = APIRouter(prefix="/api/reportes", tags=["Reportes"])


@router.get("/valorizacion", response_model=ValorizacionOut)
async def valorizacion_inventario(
    sucursal_id: int | None = FILTRO_SUCURSAL,
    _: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    repo = ProductoRepository(db)
    datos = await repo.listar_con_stock(sucursal_id)
    unidades = 0
    costo = Decimal("0")
    venta = Decimal("0")
    bajos = 0
    for d in datos:
        prod = d["producto"]
        stock = d["stock_actual"]
        unidades += stock
        costo += prod.precio_compra * stock
        venta += prod.precio_venta * stock
        if d["stock_bajo"]:
            bajos += 1
    return ValorizacionOut(
        productos_activos=len(datos),
        unidades_totales=unidades,
        productos_stock_bajo=bajos,
        valorizado_costo=costo,
        valorizado_venta=venta,
    )


@router.get("/stock", response_model=list[ProductoStockOut])
async def reporte_stock(
    sucursal_id: int | None = FILTRO_SUCURSAL,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(get_current_user_id),
):
    repo = ProductoRepository(db)
    datos = await repo.listar_con_stock(sucursal_id)
    resultado = []
    for d in datos:
        prod = d["producto"]
        resultado.append(
            ProductoStockOut(
                id=prod.id,
                sku=prod.sku,
                codigo_barras=prod.codigo_barras,
                nombre=prod.nombre,
                descripcion=prod.descripcion,
                categoria_id=prod.categoria_id,
                categoria=prod.categoria,
                marca_id=prod.marca_id,
                proveedor_id=prod.proveedor_id,
                precio_compra=prod.precio_compra,
                precio_venta=prod.precio_venta,
                precio_mayor=prod.precio_mayor,
                stock_minimo=prod.stock_minimo,
                activo=prod.activo,
                stock_actual=d["stock_actual"],
                stock_bajo=d["stock_bajo"],
            )
        )
    return resultado


@router.get("/movimientos", response_model=list[MovimientoOut])
async def reporte_movimientos(
    fecha_desde: datetime | None = Query(default=None),
    fecha_hasta: datetime | None = Query(default=None),
    sucursal_id: int | None = FILTRO_SUCURSAL,
    limite: int = 500,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(get_current_user_id),
):
    movs = await _movimientos(db, fecha_desde, fecha_hasta, sucursal_id, limite)
    return [movimiento_out(m) for m in movs]


def _csv_stock(datos: list[dict]) -> str:
    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(
        ["id", "nombre", "categoria", "precio_compra", "precio_venta",
         "stock_actual", "stock_minimo", "estado"]
    )
    for d in datos:
        prod = d["producto"]
        estado = "BAJO" if d["stock_bajo"] else "NORMAL"
        writer.writerow([
            prod.id, prod.nombre,
            prod.categoria.nombre if prod.categoria else "",
            prod.precio_compra, prod.precio_venta,
            d["stock_actual"], prod.stock_minimo, estado,
        ])
    return buffer.getvalue()


def _csv_movimientos(movs: list[Movimiento]) -> str:
    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(
        ["id", "producto", "sucursal", "tipo", "razon", "sucursal_relacionada",
         "cantidad_anterior", "cantidad", "stock_resultante", "origen",
         "usuario", "fecha"]
    )
    for m in movs:
        writer.writerow([
            m.id,
            m.producto.nombre if m.producto else "",
            m.sucursal.nombre if m.sucursal else "",
            m.tipo,
            m.razon.nombre if m.razon else "",
            m.sucursal_relacionada.nombre if m.sucursal_relacionada else "",
            m.cantidad_anterior, m.cantidad, m.stock_resultante,
            m.origen,
            m.usuario.nombre if m.usuario else "",
            m.creado_en.isoformat() if m.creado_en else "",
        ])
    return buffer.getvalue()


def _xlsx_stock(datos: list[dict]) -> bytes:
    wb = Workbook()
    ws = wb.active
    ws.title = "Stock"
    ws.append(
        ["id", "sku", "nombre", "categoria", "precio_compra", "precio_venta",
         "stock_actual", "stock_minimo", "valorizado_costo", "estado"]
    )
    for d in datos:
        prod = d["producto"]
        ws.append([
            prod.id, prod.sku or "", prod.nombre,
            prod.categoria.nombre if prod.categoria else "",
            float(prod.precio_compra), float(prod.precio_venta),
            d["stock_actual"], prod.stock_minimo,
            float(prod.precio_compra) * d["stock_actual"],
            "BAJO" if d["stock_bajo"] else "NORMAL",
        ])
    buffer = io.BytesIO()
    wb.save(buffer)
    return buffer.getvalue()


def _xlsx_movimientos(movs: list[Movimiento]) -> bytes:
    wb = Workbook()
    ws = wb.active
    ws.title = "Movimientos"
    ws.append(
        ["id", "producto", "sucursal", "tipo", "razon", "sucursal_relacionada",
         "cantidad_anterior", "cantidad", "stock_resultante", "origen",
         "usuario", "fecha"]
    )
    for m in movs:
        ws.append([
            m.id,
            m.producto.nombre if m.producto else "",
            m.sucursal.nombre if m.sucursal else "",
            m.tipo,
            m.razon.nombre if m.razon else "",
            m.sucursal_relacionada.nombre if m.sucursal_relacionada else "",
            m.cantidad_anterior, m.cantidad, m.stock_resultante,
            m.origen,
            m.usuario.nombre if m.usuario else "",
            m.creado_en.isoformat() if m.creado_en else "",
        ])
    buffer = io.BytesIO()
    wb.save(buffer)
    return buffer.getvalue()


@router.get("/exportar-stock")
async def exportar_stock(
    formato: str = Query(default="csv", pattern="^(csv|xlsx)$"),
    sucursal_id: int | None = FILTRO_SUCURSAL,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    repo = ProductoRepository(db)
    datos = await repo.listar_con_stock(sucursal_id)
    if formato == "xlsx":
        return StreamingResponse(
            io.BytesIO(_xlsx_stock(datos)),
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={
                "Content-Disposition": "attachment; filename=reporte_stock.xlsx"
            },
        )
    contenido = _csv_stock(datos).encode("utf-8-sig")
    return StreamingResponse(
        io.BytesIO(contenido),
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": "attachment; filename=reporte_stock.csv"
        },
    )


@router.get("/exportar-movimientos")
async def exportar_movimientos(
    fecha_desde: datetime | None = Query(default=None),
    fecha_hasta: datetime | None = Query(default=None),
    sucursal_id: int | None = FILTRO_SUCURSAL,
    limite: int = 500,
    formato: str = Query(default="csv", pattern="^(csv|xlsx)$"),
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    movs = await _movimientos(db, fecha_desde, fecha_hasta, sucursal_id, limite)
    if formato == "xlsx":
        return StreamingResponse(
            io.BytesIO(_xlsx_movimientos(movs)),
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={
                "Content-Disposition": "attachment; filename=reporte_movimientos.xlsx"
            },
        )
    contenido = _csv_movimientos(movs).encode("utf-8-sig")
    return StreamingResponse(
        io.BytesIO(contenido),
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": "attachment; filename=reporte_movimientos.csv"
        },
    )