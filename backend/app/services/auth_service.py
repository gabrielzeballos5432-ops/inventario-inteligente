from fastapi import HTTPException, status

from app.core.security import hash_password, verify_password, create_access_token
from app.models.usuario import Usuario
from app.repositories.usuario_repository import UsuarioRepository
from app.schemas.auth import TokenResponse
from app.schemas.usuario import UsuarioCreate


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
            data={"sub": str(usuario.id), "rol": usuario.rol.nombre}
        )
        return TokenResponse(
            access_token=token,
            usuario_id=usuario.id,
            nombre=usuario.nombre,
            rol=usuario.rol.nombre,
        )

    async def renovar(self, usuario_id: int) -> TokenResponse:
        """Entrega un token nuevo a una sesión que sigue vigente.

        La app lo pide sola mientras se usa, para que un turno largo no termine
        en el login a mitad de una venta. Se vuelve a leer al usuario: si lo
        desactivaron no se renueva, y si le cambiaron el rol el token nuevo
        trae el rol actual (no el que tenía al iniciar sesión).
        """
        usuario = await self.repo.obtener_por_id(usuario_id)
        if usuario is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="La sesión ya no es válida",
            )
        if not usuario.activo:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Usuario desactivado",
            )
        token = create_access_token(
            data={"sub": str(usuario.id), "rol": usuario.rol.nombre}
        )
        return TokenResponse(
            access_token=token,
            usuario_id=usuario.id,
            nombre=usuario.nombre,
            rol=usuario.rol.nombre,
        )

    async def registrar(self, data: UsuarioCreate) -> Usuario:
        existe = await self.repo.obtener_por_email(data.email)
        if existe:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="El email ya esta registrado",
            )

        rol = await self.repo.obtener_rol_por_id(data.rol_id)
        if rol is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Rol invalido",
            )

        usuario = Usuario(
            nombre=data.nombre,
            email=data.email,
            password_hash=hash_password(data.password),
            rol_id=rol.id,
            activo=data.activo,
        )
        return await self.repo.crear(usuario)