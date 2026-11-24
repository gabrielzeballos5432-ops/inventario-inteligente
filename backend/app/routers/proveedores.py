from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db
from app.core.security import get_current_user_id, require_admin
from app.models.proveedor import Proveedor
from app.repositories.proveedor_repository import ProveedorRepository
from app.schemas.proveedor import ProveedorCreate, ProveedorOut, ProveedorUpdate

router = APIRouter(prefix="/api/proveedores", tags=["Proveedores"])


def _campos_texto(cambios: dict) -> dict:
    """Normaliza a texto limpio y quita los campos que llegaron vacios.

    Sin esto, editar un proveedor y dejar el contacto en blanco guardaria una
    cadena vacia en vez de NULL, y el formulario los mostraria como "tiene
    dato" cuando en realidad esta en blanco.
    """
    limpios = {}
    for campo in ("nombre", "contacto", "telefono", "email"):
        if campo in cambios:
            valor = cambios[campo]
            if valor is None:
                limpios[campo] = None
                continue
            texto = str(valor).strip()
            limpios[campo] = texto or None
    return limpios


@router.get("/", response_model=list[ProveedorOut])
async def listar_proveedores(
    db: AsyncSession = Depends(get_db),
    _: int = Depends(get_current_user_id),
):
    repo = ProveedorRepository(db)
    return await repo.listar_todos()


@router.get("/{proveedor_id}", response_model=ProveedorOut)
async def obtener_proveedor(
    proveedor_id: int,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(get_current_user_id),
):
    repo = ProveedorRepository(db)
    proveedor = await repo.obtener_por_id(proveedor_id)
    if proveedor is None:
        raise HTTPException(status_code=404, detail="Proveedor no encontrado")
    return proveedor


@router.post("/", response_model=ProveedorOut, status_code=201)
async def crear_proveedor(
    body: ProveedorCreate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    repo = ProveedorRepository(db)
    datos = _campos_texto(body.model_dump())
    # Igual que marcas y categorias: si el nombre estaba en una fila
    # desactivada, esa fila se reactiva y se completan sus datos en vez de
    # crear otra (el nombre sigue reservado por el indice unico).
    existente = await repo.obtener_por_nombre(datos["nombre"])
    if existente is not None:
        if existente.activo:
            raise HTTPException(
                status_code=400,
                detail="Ya existe un proveedor activo con ese nombre",
            )
        for campo, valor in datos.items():
            setattr(existente, campo, valor)
        existente.activo = True
        return await repo.guardar(existente)
    return await repo.crear(Proveedor(**datos, activo=True))


@router.put("/{proveedor_id}", response_model=ProveedorOut)
async def actualizar_proveedor(
    proveedor_id: int,
    body: ProveedorUpdate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    repo = ProveedorRepository(db)
    proveedor = await repo.obtener_por_id(proveedor_id)
    if proveedor is None:
        raise HTTPException(status_code=404, detail="Proveedor no encontrado")
    cambios = body.model_dump(exclude_unset=True)
    cambios.pop("activo", None)
    cambios.update(_campos_texto(cambios))
    # nombre: null no significa "borrar el nombre" (la columna es NOT NULL).
    if cambios.get("nombre") is None:
        cambios.pop("nombre", None)
    nombre = cambios.get("nombre")
    if nombre and nombre != proveedor.nombre:
        conflicto = await repo.obtener_por_nombre(nombre)
        if conflicto is not None and conflicto.id != proveedor.id:
            raise HTTPException(
                status_code=400,
                detail=(
                    "Ya existe un proveedor activo con ese nombre"
                    if conflicto.activo
                    else "Hay un proveedor desactivado con ese nombre. "
                    "Registralo de nuevo con ese nombre y se reactivara."
                ),
            )
    for campo, valor in cambios.items():
        setattr(proveedor, campo, valor)
    return await repo.guardar(proveedor)


@router.delete("/{proveedor_id}", response_model=ProveedorOut)
async def desactivar_proveedor(
    proveedor_id: int,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    repo = ProveedorRepository(db)
    proveedor = await repo.obtener_por_id(proveedor_id)
    if proveedor is None:
        raise HTTPException(status_code=404, detail="Proveedor no encontrado")
    proveedor.activo = False
    return await repo.guardar(proveedor)