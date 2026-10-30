import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.exc import IntegrityError

from app.core.config import settings
from app.db.base import Base
from app.db.session import SessionLocal, engine
from app.routers import (
    auth,
    productos,
    inventario,
    inferencia,
    usuarios,
    categorias,
    marcas,
    proveedores,
    reportes,
    ventas,
    compras,
    sueldos,
    caja,
    contabilidad,
)
from app.services.seed_service import SeedService
from app.yolo.inference_service import InferenceService

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Iniciando %s v%s", settings.APP_NAME, settings.VERSION)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    async with SessionLocal() as session:
        await SeedService(session).ejecutar()
    InferenceService().cargar_modelo()
    yield
    logger.info("Apagando %s", settings.APP_NAME)


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.VERSION,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    # Cualquier puerto local: sirve al servidor web de Flutter (puerto aleatorio)
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(productos.router)
app.include_router(inventario.router)
app.include_router(inferencia.router)
app.include_router(usuarios.router)
app.include_router(categorias.router)
app.include_router(marcas.router)
app.include_router(proveedores.router)
app.include_router(reportes.router)
app.include_router(ventas.router)
app.include_router(compras.compras_router)
app.include_router(compras.monedas_router)
app.include_router(sueldos.router)
app.include_router(caja.caja_router)
app.include_router(caja.clientes_router)
app.include_router(contabilidad.router)


@app.exception_handler(IntegrityError)
async def manejar_error_integridad(request: Request, exc: IntegrityError):
    """Convierte una violacion de unicidad de la base en un 409 legible.

    Sin esto, escribir un nombre o un codigo de barras que ya existe se
    devuelve como 500 Internal Server Error con un volcado de SQLAlchemy:
    el usuario ve un fallo del servidor en vez de un mensaje que diga que
    el valor esta repetido. El rollback de la sesion lo hace get_db().
    """
    detalle = str(getattr(exc, "orig", exc))
    if (
        "uq_categoria_nombre_lower" in detalle
        or "uq_categorias_nombre_lower" in detalle
        or "categorias_nombre_key" in detalle
    ):
        mensaje = (
            "Ya existe una categoria con ese nombre (no se distinguen las "
            "mayusculas de las minusculas)."
        )
    elif "uq_usuario_email_lower" in detalle or "uq_usuarios_email_lower" in detalle:
        mensaje = "Ya existe un usuario registrado con ese correo."
    elif "codigo_barras" in detalle:
        mensaje = "Ese codigo de barras ya pertenece a otro producto."
    elif "sku" in detalle:
        mensaje = "Ese SKU ya pertenece a otro producto."
    else:
        mensaje = "No se pudo guardar: el valor ya esta en uso."
    logger.warning("Integridad en %s: %s", request.url.path, detalle)
    return JSONResponse(status_code=409, content={"detail": mensaje})


@app.get("/")
async def root():
    return {
        "mensaje": f"Bienvenido a {settings.APP_NAME}",
        "version": settings.VERSION,
        "documentacion": "/docs",
    }


@app.get("/api/health")
async def health():
    """Estado del servidor. yolo_disponible=false mientras no exista best.pt."""
    return {
        "estado": "ok",
        "servidor": settings.APP_NAME,
        "version": settings.VERSION,
        "yolo_disponible": InferenceService().modelo_disponible,
    }