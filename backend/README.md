# Inventario Inteligente

Proyecto base para un sistema inteligente de inventario con FastAPI, SQLAlchemy y vision computacional con YOLO.

## Que incluye esta base

- API REST para productos.
- Gestion inicial de stock por sucursal.
- Registro de detecciones desde imagen usando YOLO.
- Registro de detecciones desde imagen subida por app movil.
- Soporte para PostgreSQL mediante variables de entorno.
- App Flutter como frontend movil del proyecto.
- Script SQL de referencia en `inventario_db`.

## Estructura

```text
backend/
  ai/
  routes/
  services/
  database.py
  inventario_db
  main.py
  models.py
  requirements.txt
  schemas.py
mobile/
  inventario_app/
```

## Ejecutar

```powershell
cd backend
.\venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload
```

## Migraciones con Alembic

```powershell
cd backend
.\venv\Scripts\activate
python -m alembic -c alembic.ini upgrade head
```

Crear una nueva migracion:

```powershell
python -m alembic -c alembic.ini revision -m "descripcion_del_cambio"
```

## Configurar PostgreSQL

1. Crea una base llamada `inventario_db` en PostgreSQL.
2. Ejecuta el script SQL del archivo `inventario_db`.
3. Copia los valores de `.env.example` a tu entorno o define `DATABASE_URL`.

Ejemplo:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=inventario_db
DB_USER=postgres
DB_PASSWORD=postgres
```

## Endpoints base

- `GET /` estado general del sistema.
- `GET /salud` health check.
- `GET /productos/` lista productos.
- `POST /productos/` crea un producto.
- `PUT /productos/{id}` actualiza un producto.
- `POST /productos/{id}/stock` ajusta stock por sucursal.
- `GET /productos/resumen/general` resumen general.
- `POST /vision/detectar` detecta objetos desde una imagen y guarda el registro.
- `POST /vision/detectar-upload` detecta objetos desde una imagen subida por Flutter.
- `GET /vision/historial` historial de detecciones registradas.
- `GET /dashboard/resumen` resumen agregado para dashboard.

## App Flutter

La app movil esta en `mobile/inventario_app`.

Instalar dependencias:

```powershell
cd mobile\inventario_app
flutter pub get
```

Ejecutar en Android:

```powershell
flutter run --dart-define=API_BASE_URL=http://TU_IP_LOCAL:8000
```

Si usas emulador Android puedes dejar el valor por defecto `http://10.0.2.2:8000`.

## Ejemplo de deteccion

```json
{
  "image_path": "../dataset/images/val/WIN_20260312_19_13_42_Pro.jpg",
  "sucursal_id": 1,
  "producto_id": null,
  "confidence_threshold": 0.35
}
```

## Siguientes pasos recomendados

1. Alinear los modelos SQLAlchemy con todo el esquema real de `inventario_db`.
2. Entrenar un modelo propio para detectar tus productos reales.
3. Agregar autenticacion y refinamiento visual de la app Flutter.
