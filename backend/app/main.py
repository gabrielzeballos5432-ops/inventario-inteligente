import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.exc import DataError, IntegrityError

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
    configuracion,
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
app.include_router(configuracion.sucursales_router)
app.include_router(configuracion.configuracion_router)
app.include_router(configuracion.razones_router)


def _mensaje_validacion(error: dict) -> str:
    """Traduce el mensaje de Pydantic al castellano.

    Los validadores propios ya escriben en castellano ("Value error, ..."),
    pero las restricciones de Field (le, max_length, decimal_places) salian en
    ingles: "Input should be less than or equal to 99999999.99".
    """
    tipo = error.get("type", "")
    ctx = error.get("ctx") or {}
    msg = str(error.get("msg", ""))
    traducciones = {
        "missing": "Falta este dato",
        "string_too_short": "Debe tener al menos {min_length} caracteres",
        "string_too_long": "Admite hasta {max_length} caracteres",
        "greater_than": "Debe ser mayor a {gt}",
        "greater_than_equal": "Debe ser mayor o igual a {ge}",
        "less_than": "Debe ser menor a {lt}",
        "less_than_equal": "Debe ser como maximo {le}",
        "decimal_max_places": "Admite hasta {decimal_places} decimales",
        "decimal_max_digits": "El numero es demasiado grande",
        "decimal_whole_digits": "El numero es demasiado grande",
        "decimal_parsing": "Debe ser un numero",
        "int_parsing": "Debe ser un numero entero",
        "int_from_float": "Debe ser un numero entero",
        "float_parsing": "Debe ser un numero",
        "string_pattern_mismatch": "El formato no es valido",
        "literal_error": "Valor no permitido",
        "too_short": "Debe tener al menos {min_length} elementos",
        "too_long": "Admite hasta {max_length} elementos",
        "date_from_datetime_parsing": "Fecha no valida",
        "date_parsing": "Fecha no valida",
    }
    if tipo == "value_error":
        if msg.startswith("Value error, "):
            return msg[len("Value error, "):]
        if "email" in msg.lower():
            return "Ingresa un correo valido (ej. nombre@correo.com)"
        return msg
    plantilla = traducciones.get(tipo)
    if plantilla is None:
        return msg
    try:
        return plantilla.format(**ctx)
    except (KeyError, IndexError):
        return plantilla.split(" {")[0]


@app.exception_handler(RequestValidationError)
async def manejar_error_validacion(request: Request, exc: RequestValidationError):
    """Mismo formato que FastAPI (lista de {loc, msg, type}) con msg en castellano."""
    errores = []
    for error in exc.errors():
        error = dict(error)
        error["msg"] = _mensaje_validacion(error)
        error.pop("ctx", None)
        error.pop("url", None)
        errores.append(error)
    return JSONResponse(status_code=422, content={"detail": jsonable_encoder(errores)})


@app.exception_handler(DataError)
async def manejar_error_de_datos(request: Request, exc: DataError):
    """Valor fuera de rango o demasiado largo para su columna.

    Los schemas ya ponen los topes, pero si alguno se escapa PostgreSQL lanza
    DataError y, sin este manejador, el usuario veia un 500. El rollback lo
    hace get_db().
    """
    logger.warning("Dato fuera de rango en %s: %s", request.url.path, getattr(exc, "orig", exc))
    return JSONResponse(
        status_code=422,
        content={
            "detail": "Uno de los valores es demasiado largo o grande para "
            "guardarse. Revisa los numeros y textos del formulario."
        },
    )


@app.exception_handler(IntegrityError)
async def manejar_error_integridad(request: Request, exc: IntegrityError):
    """Convierte una violacion de unicidad de la base en un 409 legible.

    Sin esto, escribir un nombre o un codigo de barras que ya existe se
    devuelve como 500 Internal Server Error con un volcado de SQLAlchemy:
    el usuario ve un fallo del servidor en vez de un mensaje que diga que
    el valor esta repetido. El rollback de la sesion lo hace get_db().
    """
    detalle = str(getattr(exc, "orig", exc))
    # SQLSTATE: solo 23505 es "valor repetido". Antes un NOT NULL o una clave
    # foranea tambien respondian "el valor ya esta en uso".
    origen = getattr(exc, "orig", None)
    codigo = getattr(origen, "sqlstate", None) or getattr(origen, "pgcode", None)
    if codigo == "23502":
        mensaje = "Falta un dato obligatorio. Revisa el formulario."
    elif codigo == "23503":
        mensaje = (
            "El registro hace referencia a un dato que no existe o que otro "
            "registro todavia usa."
        )
    elif codigo == "23514":
        mensaje = "Uno de los valores no cumple las reglas del sistema."
    elif (
        "uq_categoria_nombre_lower" in detalle
        or "uq_categorias_nombre_lower" in detalle
        or "categorias_nombre_key" in detalle
    ):
        mensaje = (
            "Ya existe una categoria con ese nombre (no se distinguen las "
            "mayusculas de las minusculas)."
        )
    elif "uq_marca_nombre_lower" in detalle:
        mensaje = (
            "Ya existe una marca con ese nombre (no se distinguen las "
            "mayusculas de las minusculas)."
        )
    elif "uq_proveedor_nombre_lower" in detalle:
        mensaje = (
            "Ya existe un proveedor con ese nombre (no se distinguen las "
            "mayusculas de las minusculas)."
        )
    elif "uq_usuario_email_lower" in detalle or "uq_usuarios_email_lower" in detalle:
        mensaje = "Ya existe un usuario registrado con ese correo."
    elif "uq_sucursal_nombre_lower" in detalle:
        mensaje = "Ya existe una sucursal con ese nombre."
    elif "uq_razon_movimiento_nombre_tipo" in detalle:
        mensaje = "Ya existe una razón con ese nombre para ese tipo de movimiento."
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