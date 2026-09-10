# Inventario Inteligente - Backend

Sistema de inventario inteligente con FastAPI, SQLAlchemy async, PostgreSQL y vision computacional con YOLO.

## Estructura

```text
backend/
  app/
    core/          Configuracion, seguridad y dependencias
    db/            Sesion, base declarativa y script SQL de referencia (inventario_db.sql)
    models/        Modelos SQLAlchemy (roles, usuarios, categorias, marcas, proveedores, productos, inventario, sesiones_camara, movimientos, detecciones)
    repositories/  Acceso a datos
    routers/       Endpoints por recurso
    schemas/       Schemas Pydantic de entrada/salida
    services/      Logica de negocio (auth, inventario, usuarios, seed)
    yolo/          Servicio de inferencia YOLO
    main.py        Aplicacion FastAPI
  alembic/         Migraciones de base de datos
  requirements.txt
```

## Base de datos

El esquema de referencia es `app/db/inventario_db.sql` (Salon de Belleza Zoom). La migracion Alembic `20260401_00` reproduce exactamente ese esquema:

- `roles`, `usuarios` (email unico en minusculas, `rol_id` FK)
- `categorias` (jerarquia via `padre_id`), `marcas`, `proveedores`
- `productos` (`sku`, `codigo_barras`, `precio_compra`, `precio_venta`, `stock_minimo`)
- `inventario` (stock actual por producto)
- `sesiones_camara`, `detecciones`
- `movimientos` con restriccion matematica de consistencia (`stock_resultante`)

## Ejecutar en local (entorno principal)

La base `inventario_db` vive en el PostgreSQL de Windows (puerto 5432), usuario `admin_user`. Verificar que el servicio `postgresql-x64-18` este corriendo; se puede visualizar con pgAdmin.

```powershell
cd backend
.\venv\Scripts\Activate
pip install -r requirements.txt
python -m alembic -c alembic.ini upgrade head
uvicorn app.main:app --reload --port 8001
```

Al iniciar, la aplicacion siembra datos iniciales (roles `administrador`/`vendedor`, categorias y marcas base, y el usuario `admin@zoom.com` / `Admin12345`).

## Ejecutar con Docker (alternativa / respaldo)

```powershell
docker compose up --build
```

No se puede usar junto con el PostgreSQL local si ambos compiten por el puerto 5432: detener uno antes de levantar el otro.

## Configuracion

Copia `.env.example` a `.env` y ajusta:

| Variable | Descripcion |
| --- | --- |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | Conexion PostgreSQL (BD `inventario_db`, usuario `admin_user`) |
| `SECRET_KEY` | Clave para firmar tokens JWT |
| `DEFAULT_ADMIN_EMAIL`, `DEFAULT_ADMIN_PASSWORD` | Credenciales del admin inicial |
| `YOLO_MODEL_PATH` | Ruta del modelo entrenado (`app/models/best.pt`) |
| `YOLO_CLASS_MAP` | JSON con mapeo clase YOLO -> producto (opcional) |

## Endpoints

- `GET /` estado general.
- `POST /api/auth/login` inicia sesion (email + password) y devuelve JWT.
- `GET /api/auth/me` datos del usuario autenticado.
- `POST /api/auth/registro` crea un usuario (solo administrador).
- `GET /api/usuarios/` lista usuarios (solo administrador).
- `GET /api/usuarios/roles` lista roles (solo administrador).
- `POST /api/usuarios/` crea un usuario (solo administrador).
- `PUT /api/usuarios/{id}` actualiza un usuario (solo administrador).
- `DELETE /api/usuarios/{id}` desactiva un usuario (solo administrador).
- `POST /api/usuarios/{id}/activar` reactiva un usuario (solo administrador).
- `GET /api/categorias/` lista categorias.
- `POST /api/categorias/` crea una categoria (solo administrador).
- `PUT /api/categorias/{id}` actualiza una categoria (solo administrador).
- `DELETE /api/categorias/{id}` desactiva una categoria (solo administrador).
- `GET /api/productos/` lista productos (filtros: `texto`, `categoria_id`).
- `GET /api/productos/{id}` detalle de un producto.
- `POST /api/productos/` crea un producto (solo administrador).
- `PUT /api/productos/{id}` actualiza un producto (solo administrador).
- `DELETE /api/productos/{id}` da de baja un producto (solo administrador).
- `PATCH /api/productos/{id}/stock-minimo` configura el stock minimo (solo administrador).
- `GET /api/inventario/` inventario con stock actual y alertas de stock bajo.
- `GET /api/inventario/historial` historial de movimientos.
- `GET /api/inventario/stock-bajo` productos bajo stock minimo.
- `POST /api/inventario/movimiento` registra un movimiento de stock: `tipo` acepta `entrada`, `salida` o `ajuste` (en ajuste, `cantidad` es el nuevo stock).
- `GET /api/reportes/stock` reporte de stock actual.
- `GET /api/reportes/movimientos` reporte de movimientos (filtros: `fecha_desde`, `fecha_hasta`).
- `GET /api/reportes/exportar-stock` exporta el reporte de stock a CSV (solo administrador).
- `GET /api/reportes/exportar-movimientos` exporta el reporte de movimientos a CSV (solo administrador).
- `POST /api/inference/` sube una imagen de los productos de un estante y devuelve detecciones; registra automaticamente un movimiento de **entrada** (conteo) en el inventario y una sesion de camara. El campo `tipo_operacion` permite parametrizar `entrada` (default), `salida` o `conteo` para uso futuro.

## App movil

El frontend movil esta en `mobile/inventario_app`. La app apunta por defecto a `http://10.0.2.2:8001` (emulador Android); usa `--dart-define=API_BASE_URL=http://IP_LOCAL:8001` en un dispositivo real.