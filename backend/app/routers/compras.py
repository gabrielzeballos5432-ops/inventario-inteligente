from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from starlette.concurrency import run_in_threadpool
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db
from app.core.security import get_current_user_id, require_admin
from app.core.sucursal import get_sucursal_activa
from app.schemas.compra import (
    CompraCreate,
    CompraOut,
    MonedaCreate,
    MonedaEstadoUpdate,
    MonedaOut,
)
from app.services.compra_service import CompraService, CompraValidationError
from app.models.producto import Producto
from app.models.proveedor import Proveedor
from app.schemas.lectura_compra import LecturaCompraOut
from app.services.lectura_compra_service import LecturaCompraError, leer_comprobante


compras_router = APIRouter(prefix="/api/compras", tags=["Compras"])
monedas_router = APIRouter(prefix="/api/monedas", tags=["Monedas"])


@monedas_router.get("/", response_model=list[MonedaOut])
async def listar_monedas(
    incluir_inactivas: bool = Query(default=False),
    db: AsyncSession = Depends(get_db),
    _: int = Depends(get_current_user_id),
):
    return await CompraService(db).listar_monedas(incluir_inactivas)


@monedas_router.post("/", response_model=MonedaOut, status_code=201)
async def crear_moneda(
    body: MonedaCreate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await CompraService(db).crear_moneda(body)
    except CompraValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@monedas_router.patch("/{codigo}/estado", response_model=MonedaOut)
async def actualizar_estado_moneda(
    codigo: str,
    body: MonedaEstadoUpdate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        return await CompraService(db).actualizar_estado_moneda(
            codigo.upper(), body.activa
        )
    except CompraValidationError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@compras_router.post("/", response_model=CompraOut, status_code=201)
async def registrar_compra(
    body: CompraCreate,
    current_user: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
    sucursal_id: int = Depends(get_sucursal_activa),
):
    try:
        return await CompraService(db).registrar(
            body, current_user[0], sucursal_id=sucursal_id
        )
    except CompraValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@compras_router.get("/", response_model=list[CompraOut])
async def listar_compras(
    limite: int = Query(default=50, ge=1, le=200),
    sucursal_id: int | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    _: tuple[int, str] = Depends(require_admin),
):
    """Compras recientes; `sucursal_id` filtra por sucursal (sin él, todas)."""
    return await CompraService(db).listar(limite, sucursal_id)


@compras_router.post("/leer-comprobante", response_model=LecturaCompraOut)
async def leer_foto_compra(
    imagen: UploadFile = File(...),
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    try:
        contenido = await imagen.read(12 * 1024 * 1024 + 1)
    finally:
        await imagen.close()
    if len(contenido) > 12 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="La foto debe pesar como máximo 12 MB.")
    try:
        lectura = await run_in_threadpool(leer_comprobante, contenido)
    except LecturaCompraError as exc:
        raise HTTPException(status_code=exc.estado, detail=str(exc)) from exc
    productos = list((await db.execute(select(Producto).where(Producto.activo.is_(True)))).scalars())
    for detalle in lectura.detalles:
        candidatos = [
            producto for producto in productos
            if (detalle.codigo and detalle.codigo.casefold() in {
                (producto.sku or "").casefold(), (producto.codigo_barras or "").casefold(),
            }) or producto.nombre.casefold() == detalle.descripcion.casefold()
        ]
        if len(candidatos) == 1:
            detalle.producto_id = candidatos[0].id
    if lectura.proveedor_nombre:
        proveedores = list((await db.execute(select(Proveedor).where(Proveedor.activo.is_(True)))).scalars())
        candidatos = [
            proveedor for proveedor in proveedores
            if " ".join(proveedor.nombre.casefold().split()) == " ".join(lectura.proveedor_nombre.casefold().split())
        ]
        if len(candidatos) == 1:
            lectura.proveedor_id = candidatos[0].id
    return lectura


@compras_router.get("/{compra_id}", response_model=CompraOut)
async def obtener_compra(
    compra_id: int,
    db: AsyncSession = Depends(get_db),
    _: tuple[int, str] = Depends(require_admin),
):
    try:
        return await CompraService(db).obtener(compra_id)
    except CompraValidationError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
