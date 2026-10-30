# Inventario Inteligente - Salon Zoom

Sistema de gestion de inventario para Salon de Belleza Zoom con reconocimiento de productos por camara.

## Stack

- **Backend:** FastAPI, SQLAlchemy async, Alembic, PostgreSQL
- **Vision computacional:** YOLOv8 (Ultralytics)
- **App:** Flutter (Android, Web/navegador y Windows/laptop; sin camara fuera del celular)
- **Base de datos:** PostgreSQL local de Windows (con pgAdmin); Docker queda como alternativa/respaldo

## Estructura del proyecto

```text
backend/                  API REST y modelo de datos
mobile/inventario_app/    Aplicacion movil Flutter
dataset/                  Imagenes y etiquetas para entrenar YOLO
scripts/                  Utilidades (deploy, backup)
backups/                  Respaldos SQL
```

## Requisitos

- PostgreSQL 18 local de Windows (servicio `postgresql-x64-18`) y pgAdmin (incluido con PostgreSQL)
- Flutter SDK (para la app movil)
- Python 3.12 (para el backend en local)
- Docker Desktop (opcional: solo como alternativa/respaldo)

## Ejecucion rapida

### 1. Base de datos (PostgreSQL local)

La base `inventario_db` vive en el PostgreSQL de Windows (puerto 5432), usuario `admin_user`. Se visualiza con pgAdmin (`C:\Program Files\PostgreSQL\18\pgAdmin 4\runtime\pgAdmin4.exe`).

### 2. Backend (local)

```powershell
cd backend
.\venv\Scripts\Activate
python -m alembic -c alembic.ini upgrade head
uvicorn app.main:app --reload --port 8000
```

La API queda en `http://localhost:8000` y la documentacion Swagger en `http://localhost:8000/docs`.

El esquema de base de datos de referencia es `backend/app/db/inventario_db.sql`; todas las tablas usan nombres singulares. Incluye catalogos, inventario, ventas minoristas y mayoristas, compras, sueldos, clientes, sesiones de caja, bonos y gastos con pagos parciales. Las ganancias se calculan en reportes a partir de las ventas, costos historicos, gastos y liquidaciones; no se guardan como tablas transaccionales. Antes de iniciar por primera vez o tras actualizar el backend, aplica las migraciones con `python -m alembic -c alembic.ini upgrade head`; el arranque crea tablas faltantes y siembra datos iniciales, pero no reemplaza las migraciones de una base existente.

### Registro de ventas

`POST /api/ventas/` registra una venta minorista o mayorista con sus detalles y pagos en una sola transaccion. El precio negociado se registra por linea y puede asociarse a oferta, combo o liquidacion. El backend calcula los totales, valida el stock, captura el costo historico y crea movimientos de salida; si una validacion falla, no guarda parcialmente la venta. Los pagos admiten efectivo y QR, y pueden dividirse entre ambos metodos. Se acepta `Idempotency-Key` para evitar ventas duplicadas por reintentos. `GET /api/ventas/` lista las ventas recientes y `POST /api/ventas/{id}/anular` permite anular una venta con motivo, registro auditado y movimientos de inventario compensatorios (solo administrador).

Ejemplo de cuerpo para `POST /api/ventas/`:

```json
{
  "detalles": [
    {
      "producto_id": 12,
      "cantidad": 2,
      "precio_unitario_negociado": "18.50",
      "tipo_promocion": "oferta"
    }
  ],
  "pagos": [
    {"metodo_pago": "qr", "monto": "37.00", "referencia": "op-123"}
  ]
}
```

### Compras y sueldos

`POST /api/compras/` registra una factura, aplica el descuento y el porcentaje de manipulacion/envio, convierte los importes a BOB con las tasas guardadas en la compra y actualiza stock/costo de compra con movimientos de entrada en una sola transaccion. `GET /api/compras/` consulta las compras y `GET /api/monedas/` lista las monedas activas.

La conversion se calcula como `total_bob = (total_moneda / tipo_cambio_ext) * tipo_cambio_bob`, donde `tipo_cambio_ext` son unidades de la moneda de factura por USD y `tipo_cambio_bob` son BOB por USD. Para USD, `tipo_cambio_ext` es 1; para BOB, ambas tasas deben coincidir.

Los vendedores registran su entrada y salida mediante `/api/sueldos/asistencias/entrada` y `/salida`. El administrador confirma las asistencias y crea liquidaciones por período en `/api/sueldos/liquidaciones`; el cálculo suma las horas confirmadas y la comisión sobre ventas completadas registradas por ese vendedor. Cada liquidacion conserva las tasas salariales aplicadas.

### Caja y contabilidad

- `/api/clientes/` permite consultar clientes activos; la creacion requiere administrador.
- `/api/caja/sesiones/actual`, `/api/caja/sesiones/abrir` y `/api/caja/sesiones/cerrar` permiten consultar y controlar la caja por usuario. Los pagos en efectivo de ventas se asocian a la sesion abierta; el cierre calcula el efectivo esperado restando pagos de gastos en efectivo.
- `/api/contabilidad/bonos` registra bonos de personal, que pueden asignarse a una liquidacion pendiente y quedan incluidos en su total.
- `/api/contabilidad/gastos` registra servicios, alquiler, limpieza, mantenimiento y otros gastos, conservando moneda, tasas de cambio y equivalente en BOB. `/api/contabilidad/gastos/{id}/pagos` admite pagos parciales; los pagos en efectivo requieren una sesion de caja abierta. Un gasto sin pagos puede anularse con motivo y auditoria; los gastos con pagos no se anulan para evitar borrar un movimiento de dinero.
- `/api/contabilidad/reporte-financiero?fecha_inicio=AAAA-MM-DD&fecha_fin=AAAA-MM-DD` calcula ventas netas, costo de ventas, ganancia bruta, gastos y utilidad operativa/neta estimada. Si existen lineas sin costo historico, la ganancia bruta se informa como no disponible y se indica el numero de lineas afectadas. La utilidad neta es una estimacion antes de impuestos y cargos no registrados.

### Navegacion de la app

Las pantallas se organizan por tarea, sin la antigua agrupacion de seis pestanas en "Gestion":

- **Operacion:** Ventas, Caja y Compras.
- **Inventario:** Productos, Movimientos y Deteccion.
- **Finanzas:** Gastos y Resultados.
- **Equipo:** Jornadas y sueldos, y Bonos.
- **Administracion:** Clientes, Usuarios, Categorias, Marcas y Proveedores.

El menu lateral queda fijo desde 1100 px de ancho; en movil y tablet se abre con el boton de menu. Las opciones administrativas solo aparecen para administradores. Los vendedores tienen acceso a ventas, caja, inventario y "Mi jornada". Las pantallas se cargan al abrirlas por primera vez y conservan sus formularios al cambiar de seccion.

Categorias, Marcas y Proveedores son destinos del mismo menu, igual que Clientes: reemplazan el contenido central y mantienen la barra y el menu principal, sin abrir rutas superpuestas. Solo los formularios de alta, edicion y confirmacion se muestran en dialogos.

**Movimientos** permite consultar el historial filtrado y registrar varios productos del mismo tipo. El formulario compartido con Productos usa buscador por codigo o nombre, una fila compacta por producto en escritorio y dos lineas en movil, con saldo actual y resultante de solo lectura. Enter en cantidad pasa al producto siguiente (o agrega una fila); Ctrl+Enter guarda el lote. El ajuste fija el stock final y admite cero. El pie permanece visible al abrir el teclado; durante el envio se bloquean la edicion, el cierre y los envios repetidos. Si el servidor rechaza la operacion, conserva las filas y muestra el detalle del error.

### 3. Aplicacion movil (Android)

```powershell
cd mobile\inventario_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

En un dispositivo real apunta a la IP del equipo donde corre el backend:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000
```

### 4. Aplicacion en Web (navegador)

No requiere herramientas adicionales; ideal para la laptop sin compilar nada nativo:

```powershell
cd mobile\inventario_app
flutter run -d chrome
```

La app abre en el navegador apuntando a `localhost:8000` (sin camara: la deteccion usa imagenes de disco).

### 5. Aplicacion en Windows (laptop)

Requiere Visual Studio con la carga "Desarrollo de escritorio con C++". La app corre en la laptop conectada al backend local (`localhost:8000` por defecto), sin el modulo de camara (la deteccion usa imagenes de disco):

```powershell
cd mobile\inventario_app
flutter run -d windows
```

## Scripts

### Desarrollo (todo en uno)

Verifica el PostgreSQL local y lanza el backend (venv) y la app:

```powershell
.\start-dev.ps1            # backend + app movil (emulador)
.\start-dev.ps1 -Web       # backend + app en el navegador
.\start-dev.ps1 -Windows   # backend + app en la laptop (requiere VS)
.\start-dev.ps1 -SinApp    # solo backend
.\start-dev.ps1 -Detener   # detiene el backend
```

### Alternativa con Docker (opcional / respaldo)

```powershell
docker compose up --build
```

Docker no es el servidor principal: la base vive en el PostgreSQL local. `docker-compose.yml` se conserva como alternativa (por ejemplo, si hay que montar todo en otra maquina).

### Despliegue en la laptop del salon (produccion, costo cero)

```powershell
Copy-Item .env.prod.example .env.prod   # configurar SECRET_KEY
.\scripts\deploy.ps1                    # despliega BD + backend
.\scripts\deploy.ps1 -Modelo .\best.pt  # incluye el modelo YOLO entrenado
.\scripts\deploy.ps1 -Restart           # reinicia
.\scripts\deploy.ps1 -Down              # detiene
```

### Backup de la base de datos

```powershell
.\scripts\backup.ps1            # crea un respaldo (pg_dump del PostgreSQL local)
.\scripts\backup.ps1 -Restore   # restaura el mas reciente
```

## Deteccion por camara (YOLO)

La deteccion requiere un modelo entrenado en `backend/app/models/best.pt`. Sin el modelo, el resto del sistema funciona normalmente y el endpoint de inferencia devuelve un error 503.

El mapeo entre las clases del modelo YOLO y los productos de la base de datos se configura en `backend/app/yolo/inference_service.py` (o mediante la variable `YOLO_CLASS_MAP`).

## Credenciales por defecto

| Rol           | Email              | Password       |
| ------------- | ------------------ | -------------- |
| Administrador | `admin@zoom.com` | `Admin12345` |

> Cambia la `SECRET_KEY` y la password del admin en produccion.
