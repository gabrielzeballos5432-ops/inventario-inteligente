from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.usuario import Usuario


class UsuarioRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def obtener_por_email(self, email: str) -> Optional[Usuario]:
        result = await self.db.execute(
            select(Usuario).where(Usuario.email == email)
        )
        return result.scalar_one_or_none()

    async def obtener_por_id(self, usuario_id: int) -> Optional[Usuario]:
        return await self.db.get(Usuario, usuario_id)

    async def crear(self, usuario: Usuario) -> Usuario:
        self.db.add(usuario)
        await self.db.commit()
        await self.db.refresh(usuario)
        return usuario
