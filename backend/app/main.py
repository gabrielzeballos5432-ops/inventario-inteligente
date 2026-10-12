import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.db.base import Base
from app.db.session import SessionLocal, engine
from app.routers import auth, productos, inventario, inferencia, usuarios, categorias, reportes
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
app.include_router(reportes.router)


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