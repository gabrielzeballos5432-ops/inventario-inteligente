from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db
from app.core.security import get_current_user_id, require_admin
from app.models.marca import Marca
from app.repositories.marca_repository import MarcaRepository
from app.schemas.marca import MarcaCreate, MarcaOut, MarcaUpdate

router = APIRouter(prefix="/api/marcas", tags=["Marcas"])


@router.get("/", response_model=list[MarcaOut])
async def listar_marcas(
    db: AsyncSession = Depends(get_db),
    _: int = Depends(get_current_user_id),
):
    repo = MarcaRepository(db)
    return await repo.listar_todas()


@router.get("/{marca_id}", response_model=MarcaOut)
async def obtener_marca(
    marca_id: int,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(get_current_user_id),
):
    repo = MarcaRepository(db)
    marca = await repo.obtener_por_id(marca_id)
    if marca is None:
        raise HTTPException(status_code=404, detail="Marca no encontrada")
    return marca


@router.post("/", response_model=MarcaOut, status_code=201)
async def crear_marca(
    body: MarcaCreate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    repo = MarcaRepository(db)
    # Igual que en categorias: el borrado es logico y el nombre sigue
    # reservado, asi que si la marca existe pero esta inactiva se reactiva en
    # lugar de devolver un rechazo que el usuario no puede resolver (no la ve
    # en ninguna lista).
    existente = await repo.obtener_por_nombre(body.nombre)
    if existente is not None:
        if existente.activo:
            raise HTTPException(
                status_code=400,
                detail="Ya existe una marca activa con ese nombre",
            )
        existente.activo = True
        return await repo.guardar(existente)
    marca = Marca(nombre=body.nombre.strip(), activo=True)
    return await repo.crear(marca)


@router.put("/{marca_id}", response_model=MarcaOut)
async def actualizar_marca(
    marca_id: int,
    body: MarcaUpdate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    repo = MarcaRepository(db)
    marca = await repo.obtener_por_id(marca_id)
    if marca is None:
        raise HTTPException(status_code=404, detail="Marca no encontrada")
    cambios = body.model_dump(exclude_unset=True)
    # nombre: null no significa "borrar el nombre" (la columna es NOT NULL).
    if cambios.get("nombre") is None:
        cambios.pop("nombre", None)
    nombre = cambios.get("nombre")
    if nombre is not None and nombre != marca.nombre:
        # El id propio se excluye para que renombrar solo por caja
        # (Loreal -> loreal) no se rechace a si mismo.
        conflicto = await repo.obtener_por_nombre(nombre)
        if conflicto is not None and conflicto.id != marca.id:
            raise HTTPException(
                status_code=400,
                detail=(
                    "Ya existe una marca activa con ese nombre"
                    if conflicto.activo
                    # Sin este caso chocaba con el indice unico y respondia un
                    # 409 generico sobre un nombre que no se ve en la lista.
                    else "Hay una marca desactivada con ese nombre. Registrala "
                    "de nuevo con ese nombre y se reactivara."
                ),
            )
    for campo, valor in cambios.items():
        setattr(marca, campo, valor)
    return await repo.guardar(marca)


@router.delete("/{marca_id}", response_model=MarcaOut)
async def desactivar_marca(
    marca_id: int,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    repo = MarcaRepository(db)
    marca = await repo.obtener_por_id(marca_id)
    if marca is None:
        raise HTTPException(status_code=404, detail="Marca no encontrada")
    marca.activo = False
    return await repo.guardar(marca)