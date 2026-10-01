# AGENTS.md

Proyecto de grado: sistema de inventario para Salón de Belleza Zoom (FastAPI + PostgreSQL + Flutter + YOLOv8).
Todo el repo (código, comentarios, docs, commits) está **en español**; commits usan convención `feat:`/`fix:`/`ci:`.

## Arquitectura

- `backend/` — API FastAPI (async SQLAlchemy + Alembic). Entrypoint: `backend/app/main.py` (lifespan ejecuta `create_all` + seed al arrancar).
- `mobile/inventario_app/` — Flutter con **3 plataformas**: Android, Web (`flutter run -d chrome`) y Windows (`flutter run -d windows`).
- `backend/app/yolo/` — inferencia YOLOv8. Modelo `backend/app/models/best.pt` está gitignored (`*.pt`): sin él, `POST /api/inference/` devuelve 503 (esperado, S5–S6 pendientes).
- Docs académicas en `tecnico y original/` y `revision-sistematica/` — **gitignored**, no editar desde aquí.

## Entorno de desarrollo (solo Windows)

El entorno activo es **100% local**, no Docker:

- **BD principal**: servicio de Windows `postgresql-x64-18` (PostgreSQL 18) en `localhost:5432`, BD `inventario_db`, usuario `admin_user`/`admin_password` (ver `backend/.env.example`); esquema canónico en `backend/app/db/inventario_db.sql`. pgAdmin 4 viene con la instalación de PostgreSQL.
- **`docker-compose.yml` usa el MISMO puerto 5432** con credenciales distintas (`zoom_user`): **nunca** correr la BD de Docker junto con la local. Docker queda solo como alternativa/respaldo; `scripts/backup.ps1` usa `pg_dump` de Windows (`C:\Program Files\PostgreSQL\18\bin`), no Docker.
- Lanzador único: `.\start-dev.ps1` (verifica PG, arranca backend + app). Flags: `-Web` (navegador), `-Windows` (escritorio), `-SinApp`, `-Detener`.
- Backend en local: `cd backend; .\venv\Scripts\Activate; python -m alembic -c alembic.ini upgrade head; uvicorn app.main:app --reload --port 8001`. El arranque también crea tablas y siembra datos (roles, categorías, marcas, admin).
- **El backend va en el puerto 8001, NO 8000**: el 8000 lo ocupa Laravel Herd (PHP) del usuario, que lo necesita para otro proyecto. Si el 8001 aparece ocupado, buscar el proceso con `netstat -ano | findstr :8001`.

## Comandos de verificación

Backend **no tiene tests ni linter** (solo `requirements.txt`, sin ruff/mypy/pyproject). Verificación = levantar servidor y golpear endpoints:

```powershell
# login (creado por el seed)
POST http://localhost:8001/api/auth/login  {"email":"admin@zoom.com","password":"Admin12345"}
```

Flutter (barra: **0 errores**; hay ~27 issues info/warning preexistentes, el CI los tolera):

```powershell
cd mobile/inventario_app
flutter analyze --no-fatal-infos --no-fatal-warnings   # igual que CI
flutter test                                           # 1 widget test (login)
flutter build web                                      # compila limpio
```

Orden recomendado tras tocar la app: `flutter analyze` → `flutter test` → (si aplica) `flutter build web`.

## Peculiaridades de Flutter

- `pubspec.lock` está **gitignored** (poco común): siempre `flutter pub get` tras clonar.
- URL del API: `ApiConfig.baseUrl` decide en runtime (Android → `http://10.0.2.2:8001`, resto → `http://localhost:8001`); override con `--dart-define=API_BASE_URL=...`.
- Multiplataforma: la **cámara solo existe en Android/iOS**; web y escritorio usan selector de archivos (`kIsWeb`/`defaultTargetPlatform` en `detection_page.dart` y `shell_page.dart`).
- Importaciones condicionales — no romperlas:
  - `core/db/db_bootstrap.dart` (web, no-op) vs `db_bootstrap_io.dart` (desktop: sqflite FFI).
  - `core/services/local_db_service.dart` exporta `_web.dart` (memoria) o `_io.dart` (sqflite) según `dart.library.io`.
- `flutter run -d windows` requiere Visual Studio con carga "Desarrollo de escritorio con C++" (**no instalado** en esta máquina); `flutter run -d chrome` funciona sin nada extra.
- CI (`.github/workflows/build-mobile.yml`) analiza y compila APK en cambios de `mobile/`; tiene **Flutter 3.29 fijado** mientras el repo usa local 3.41.6 / `sdk: ^3.11.4` — verificar que el CI verde coincida antes de confiar en él.

## Backend — datos y migraciones

- Esquema de referencia: `backend/app/db/inventario_db.sql`. La única migración Alembic (`backend/alembic/versions/20260401_00_inventario_db.py`) debe reproducirlo exactamente: si cambia un modelo SQLAlchemy, actualizar **ambos** (SQL + migración).
- `POST /api/inference/` acepta el campo Form `tipo_operacion` (default `entrada`): el reconocimiento registra **entrada** de stock; salida es trabajo futuro.
- CORS acepta cualquier puerto local (`localhost`/`127.0.0.1`) vía `allow_origin_regex` en `main.py` (el servidor web de Flutter usa puertos aleatorios).
- Los `Decimal` de los schemas Pydantic salen en JSON como **string** (`"8.00"`): en Flutter parsear con `parseDouble` de `core/models/json_utils.dart` (nunca `as num`, truena en runtime y cae al catch "sin conexion").
- `dataset/` (imágenes YOLO) y `backups/` (SQL dumps) viven en la raíz; `dataset/` está gitignored.
