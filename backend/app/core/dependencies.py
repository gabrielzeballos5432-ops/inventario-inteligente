from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import SessionLocal


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with SessionLocal() as session:
        try:
            yield session
        except Exception:
            # Tras un error de integridad (por ejemplo, un UNIQUE violado) la
            # sesion queda con la transaccion abortada y no admite mas
            # consultas. El cierre ya haria rollback, pero dejarlo explicito
            # evita depender de ese detalle y deja claro el contrato.
            await session.rollback()
            raise
