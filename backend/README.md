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

## Lectura local de comprobantes de compra (PaddleOCR)

`POST /api/compras/leer-comprobante` recibe una imagen multipart en `imagen`
(hasta 12 MB y 25 megapixeles, solo administrador). No registra compras ni
movimientos: devuelve un borrador con texto, cantidades, costos, total y
advertencias. Sugiere productos solo por codigo o nombre exactos y unicos.
Las lineas del tipo `12,00 x 600 = 7.200` se interpretan automaticamente;
otros formatos o texto tapado pueden requerir ingreso manual. La moneda solo
se sugiere si aparece CLP/USD/BOB explicitamente; nunca se inventa una cotizacion.

Instalar desde `backend`, en un entorno aislado para no alterar FastAPI/YOLO:

```powershell
.\venv\Scripts\python.exe -m venv venv-ocr
.\venv-ocr\Scripts\python.exe -m pip install -r requirements-ocr.txt
```

La API ejecuta ese interprete en un proceso local, sin otro servidor y sin
enviar las imagenes a servicios externos. La primera lectura descarga modelos
publicos de PaddleOCR y necesita Internet; despues usa su cache local.
Opcionalmente `OCR_PYTHON` permite indicar otra ruta de interprete.
Una lectura por proceso de API a la vez; timeout del motor: 240 s.
La foto temporal se elimina al terminar. Si falla la instalacion o la lectura,
se informa el error y sigue disponible el formulario manual.
Se usan PP-OCRv5 mobile de deteccion y reconocimiento latino en CPU.
En Windows se desactiva MKL-DNN por incompatibilidad observada con el ejecutor
de Paddle. Los modelos viven en la cache del usuario que ejecuta la API.

## Ejecucion de pruebas

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

## Preparacion del reconocimiento visual

El entrenamiento es un proceso local, no otro servidor. La inferencia permanece
en la API FastAPI existente. Un entorno de entrenamiento separado puede vivir
en `backend/entrenamiento/.venv`; no sustituye `backend/venv` ni requiere
modificar las dependencias de la API.

Para los dos videos de la raiz, desde `backend`:

```powershell
.\venv\Scripts\python.exe entrenamiento\preparar_fotogramas.py --fps 2 --destino ..\dataset\revision_videos_20261030
```

El destino debe ser nuevo: el script no borra ni sobrescribe datasets anteriores.
Genera JPG, hojas de contacto y un manifiesto con video, fotograma y tiempo.
No asigna cajas automaticamente ni crea etiquetas vacias como si fueran fondos.
La anotacion debe encerrar solo el producto, no la mano ni el fondo.

Se propone comenzar con YOLOv8s (Small) y aumentacion durante el entrenamiento.
Primero se deben revisar etiquetas y separar escenas antes de aumentar datos;
fotogramas vecinos y sus variantes no deben cruzar entrenamiento y evaluacion.
Dos videos cortos no bastan para medir generalizacion a fondos nuevos: hacen
falta capturas independientes, incluidos productos simultaneos y fondos sin
productos. Los aumentos sinteticos no sustituyen esa evidencia.

Solo despues de validar el modelo se coloca el peso en `app/models/best.pt`
o se configura `YOLO_MODEL_PATH`. Es obligatorio comprobar `YOLO_CLASS_MAP`
contra los IDs reales de ambos productos; el mapeo de ejemplo de inferencia
no corresponde a estas dos clases. No se activa un modelo sin esa comprobacion.

### Entrenamiento local con GPU

Desde la raiz, sin tocar el entorno del servidor:

```powershell
backend\venv\Scripts\python.exe -m venv backend\entrenamiento\.venv
backend\entrenamiento\.venv\Scripts\python.exe -m pip install -r backend\entrenamiento\requirements.txt
backend\venv\Scripts\python.exe backend\entrenamiento\armar_dataset.py --origen dataset\revision_videos_20261030 --destino dataset\dos_productos_v3
backend\entrenamiento\.venv\Scripts\python.exe backend\entrenamiento\entrenar_modelo.py --datos dataset\dos_productos_v3\data.yaml --nombre dos_productos_s_20261030 --epocas 100
```

El ensamblado requiere `cajas_revisadas.json` junto al manifiesto de extraccion.
Sus cajas se expresan sobre miniaturas completas de 400 x 171 pixeles; deben
revisarse con las hojas generadas. En esta preparacion son aproximaciones visuales,
no una anotacion certificada. Los destinos y nombres de ejecucion deben ser nuevos.
El script no borra ejecuciones ni sustituye automaticamente el modelo de la API.

El muestreo actual produce 53 imagenes de entrenamiento, 11 de validacion y
11 de prueba; 8 se excluyen como separacion temporal. Son bloques de las mismas
grabaciones, no evidencia independiente de generalizacion. La aumentacion se
aplica durante entrenamiento, no a validacion ni prueba. Se guardan `best.pt`,
curvas y `evaluacion_preliminar.json` dentro de `dataset/runs/`.
No se registran entradas o salidas de inventario al entrenar o evaluar.

### Videos adicionales y evaluacion multientorno

Desde la raiz, con entornos ya preparados:

```powershell
backend\venv\Scripts\python.exe backend\entrenamiento\revisar_videos_nuevos.py --destino dataset\videos_nuevos_20261031
backend\venv\Scripts\python.exe backend\entrenamiento\armar_videos_nuevos.py --origen dataset\videos_nuevos_20261031 --anterior dataset\dos_productos_v3 --destino dataset\dos_productos_multientorno_v2
backend\entrenamiento\.venv\Scripts\python.exe backend\entrenamiento\entrenar_modelo.py --datos dataset\dos_productos_multientorno_v2\data.yaml --nombre dos_productos_multientorno_s_20261031 --epocas 120
backend\venv\Scripts\python.exe backend\entrenamiento\comprobar_predicciones.py --peso dataset\runs\dos_productos_multientorno_s_20261031\weights\best.pt --dataset dataset\dos_productos_multientorno_v2 --destino dataset\runs\dos_productos_multientorno_s_20261031\comprobacion_backend
```

La extraccion produce 418 fotogramas de 14 videos a 1 FPS. No todos estan
anotados: el ensamblador utiliza ocho muestras revisadas por video positivo y
todas las muestras de los dos videos confirmados sin productos objetivo.
Requiere `anotaciones_muestras.json` junto al manifiesto, con cajas locales
de las celdas de 300 pixeles de las hojas de contacto. Identifica clase 0 como
iluminador rectangular y clase 1 como sombra de envase curvo. Los videos de
estantes contienen ambos productos; el spray de fondo no se etiqueta.

La version revisada contiene 132 imagenes de entrenamiento, 24 de validacion
y 40 de prueba. Las grabaciones completas se asignan a una sola particion;
solo las 53 muestras antiguas de entrenamiento se reutilizan. Se comprueban
duplicados exactos entre particiones. La prueba comprende ocho escenas con
ambos productos y 32 fondos negativos; son fotogramas correlacionados, no
40 entornos independientes. No se entrenan ni aumentan esas imagenes.

La comprobacion en el entorno real del backend usa CPU y el umbral 0.5 de
la API. Compara clase y localizacion (IoU >= 0.5), con correspondencia uno
a uno; informa omisiones, detecciones sobrantes y falsas detecciones en
fondos. No sustituye una prueba con camara en el ambiente definitivo ni
habilita el registro de stock automaticamente.

## Base de datos

### Categorías de gasto

Los abonos de gastos de la app usan
`POST /api/contabilidad/gastos/{id}/pagos/mixto` con `pagos` (uno o dos
elementos, métodos efectivo/QR sin duplicados). Se valida el saldo total bajo
bloqueo del gasto y se guardan todos los componentes en un solo commit.
Solo efectivo exige caja abierta y afecta su conciliación. Se mantienen los
pagos históricos y el endpoint individual para compatibilidad.

`categoria_gasto` es un catálogo administrable: nombre único sin distinguir
mayúsculas, periodicidad (`sin_periodicidad`, `mensual`, `semanal`, `anual`),
tipo de importe (`fijo`, `variable`), monto habitual opcional en Bs y estado
activo. La periodicidad no determina si el importe es fijo: luz y agua
pueden tener importes distintos. Luz se propone mensual variable; agua, Wifi
y alquiler se proponen mensuales fijos,
sin inventar un importe inicial; todas estas opciones son editables.

Los endpoints `/api/contabilidad/categorias-gasto` (GET/POST) y
`/api/contabilidad/categorias-gasto/{id}` (PUT/DELETE) requieren administrador.
GET permite `incluir_inactivas=true`; DELETE da de baja y PUT permite reactivar.
La app oculta las inactivas. POST con el mismo nombre que una inactiva
reactiva su mismo ID y actualiza su configuración, sin duplicar la categoría.
La coincidencia ignora mayúsculas y espacios redundantes; no usa similitud
aproximada entre nombres. Un nombre ya activo se rechaza.
Una categoría inactiva no puede asignarse a nuevos gastos.

`GastoCreate` acepta `categoria_gasto_id`. El nombre elegido se guarda también
en `gasto.categoria` como referencia histórica: editar o desactivar el catálogo
no cambia los gastos anteriores. Se conserva la categoría textual antigua para
clientes anteriores, pero la app usa IDs. La migración `20261101_01` enlaza los
gastos existentes sin borrarlos. Ejecutar `python -m alembic upgrade head` antes
de utilizar el nuevo formulario.

No hay generación automática de gastos. La app sugiere el mes calendario,
la semana de lunes a domingo o el año calendario actual, con fechas editables.
Sin periodicidad no precarga fechas. El monto habitual también puede cambiarse
al registrar y solo se permite guardarlo en categorías de importe fijo.

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