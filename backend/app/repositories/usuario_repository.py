from typing import Optional

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.models.usuario import Usuario
from app.models.rol import Rol


class UsuarioRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def obtener_por_email(self, email: str) -> Optional[Usuario]:
        result = await self.db.execute(
            select(Usuario)
            .options(joinedload(Usuario.rol))
            .where(func.lower(Usuario.email) == email.lower())
        )
        return result.scalar_one_or_none()

    async def obtener_por_id(self, usuario_id: int) -> Optional[Usuario]:
        result = await self.db.execute(
            select(Usuario)
            .options(joinedload(Usuario.rol))
            .where(Usuario.id == usuario_id)
        )
        return result.scalar_one_or_none()

    async def listar_todos(self) -> list[Usuario]:
        result = await self.db.execute(
            select(Usuario)
            .options(joinedload(Usuario.rol))
            .order_by(Usuario.id.asc())
        )
        return list(result.scalars().unique().all())

    async def listar_roles(self) -> list[Rol]:
        result = await self.db.execute(select(Rol).order_by(Rol.id.asc()))
        return list(result.scalars().all())

    async def obtener_rol_por_nombre(self, nombre: str) -> Optional[Rol]:
        result = await self.db.execute(select(Rol).where(Rol.nombre == nombre))
        return result.scalar_one_or_none()

    async def obtener_rol_por_id(self, rol_id: int) -> Optional[Rol]:
        result = await self.db.execute(select(Rol).where(Rol.id == rol_id))
        return result.scalar_one_or_none()

    async def crear(self, usuario: Usuario) -> Usuario:
        self.db.add(usuario)
        await self.db.commit()
        await self.db.refresh(usuario)
        return usuario

    async def contar_admins_activos(self) -> int:
        result = await self.db.execute(
            select(func.count(Usuario.id))
            .join(Usuario.rol)
            .where(Rol.nombre == "administrador", Usuario.activo.is_(True))
        )
        return result.scalar_one() or 0