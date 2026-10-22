from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db
from app.core.security import get_current_user_id, require_admin
from app.models.categoria import Categoria
from app.repositories.categoria_repository import CategoriaRepository
from app.schemas.categoria import CategoriaCreate, CategoriaOut, CategoriaUpdate

router = APIRouter(prefix="/api/categorias", tags=["Categorias"])


@router.get("/", response_model=list[CategoriaOut])
async def listar_categorias(
    db: AsyncSession = Depends(get_db),
    _: int = Depends(get_current_user_id),
):
    repo = CategoriaRepository(db)
    return await repo.listar_todas()


@router.get("/{categoria_id}", response_model=CategoriaOut)
async def obtener_categoria(
    categoria_id: int,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(get_current_user_id),
):
    repo = CategoriaRepository(db)
    categoria = await repo.obtener_por_id(categoria_id)
    if categoria is None:
        raise HTTPException(status_code=404, detail="Categoria no encontrada")
    return categoria


@router.post("/", response_model=CategoriaOut, status_code=status.HTTP_201_CREATED)
async def crear_categoria(
    body: CategoriaCreate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    repo = CategoriaRepository(db)
    # El borrado de categorias es logico (activo=false) y el nombre es UNIQUE
    # sobre toda la tabla, no solo entre las activas. Una categoria desactivada
    # sigue reservando su nombre y, como listar_todas() solo devuelve las
    # activas, el usuario recibe un rechazo sin ver nunca el conflicto. Por eso
    # se reactiva la fila en vez de crear otra o devolver un error que no
    # puede resolver.
    existente = await repo.obtener_por_nombre(body.nombre)
    if existente is not None:
        if existente.activo:
            raise HTTPException(
                status_code=400,
                detail="Ya existe una categoria activa con ese nombre",
            )
        existente.activo = True
        existente.padre_id = body.padre_id
        return await repo.guardar(existente)
    if body.padre_id is not None and await repo.obtener_por_id(body.padre_id) is None:
        raise HTTPException(status_code=400, detail="Categoria padre no encontrada")
    categoria = Categoria(nombre=body.nombre, padre_id=body.padre_id, activo=True)
    return await repo.crear(categoria)


@router.put("/{categoria_id}", response_model=CategoriaOut)
async def actualizar_categoria(
    categoria_id: int,
    body: CategoriaUpdate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    repo = CategoriaRepository(db)
    categoria = await repo.obtener_por_id(categoria_id)
    if categoria is None:
        raise HTTPException(status_code=404, detail="Categoria no encontrada")
    cambios = body.model_dump(exclude_unset=True)
    if "nombre" in cambios and cambios["nombre"] != categoria.nombre:
        # Igual que al crear: solo estorba otra categoria activa. Chocar con
        # una inactiva daria un rechazo sobre un nombre que el usuario no ve
        # en ninguna lista.
        #
        # El id importa: la busqueda ignora mayusculas, asi que cambiar
        # "uñas" por "Uñas" se encuentra a si misma y sin esta excepcion el
        # renombrado por capitalizacion quedaria bloqueado.
        conflicto = await repo.obtener_por_nombre(cambios["nombre"])
        if conflicto is not None and conflicto.activo and conflicto.id != categoria.id:
            raise HTTPException(
                status_code=400,
                detail="Ya existe una categoria activa con ese nombre",
            )
    if cambios.get("padre_id") == categoria.id:
        raise HTTPException(status_code=400, detail="Una categoria no puede ser su propio padre")
    for campo, valor in cambios.items():
        setattr(categoria, campo, valor)
    return await repo.guardar(categoria)


@router.delete("/{categoria_id}", response_model=CategoriaOut)
async def desactivar_categoria(
    categoria_id: int,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    repo = CategoriaRepository(db)
    categoria = await repo.obtener_por_id(categoria_id)
    if categoria is None:
        raise HTTPException(status_code=404, detail="Categoria no encontrada")
    categoria.activo = False
    return await repo.guardar(categoria)
