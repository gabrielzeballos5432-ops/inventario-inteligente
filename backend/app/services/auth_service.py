from fastapi import HTTPException, status

from app.core.security import hash_password, verify_password, create_access_token
from app.models.usuario import Usuario
from app.repositories.usuario_repository import UsuarioRepository
from app.schemas.auth import TokenResponse, UsuarioCreate


class AuthService:
    def __init__(self, repo: UsuarioRepository):
        self.repo = repo

    async def login(self, email: str, password: str) -> TokenResponse:
        usuario = await self.repo.obtener_por_email(email)
        if not usuario or not verify_password(password, usuario.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Credenciales invalidas",
            )
        if not usuario.activo:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Usuario desactivado",
            )
        token = create_access_token(
            data={"sub": str(usuario.id), "rol": usuario.rol}
        )
        return TokenResponse(
            access_token=token,
            usuario_id=usuario.id,
            nombre=usuario.nombre,
            rol=usuario.rol,
        )

    async def registrar(self, data: UsuarioCreate) -> Usuario:
        existe = await self.repo.obtener_por_email(data.email)
        if existe:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="El email ya esta registrado",
            )
        usuario = Usuario(
            nombre=data.nombre,
            email=data.email,
            password_hash=hash_password(data.password),
            rol=data.rol,
        )
        return await self.repo.crear(usuario)
