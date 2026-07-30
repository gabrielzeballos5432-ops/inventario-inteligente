from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db
from app.core.security import get_current_user_id
from app.repositories.producto_repository import ProductoRepository
from app.schemas.producto import ProductoOut, ProductoCreate

router = APIRouter(prefix="/api/productos", tags=["Productos"])


@router.get("/", response_model=list[ProductoOut])
async def listar_productos(
    db: AsyncSession = Depends(get_db),
    _: int = Depends(get_current_user_id),
):
    repo = ProductoRepository(db)
    return await repo.listar_todos()


@router.get("/{producto_id}", response_model=ProductoOut)
async def obtener_producto(
    producto_id: int,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(get_current_user_id),
):
    repo = ProductoRepository(db)
    return await repo.obtener_por_id(producto_id)
