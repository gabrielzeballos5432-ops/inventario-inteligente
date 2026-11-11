from fastapi import Depends, Header, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db
from app.core.security import decode_access_token, security_scheme
from app.models.sucursal import ConfiguracionSistema, Sucursal


async def obtener_sucursal_predeterminada_id(db: AsyncSession) -> int:
    resultado = await db.execute(
        select(ConfiguracionSistema.sucursal_predeterminada_id).where(
            ConfiguracionSistema.id == 1
        )
    )
    sucursal_id = resultado.scalar_one_or_none()
    if sucursal_id is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="No hay una sucursal predeterminada configurada.",
        )
    return sucursal_id


async def get_sucursal_activa(
    x_sucursal_id: int | None = Header(default=None, alias="X-Sucursal-Id"),
    credentials: HTTPAuthorizationCredentials = Depends(security_scheme),
    db: AsyncSession = Depends(get_db),
) -> int:
    """Sucursal en la que se registra la operación de esta petición.

    La app manda la sucursal elegida en el encabezado `X-Sucursal-Id`. Solo el
    administrador puede operar en otra sucursal: para el vendedor el encabezado
    se ignora y siempre se usa la predeterminada de Configuración, así no puede
    vender ni mover stock de otro local cambiando un valor en la petición.
    """
    payload = decode_access_token(credentials.credentials)
    if x_sucursal_id is not None and payload.get("rol") == "administrador":
        sucursal = await db.get(Sucursal, x_sucursal_id)
        if sucursal is None or not sucursal.activo:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La sucursal seleccionada no existe o está desactivada.",
            )
        return sucursal.id
    return await obtener_sucursal_predeterminada_id(db)
