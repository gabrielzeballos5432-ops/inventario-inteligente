# Inventario Inteligente - Backend

Sistema de inventario inteligente con FastAPI, SQLAlchemy async, PostgreSQL y vision computacional con YOLO.

## Estructura

```text
backend/
  app/
    core/          Configuracion, seguridad y dependencias
    db/            Sesion, base declarativa y script SQL de referencia (inventario_db.sql)
    models/        Modelos SQLAlchemy con nombres de tablas singulares
    repositories/  Acceso a datos
    routers/       Endpoints por recurso
    schemas/       Schemas Pydantic de entrada/salida
    services/      Logica de negocio (auth, inventario, compras, ventas, sueldos, usuarios y seed)
    yolo/          Servicio de inferencia YOLO
    main.py        Aplicacion FastAPI
  alembic/         Migraciones de base de datos
  requirements.txt
```

## Pruebas unitarias

Desde `backend`, con el entorno virtual activado y las dependencias de
`requirements.txt` disponibles:

```powershell
python -m pip install -r requirements-dev.txt
python -m pytest -v
```

La suite de `tests/` utiliza pytest y `unittest.mock` para comprobar schemas,
reglas de ventas y compras, diferencias de caja y serializacion de roles.
Las corutinas se ejecutan con `asyncio.run`, sin requerir pytest-asyncio.
Las sesiones y repositorios se simulan: no se inicia FastAPI, no se conecta
PostgreSQL y no se carga el modelo YOLO. No reemplaza pruebas de integracion,
concurrencia, rollback ni evaluacion de la IA.

Para conservar un reporte procesable: `python -m pytest -v --junitxml=resultado_pytest.xml`.

## Base de datos

El esquema de referencia es `app/db/inventario_db.sql` (Salon de Belleza Zoom). Las migraciones Alembic parten del esquema inicial y aplican ventas, compras, sueldos, caja y contabilidad:

- `rol`, `usuario` (email unico en minusculas, `rol_id` FK)
- `categoria` (jerarquia via `padre_id`), `marca`, `proveedor`
- `producto` (`sku`, `codigo_barras`, `precio_compra`, `precio_venta`, `stock_minimo`)
- `inventario` (stock actual por producto)
- `sesion_camara`, `deteccion`
- `movimiento` con restriccion matematica de consistencia (`stock_resultante`)
- `moneda`, `compra` y `compra_detalle`, con cotizaciones historicas
- `registro_hora` y `liquidacion_sueldo` para asistencia y pago por hora/comision
- `cliente`, `sesion_caja` y `bono_sueldo`
- `gasto` y `pago_gasto` para gastos en moneda original, conversion a BOB y pagos parciales
- Las ventas tienen su tipo minorista/mayorista, cliente opcional, clave de idempotencia, anulacion auditada y costo historico por detalle.
- Todas las tablas y referencias usan nombres singulares. Las ganancias se calculan en reportes y no se almacenan como resultados contables duplicados.

## Ejecutar en local (entorno principal)

La base `inventario_db` vive en el PostgreSQL de Windows (puerto 5432), usuario `admin_user`. Verificar que el servicio `postgresql-x64-18` este corriendo; se puede visualizar con pgAdmin.

```powershell
cd backend
.\venv\Scripts\Activate
pip install -r requirements.txt
python -m alembic -c alembic.ini upgrade head
uvicorn app.main:app --reload --port 8000
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
- `GET /api/categorias/{id}` detalle de una categoria.
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
- `GET /api/reportes/valorizacion` valoriza el inventario a costo y a precio de venta.
- `GET /api/reportes/exportar-stock` exporta el reporte de stock (solo administrador). El parametro `formato` acepta `csv` (default) o `xlsx`.
- `GET /api/reportes/exportar-movimientos` exporta el reporte de movimientos (solo administrador). El parametro `formato` acepta `csv` (default) o `xlsx`.
- `POST /api/inference/` sube una imagen de los productos de un estante y devuelve detecciones; registra automaticamente un movimiento de **entrada** (conteo) en el inventario y una sesion de camara. El campo `tipo_operacion` permite parametrizar `entrada` (default), `salida` o `conteo` para uso futuro. Devuelve **503** si el modelo no esta disponible.
- `GET /api/monedas/` lista monedas activas; `POST /api/monedas/` crea una moneda y `PATCH /api/monedas/{codigo}/estado` la activa o desactiva (solo administrador). BOB y USD se cargan al iniciar.
- `POST /api/compras/` registra la factura, sus productos, el descuento y el porcentaje de manipulacion/envio (solo administrador). En la misma transaccion convierte el costo a BOB, actualiza el inventario y el costo de compra del producto, y registra movimientos de entrada. `GET /api/compras/` y `GET /api/compras/{id}` consultan compras.
- Las tasas de cambio se guardan por compra: `tipo_cambio_ext` representa unidades de la moneda de factura por USD y `tipo_cambio_bob` representa BOB por USD. La conversion es `(total_moneda / tipo_cambio_ext) * tipo_cambio_bob`; para USD, la primera tasa es 1, y para BOB ambas tasas deben coincidir. Los importes de factura se redondean segun `moneda.decimales`.
- `POST /api/sueldos/asistencias/entrada` y `/salida` permiten al vendedor registrar su jornada con fecha y hora de Cochabamba. El administrador puede registrar asistencias manuales, consultarlas y confirmarlas mediante las rutas `/api/sueldos/asistencias`.
- `POST /api/sueldos/liquidaciones` calcula el pago por horas confirmadas y la comision sobre ventas completadas registradas por ese vendedor en el período; guarda las tasas aplicadas. `GET /api/sueldos/liquidaciones` consulta liquidaciones y `POST /api/sueldos/liquidaciones/{id}/pagar` marca el pago (solo administrador). No se aceptan períodos superpuestos.
- `GET /api/caja/sesiones/actual` permite consultar la sesion del usuario; `POST /api/caja/sesiones/abrir` y `/cerrar` registran aperturas y cierres con conciliacion del efectivo esperado. Las ventas y pagos de gastos en efectivo se vinculan a la sesion abierta.
- `/api/clientes/` administra el catalogo de clientes para asociarlos opcionalmente a ventas.
- `/api/contabilidad/bonos` registra bonos y permite asignarlos a una liquidacion pendiente; el total se suma al importe de la liquidacion.
- `/api/contabilidad/gastos` registra servicios, alquiler, insumos de limpieza, mantenimiento y otros conceptos. Los pagos se registran por separado en `/api/contabilidad/gastos/{id}/pagos`, con soporte para pagos parciales y conversion a BOB. Un gasto sin pagos puede anularse con motivo y usuario responsable.
- `GET /api/contabilidad/reporte-financiero` calcula ventas netas, costo de ventas historico, ganancia bruta, gastos y utilidad estimada. La ganancia bruta se declara no disponible si hay lineas de venta sin costo historico; la utilidad neta es estimada antes de impuestos y cargos no registrados.

Las ventas aceptan los tipos `minorista` y `mayorista`, registran precios negociados por detalle y capturan el costo historico aplicado. Se puede enviar la cabecera `Idempotency-Key` para que los reintentos no creen ventas duplicadas. La anulacion administrativa conserva el registro y repone stock con movimientos compensatorios. La app movil todavia no incluye pantallas para caja, clientes, bonos ni gastos.

## Estado del servicio

- `GET /api/health` informa si la API responde y si el modelo de vision esta cargado (`yolo_disponible`). La app lo consulta para distinguir "el servidor esta caido" de "la IA todavia no esta entrenada".

## Estado del reconocimiento con IA

El reconocimiento depende de `app/models/best.pt`. **Ese archivo no se versiona** (pesos entrenados pesan decenas de MB). Mientras no exista:

- `POST /api/inference/` responde **503** y `GET /api/health` devuelve `yolo_disponible: false`.
- La app muestra una tarjeta de "Reconocimiento con IA pendiente" en lugar de un error generico.
- Todo el resto del sistema (catalogo, movimientos, reportes, valorizacion) funciona con normalidad: la IA es una capa opcional.

## App movil

El frontend movil esta en `mobile/inventario_app`. La app apunta por defecto a `http://10.0.2.2:8000` (emulador Android); usa `--dart-define=API_BASE_URL=http://IP_LOCAL:8000` en un dispositivo real.