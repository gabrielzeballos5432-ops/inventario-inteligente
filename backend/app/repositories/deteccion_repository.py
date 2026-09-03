from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.models.deteccion import Deteccion


class DeteccionRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def crear(
        self,
        sesion_id: int,
        producto_id: int,
        confianza: float,
        imagen_url: str | None = None,
    ) -> Deteccion:
        deteccion = Deteccion(
            sesion_id=sesion_id,
            producto_id=producto_id,
            confianza=confianza,
            imagen_url=imagen_url,
        )
        self.db.add(deteccion)
        return deteccion

    async def listar_recientes(self, limite: int = 20) -> list[Deteccion]:
        result = await self.db.execute(
            select(Deteccion)
            .options(joinedload(Deteccion.producto))
            .order_by(desc(Deteccion.detectado_en))
            .limit(limite)
        )
        return list(result.scalars().unique().all())