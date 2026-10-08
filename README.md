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

El esquema de base de datos de referencia es `backend/app/db/inventario_db.sql`. Al iniciar se aplican las migraciones Alembic y se siembran datos iniciales (roles, categorias, marcas y el usuario `admin@zoom.com` / `Admin12345`).

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
