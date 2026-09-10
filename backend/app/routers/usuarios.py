from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db
from app.core.security import require_admin
from app.repositories.usuario_repository import UsuarioRepository
from app.services.usuario_service import UsuarioService
from app.schemas.usuario import (
    RolOut,
    UsuarioCreate,
    UsuarioOut,
    UsuarioUpdate,
)

router = APIRouter(prefix="/api/usuarios", tags=["Usuarios"])


def _service(db: AsyncSession) -> UsuarioService:
    return UsuarioService(UsuarioRepository(db))


@router.get("/", response_model=list[UsuarioOut])
async def listar_usuarios(
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    service = _service(db)
    return [service.to_out(u) for u in await service.listar()]


@router.get("/roles", response_model=list[RolOut])
async def listar_roles(
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await _service(db).listar_roles()


@router.post("/", response_model=UsuarioOut, status_code=201)
async def crear_usuario(
    body: UsuarioCreate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    service = _service(db)
    usuario = await service.crear(body)
    return service.to_out(usuario)


@router.put("/{usuario_id}", response_model=UsuarioOut)
async def actualizar_usuario(
    usuario_id: int,
    body: UsuarioUpdate,
    current_user: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    service = _service(db)
    usuario = await service.actualizar(usuario_id, body, current_user[0])
    return service.to_out(usuario)


@router.delete("/{usuario_id}", response_model=UsuarioOut)
async def desactivar_usuario(
    usuario_id: int,
    current_user: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    service = _service(db)
    usuario = await service.desactivar(usuario_id, current_user[0])
    return service.to_out(usuario)


@router.post("/{usuario_id}/activar", response_model=UsuarioOut)
async def activar_usuario(
    usuario_id: int,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    service = _service(db)
    usuario = await service.activar(usuario_id)
    return service.to_out(usuario)