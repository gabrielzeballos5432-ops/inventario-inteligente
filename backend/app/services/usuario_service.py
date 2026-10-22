from fastapi import HTTPException, status

from app.core.security import hash_password
from app.models.usuario import Usuario
from app.repositories.usuario_repository import UsuarioRepository
from app.schemas.usuario import UsuarioCreate, UsuarioUpdate


class UsuarioService:
    def __init__(self, repo: UsuarioRepository):
        self.repo = repo

    @staticmethod
    def _rol_cargado(usuario: Usuario):
        """Devuelve `usuario.rol` solo si la relationship YA esta cargada.

        Acceder a una relationship en lazy dispara una consulta, y en SQLAlchemy
        async eso fuera del greenlet lanza MissingGreenlet. Mirar el estado de
        la instancia con __dict__ permite aprovechar el joinedload que ya traen
        las consultas del repositorio (listar, obtener_por_id,
        obtener_por_email) y evitar una consulta extra por usuario.

        El id tiene que coincidir con el rol_id actual: la sesion se crea con
        expire_on_commit=False, de modo que tras cambiar el rol de un usuario
        el joinedload NO sobrescribe la relationship que ya estaba cacheada y
        se terminaria devolviendo el rol_nombre anterior junto al rol_id nuevo
        (el PUT respondia 200 con rol_id 1 y rol_nombre "vendedor").
        """
        rol = usuario.__dict__.get("rol")
        if rol is not None and rol.id != usuario.rol_id:
            return None
        return rol

    async def to_out(self, usuario: Usuario) -> dict:
        """Arma el dict del response_model.

        Es async a proposito: leer `usuario.rol.nombre` cuando la relationship
        viene en lazy lanza MissingGreenlet, porque ese acceso dispara IO
        fuera del greenlet de SQLAlchemy. Ese requisito se cumplio en casi
        todos los metodos del repositorio y se olvido en crear(), lo que hacia
        que el alta de usuario devolviera 500.

        Primero se aprovecha la relationship si ya viene cargada; solo si no,
        se consulta el rol explicitamente.
        """
        rol = self._rol_cargado(usuario)
        if rol is None:
            rol = await self.repo.obtener_rol_por_id(usuario.rol_id)
        return {
            "id": usuario.id,
            "nombre": usuario.nombre,
            "email": usuario.email,
            "rol_id": usuario.rol_id,
            "rol_nombre": rol.nombre if rol else "",
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