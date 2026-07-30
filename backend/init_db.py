import asyncio
import logging

from sqlalchemy.ext.asyncio import create_async_engine

from app.core.config import settings
from app.db.base import Base

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def crear_tablas():
    engine = create_async_engine(settings.DATABASE_URL, echo=True)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await engine.dispose()
    logger.info("Tablas creadas exitosamente")


if __name__ == "__main__":
    asyncio.run(crear_tablas())
