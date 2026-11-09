import logging
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import hash_password
from app.models.rol import Rol
from app.models.categoria import Categoria
from app.models.marca import Marca
from app.models.usuario import Usuario
from app.models.compra import Moneda
from app.models.contabilidad import CategoriaGasto

logger = logging.getLogger(__name__)


class SeedService:
    """Crea datos iniciales: catalogos, monedas y usuario administrador."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def ejecutar(self) -> None:
        await self._asegurar_roles()
        await self._asegurar_categorias()
        await self._asegurar_marcas()
        await self._asegurar_monedas()
        await self._asegurar_categorias_gasto()
        await self._asegurar_admin()
        await self.db.commit()
        logger.info("Datos iniciales verificados")

    async def _asegurar_roles(self) -> None:
        for nombre, descripcion in [
            ("administrador", "Administrador del sistema"),
            ("vendedor", "Operador de inventario"),
        ]:
            existe = await self.db.execute(select(Rol).where(Rol.nombre == nombre))
            if existe.scalar_one_or_none() is None:
                self.db.add(Rol(nombre=nombre, descripcion=descripcion))

    async def _asegurar_categorias(self) -> None:
        for nombre in ["General", "Tintes", "Peroxidos"]:
            existe = await self.db.execute(
                select(Categoria).where(Categoria.nombre == nombre)
            )
            if existe.scalar_one_or_none() is None:
                self.db.add(Categoria(nombre=nombre, activo=True))

    async def _asegurar_marcas(self) -> None:
        for nombre in ["Schwarzkopf", "Loreal"]:
            existe = await self.db.execute(select(Marca).where(Marca.nombre == nombre))
            if existe.scalar_one_or_none() is None:
                self.db.add(Marca(nombre=nombre, activo=True))

    async def _asegurar_monedas(self) -> None:
        for codigo, nombre, simbolo, pais in [
            ("BOB", "Boliviano", "Bs", "Bolivia"),
            ("USD", "Dólar estadounidense", "$", "Estados Unidos"),
        ]:
            existe = await self.db.get(Moneda, codigo)
            if existe is None:
                self.db.add(
                    Moneda(
                        codigo=codigo,
                        nombre=nombre,
                        simbolo=simbolo,
                        pais=pais,
                        decimales=2,
                        activa=True,
                    )
                )

    async def _asegurar_categorias_gasto(self) -> None:
        existe = await self.db.execute(select(CategoriaGasto.id).limit(1))
        if existe.first() is not None:
            return
        for nombre, periodicidad, tipo in [
            ("Luz", "mensual", "variable"),
            ("Agua", "mensual", "fijo"),
            ("Wifi", "mensual", "fijo"),
            ("Alquiler", "mensual", "fijo"),
            ("Scotch", "sin_periodicidad", "variable"),
            ("Papel para tickets", "sin_periodicidad", "variable"),
            ("Etiquetas", "sin_periodicidad", "variable"),
        ]:
            self.db.add(CategoriaGasto(
                nombre=nombre, periodicidad=periodicidad, tipo_importe=tipo,
                activo=True,
            ))

    async def _asegurar_admin(self) -> None:
        existe = await self.db.execute(
            select(Usuario).where(Usuario.email == settings.DEFAULT_ADMIN_EMAIL)
        )
        if existe.scalar_one_or_none() is not None:
            return

        rol = await self.db.execute(
            select(Rol).where(Rol.nombre == "administrador")
        )
        rol_obj = rol.scalar_one_or_none()

        self.db.add(
            Usuario(
                nombre="Administrador",
                email=settings.DEFAULT_ADMIN_EMAIL,
                password_hash=hash_password(settings.DEFAULT_ADMIN_PASSWORD),
                rol_id=rol_obj.id if rol_obj else 1,
                activo=True,
            )
        )
        logger.info("Usuario administrador creado: %s", settings.DEFAULT_ADMIN_EMAIL)