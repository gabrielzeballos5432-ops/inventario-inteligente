from fastapi import HTTPException, status

from app.core.security import hash_password
from app.models.usuario import Usuario
from app.repositories.usuario_repository import UsuarioRepository
from app.schemas.usuario import UsuarioCreate, UsuarioUpdate


class UsuarioService:
    def __init__(self, repo: UsuarioRepository):
        self.repo = repo

    def to_out(self, usuario: Usuario) -> dict:
        return {
            "id": usuario.id,
            "nombre": usuario.nombre,
            "email": usuario.email,
            "rol_id": usuario.rol_id,
            "rol_nombre": usuario.rol.nombre if usuario.rol else "",
            "activo": usuario.activo,
            "created_at": usuario.creado_en,
        }

    async def _validar_referencias(self, rol_id: int | None) -> None:
        if rol_id is not None:
            roles = {rol.id for rol in await self.repo.listar_roles()}
            if rol_id not in roles:
                raise HTTPException(status_code=400, detail="Rol no encontrado")

    async def listar(self) -> list[Usuario]:
        return await self.repo.listar_todos()

    async def listar_roles(self):
        return await self.repo.listar_roles()

    async def crear(self, data: UsuarioCreate) -> Usuario:
        await self._validar_referencias(data.rol_id)

        if await self.repo.obtener_por_email(data.email):
            raise HTTPException(status_code=400, detail="Ya existe un usuario con ese email")

        usuario = Usuario(
            nombre=data.nombre,
            email=data.email,
            password_hash=hash_password(data.password),
            rol_id=data.rol_id,
            activo=data.activo,
        )
        return await self.repo.crear(usuario)

    async def actualizar(
        self, usuario_id: int, data: UsuarioUpdate, current_user_id: int
    ) -> Usuario:
        usuario = await self.repo.obtener_por_id(usuario_id)
        if usuario is None:
            raise HTTPException(status_code=404, detail="Usuario no encontrado")

        cambios = data.model_dump(exclude_unset=True)
        await self._validar_referencias(cambios.get("rol_id"))

        if usuario_id == current_user_id:
            if cambios.get("activo") is False:
                raise HTTPException(status_code=400, detail="No puedes desactivar tu propia cuenta")
            if cambios.get("rol_id") is not None and cambios["rol_id"] != usuario.rol_id:
                raise HTTPException(
                    status_code=400,
                    detail="No puedes cambiar tu propio rol desde tu sesion actual",
                )

        nuevo_rol_id = cambios.get("rol_id", usuario.rol_id)
        nuevo_activo = cambios.get("activo", usuario.activo)
        if (
            usuario.rol
            and usuario.rol.nombre == "administrador"
            and usuario.activo
            and (nuevo_rol_id != usuario.rol_id or not nuevo_activo)
        ):
            if await self.repo.contar_admins_activos() <= 1:
                raise HTTPException(
                    status_code=400,
                    detail="Debe existir al menos un administrador activo en el sistema",
                )

        if "email" in cambios and cambios["email"].lower() != usuario.email.lower():
            existente = await self.repo.obtener_por_email(cambios["email"])
            if existente is not None and existente.id != usuario_id:
                raise HTTPException(status_code=400, detail="Ya existe un usuario con ese email")

        password = cambios.pop("password", None)
        if password:
            usuario.password_hash = hash_password(password)

        for campo, valor in cambios.items():
            setattr(usuario, campo, valor)

        await self.repo.db.commit()
        return await self.repo.obtener_por_id(usuario_id)

    async def desactivar(self, usuario_id: int, current_user_id: int) -> Usuario:
        usuario = await self.repo.obtener_por_id(usuario_id)
        if usuario is None:
            raise HTTPException(status_code=404, detail="Usuario no encontrado")
        if usuario_id == current_user_id:
            raise HTTPException(status_code=400, detail="No puedes desactivar tu propia cuenta")
        if (
            usuario.rol
            and usuario.rol.nombre == "administrador"
            and usuario.activo
            and await self.repo.contar_admins_activos() <= 1
        ):
            raise HTTPException(
                status_code=400,
                detail="Debe existir al menos un administrador activo en el sistema",
            )

        usuario.activo = False
        await self.repo.db.commit()
        return await self.repo.obtener_por_id(usuario_id)

    async def activar(self, usuario_id: int) -> Usuario:
        usuario = await self.repo.obtener_por_id(usuario_id)
        if usuario is None:
            raise HTTPException(status_code=404, detail="Usuario no encontrado")
        usuario.activo = True
        await self.repo.db.commit()
        return await self.repo.obtener_por_id(usuario_id)