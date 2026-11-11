from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db
from app.core.security import get_current_user_id, require_admin
from app.core.sucursal import get_sucursal_activa
from app.models.inventario import Inventario
from app.models.movimiento import Movimiento
from app.models.producto import Producto
from app.models.razon_movimiento import razon_sistema
from app.repositories.producto_repository import ProductoRepository
from app.schemas.producto import ProductoOut, ProductoCreate, ProductoUpdate, ProductoStockOut

router = APIRouter(prefix="/api/productos", tags=["Productos"])


@router.get("/", response_model=list[ProductoOut])
async def listar_productos(
    texto: str | None = None,
    categoria_id: int | None = None,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(get_current_user_id),
):
    repo = ProductoRepository(db)
    return await repo.listar_todos(texto=texto, categoria_id=categoria_id)


@router.get("/{producto_id}", response_model=ProductoOut)
async def obtener_producto(
    producto_id: int,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(get_current_user_id),
):
    repo = ProductoRepository(db)
    producto = await repo.obtener_por_id(producto_id)
    if producto is None:
        raise HTTPException(status_code=404, detail="Producto no encontrado")
    return producto


@router.post("/", response_model=ProductoOut, status_code=status.HTTP_201_CREATED)
async def crear_producto(
    body: ProductoCreate,
    administrador: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
    sucursal_id: int = Depends(get_sucursal_activa),
):
    repo = ProductoRepository(db)
    producto = Producto(
        sku=body.sku,
        codigo_barras=body.codigo_barras,
        nombre=body.nombre,
        descripcion=body.descripcion,
        categoria_id=body.categoria_id,
        marca_id=body.marca_id,
        proveedor_id=body.proveedor_id,
        precio_compra=body.precio_compra,
        precio_venta=body.precio_venta,
        precio_mayor=body.precio_mayor,
        stock_minimo=body.stock_minimo,
        activo=True,
    )
    if body.cantidad_inicial > 0:
        # Producto y stock inicial en la misma transacción: si la entrada
        # fallara, tampoco queda el producto creado a medias. El movimiento
        # deja la auditoría (fecha, usuario y sucursal).
        db.add(producto)
        await db.flush()
        db.add(Inventario(
            producto_id=producto.id,
            sucursal_id=sucursal_id,
            cantidad=body.cantidad_inicial,
        ))
        db.add(Movimiento(
            producto_id=producto.id,
            sucursal_id=sucursal_id,
            razon_movimiento_id=razon_sistema("stock_inicial"),
            usuario_id=administrador[0],
            tipo="entrada",
            cantidad_anterior=0,
            cantidad=body.cantidad_inicial,
            stock_resultante=body.cantidad_inicial,
            origen="manual",
        ))
    return await repo.crear(producto)


@router.put("/{producto_id}", response_model=ProductoOut)
async def actualizar_producto(
    producto_id: int,
    body: ProductoUpdate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    repo = ProductoRepository(db)
    producto = await repo.obtener_por_id(producto_id)
    if producto is None:
        raise HTTPException(status_code=404, detail="Producto no encontrado")
    for campo, valor in body.model_dump(exclude_unset=True).items():
        setattr(producto, campo, valor)
    return await repo.guardar(producto)


@router.delete("/{producto_id}", response_model=ProductoOut)
async def desactivar_producto(
    producto_id: int,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    repo = ProductoRepository(db)
    producto = await repo.obtener_por_id(producto_id)
    if producto is None:
        raise HTTPException(status_code=404, detail="Producto no encontrado")
    producto.activo = False
    return await repo.guardar(producto)


@router.patch("/{producto_id}/stock-minimo", response_model=ProductoOut)
async def configurar_stock_minimo(
    producto_id: int,
    body: dict,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    repo = ProductoRepository(db)
    producto = await repo.obtener_por_id(producto_id)
    if producto is None:
        raise HTTPException(status_code=404, detail="Producto no encontrado")
    stock_minimo = body.get("stock_minimo")
    if stock_minimo is None or not isinstance(stock_minimo, int) or stock_minimo < 0:
        raise HTTPException(status_code=400, detail="stock_minimo debe ser un entero >= 0")
    producto.stock_minimo = stock_minimo
    return await repo.guardar(producto)