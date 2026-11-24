import logging
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import hash_password
from app.models.rol import Rol
from app.models.categoria import Categoria
from app.models.marca import Marca
from app.models.usuario import Usuario
from app.models.compra import Moneda
from app.models.contabilidad import CategoriaGasto
from app.models.razon_movimiento import RAZONES_PREDEFINIDAS, RazonMovimiento
from app.models.sucursal import ConfiguracionSistema, Sucursal

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
        await self._asegurar_sucursal_predeterminada()
        await self._asegurar_razones_movimiento()
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

    # La busqueda no distingue mayusculas, igual que el indice unico
    # lower(nombre): con `==` exacto, renombrar "Peroxidos" a "Peróxidos" en la
    # base hacia que el arranque siguiente creara otra vez "Peroxidos".
    async def _asegurar_categorias(self) -> None:
        for nombre in ["General", "Tintes", "Peróxidos"]:
            existe = await self.db.execute(
                select(Categoria).where(func.lower(Categoria.nombre) == nombre.lower())
            )
            if existe.scalar_one_or_none() is None:
                self.db.add(Categoria(nombre=nombre, activo=True))

    async def _asegurar_marcas(self) -> None:
        for nombre in ["Schwarzkopf", "L'Oréal"]:
            existe = await self.db.execute(
                select(Marca).where(func.lower(Marca.nombre) == nombre.lower())
            )
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

    async def _asegurar_sucursal_predeterminada(self) -> None:
        # Base nueva (create_all): sin sucursal no se puede registrar nada,
        # porque toda operación lleva una. La migración hace lo mismo con una
        # base existente.
        config = await self.db.get(ConfiguracionSistema, 1)
        if config is not None:
            return
        resultado = await self.db.execute(
            select(Sucursal).order_by(Sucursal.id).limit(1)
        )
        sucursal = resultado.scalar_one_or_none()
        if sucursal is None:
            sucursal = Sucursal(nombre="Sucursal principal", activo=True)
            self.db.add(sucursal)
            await self.db.flush()
        self.db.add(
            ConfiguracionSistema(id=1, sucursal_predeterminada_id=sucursal.id)
        )
        logger.info("Sucursal predeterminada: %s", sucursal.nombre)

    async def _asegurar_razones_movimiento(self) -> None:
        resultado = await self.db.execute(select(RazonMovimiento.codigo))
        existentes = {codigo for codigo in resultado.scalars() if codigo}
        for codigo, nombre, tipo, sistema, destino in RAZONES_PREDEFINIDAS:
            if codigo not in existentes:
                self.db.add(RazonMovimiento(
                    codigo=codigo, nombre=nombre, tipo_movimiento=tipo,
                    sistema=sistema, requiere_sucursal_destino=destino,
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