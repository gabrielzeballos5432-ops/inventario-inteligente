from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db
from app.core.security import get_current_user_id, require_admin
from app.repositories.usuario_repository import UsuarioRepository
from app.services.auth_service import AuthService
from app.services.usuario_service import UsuarioService
from app.schemas.auth import LoginRequest, TokenResponse, UsuarioCreado
from app.schemas.usuario import UsuarioCreate, UsuarioOut

router = APIRouter(prefix="/api/auth", tags=["Autenticacion"])


@router.post("/login", response_model=TokenResponse)
async def login(body: LoginRequest, db: AsyncSession = Depends(get_db)):
    repo = UsuarioRepository(db)
    service = AuthService(repo)
    return await service.login(body.email, body.password)


@router.post("/registro", response_model=UsuarioOut, status_code=201)
async def registro(
    body: UsuarioCreate,
    _: tuple[int, str] = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    repo = UsuarioRepository(db)
    service = AuthService(repo)
    usuario = await service.registrar(body)
    return UsuarioService(repo).to_out(usuario)


@router.get("/me", response_model=UsuarioCreado)
async def obtener_usuario_actual(
    usuario_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    repo = UsuarioRepository(db)
    usuario = await repo.obtener_por_id(usuario_id)
    return UsuarioCreado(
        id=usuario.id,
        nombre=usuario.nombre,
        email=usuario.email,
        rol=usuario.rol.nombre if usuario.rol else "",
        activo=usuario.activo,
    )