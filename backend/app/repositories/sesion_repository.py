from typing import Optional

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.sesion_camara import SesionCamara


class SesionRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def crear(
        self,
        usuario_id: int,
        tipo_operacion: str,
    ) -> SesionCamara:
        sesion = SesionCamara(usuario_id=usuario_id, tipo_operacion=tipo_operacion)
        self.db.add(sesion)
        await self.db.flush()
        return sesion

    async def finalizar(self, sesion_id: int) -> Optional[SesionCamara]:
        sesion = await self.db.get(SesionCamara, sesion_id)
        if sesion is None:
            return None
        sesion.fecha_fin = func.now()
        await self.db.commit()
        return sesion

    async def incrementar_detectados(self, sesion_id: int, cantidad: int) -> None:
        sesion = await self.db.get(SesionCamara, sesion_id)
        if sesion is not None:
            sesion.productos_detectados += cantidad
            await self.db.flush()