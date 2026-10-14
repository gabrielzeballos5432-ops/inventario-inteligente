# AGENTS.md

Proyecto de grado: sistema de inventario para Salón de Belleza Zoom (FastAPI + PostgreSQL + Flutter + YOLOv8).
Todo el repo (código, comentarios, docs, commits) está **en español**; commits usan convención `feat:`/`fix:`/`ci:`.

## Arquitectura

- `backend/` — API FastAPI (async SQLAlchemy + Alembic). Entrypoint: `backend/app/main.py` (lifespan ejecuta `create_all` + seed al arrancar).
- `mobile/inventario_app/` — Flutter con **3 plataformas**: Android, Web (`flutter run -d chrome`) y Windows (`flutter run -d windows`).
- `backend/app/yolo/` — inferencia YOLOv8. Modelo `backend/app/models/best.pt` está gitignored (`*.pt`): sin él, `POST /api/inference/` devuelve 503 y `GET /api/health` responde `yolo_disponible: false` (esperado, S5–S6 pendientes). `InferenceService` es un singleton con carga perezosa.
- `backend/app/routers/reportes.py` — reportes y exportación real a **CSV y XLSX** (`openpyxl`), no CSV crudo. `/valorizacion` devuelve el inventario valorado a costo y a venta.
- Docs académicas en `tecnico y original/` y `revision-sistematica/` — **gitignored**, no editar desde aquí.
- `scripts/generar_*.py` — generadores de los 16 diagramas UML (PlantUML). Están **gitignored**: son material de trabajo local, no código del sistema. Se regeneran con `python scripts/generar_dcc.py` (etc.), requieren `plantuml.jar` + Java.

## Entorno de desarrollo (solo Windows)

El entorno activo es **100% local**, no Docker:

- **BD principal**: servicio de Windows `postgresql-x64-18` (PostgreSQL 18) en `localhost:5432`, BD `inventario_db`, usuario `admin_user`/`admin_password` (ver `backend/.env.example`); esquema canónico en `backend/app/db/inventario_db.sql`. pgAdmin 4 viene con la instalación de PostgreSQL.
- **`docker-compose.yml` usa el MISMO puerto 5432** con credenciales distintas (`zoom_user`): **nunca** correr la BD de Docker junto con la local. Docker queda solo como alternativa/respaldo; `scripts/backup.ps1` usa `pg_dump` de Windows (`C:\Program Files\PostgreSQL\18\bin`), no Docker.
- Lanzador único: `.\start-dev.ps1` (verifica PG, arranca backend + app). Flags: `-Web` (navegador), `-Windows` (escritorio), `-SinApp`, `-Detener`.
- Backend en local: `cd backend; .\venv\Scripts\Activate; python -m alembic -c alembic.ini upgrade head; uvicorn app.main:app --reload --port 8000`. El arranque también crea tablas y siembra datos (roles, categorías, marcas, admin). Para **celular físico** hace falta `--host 0.0.0.0` (si no, solo escucha en 127.0.0.1 y el celular no conecta).
- **El backend va en el puerto 8000** (puerto estándar de FastAPI). Si aparece ocupado, casi siempre es otro servidor local (por ejemplo Laravel Herd): identificar el proceso con `netstat -ano | findstr :8000`. Para no detener ese servicio, se puede levantar el backend en otro puerto y usar `--dart-define=API_BASE_URL=http://10.0.2.2:<PUERTO>` en la app.

## Comandos de verificación

Backend **no tiene tests ni linter** (solo `requirements.txt`, sin ruff/mypy/pyproject). Verificación = levantar servidor y golpear endpoints:

```powershell
# login (creado por el seed)
POST http://localhost:8000/api/auth/login  {"email":"admin@zoom.com","password":"Admin12345"}
```

Flutter (barra: **0 errores**; hay ~27 issues info/warning preexistentes, el CI los tolera):

```powershell
cd mobile/inventario_app
flutter analyze --no-fatal-infos --no-fatal-warnings   # igual que CI
flutter test                                           # 4 tests (3 de modelo + 1 widget de login)
flutter build web                                      # compila limpio
```

Orden recomendado tras tocar la app: `flutter analyze` → `flutter test` → (si aplica) `flutter build web`.

## Peculiaridades de Flutter

- `pubspec.lock` está **gitignored** (poco común): siempre `flutter pub get` tras clonar.
- URL del API (`ApiConfig.baseUrl`), por prioridad: 1) valor guardado en `SharedPreferences` (`api_base_url`) desde el diálogo **"Configurar servidor"** (icono servidor en la barra superior y en el login) — sirve para cambiar la IP del PC **sin recompilar**; 2) `--dart-define=API_BASE_URL=...`; 3) default por plataforma (Android → `http://10.0.2.2:8000`, resto → `http://localhost:8000`).
- **Celular físico (no emulador)**: `10.0.2.2` no existe fuera del emulador. La PC usa IP fija **192.168.100.43** (DHCP deshabilitado en el adaptador Wi-Fi, `netsh interface ipv4 set address ... static`), el backend debe correr con `--host 0.0.0.0 --port 8000`, y el APK se compila con `--dart-define=API_BASE_URL=http://192.168.100.43:8000`. Si algún día cambia la IP, no hay que recompilar: se cambia desde "Configurar servidor" en la app.
- Multiplataforma: la **cámara solo existe en Android/iOS**; web y escritorio usan selector de archivos (`kIsWeb`/`defaultTargetPlatform` en `detection_page.dart` y `shell_page.dart`).
- Importaciones condicionales — no romperlas:
  - `core/db/db_bootstrap.dart` (web, no-op) vs `db_bootstrap_io.dart` (desktop: sqflite FFI).
  - `core/services/local_db_service.dart` exporta `_web.dart` (memoria) o `_io.dart` (sqflite) según `dart.library.io`.
  - `core/utils/descarga_reporte.dart` exporta `_web.dart` (descarga por `<a download>`) o `_io.dart` (`path_provider` + `share_plus`) según `dart.library.io`.
- Plugins con código nativo: `mobile_scanner` (escáner de código de barras), `permission_handler` (permiso CAMERA), `share_plus` + `path_provider` (descargar y compartir el reporte exportado). El escáner **solo funciona en Android/iOS**: en web/escritorio el botón debe seguir ofreciendo el selector de archivos.
- AndroidManifest: el permiso `CAMERA` está declarado y `android.hardware.camera` va con `required="false"` para no romper la instalación en dispositivos sin cámara.
- `flutter run -d windows` requiere Visual Studio con carga "Desarrollo de escritorio con C++" (**no instalado** en esta máquina); `flutter run -d chrome` funciona sin nada extra.
- CI (`.github/workflows/build-mobile.yml`) analiza y compila APK en cambios de `mobile/`; tiene **Flutter 3.29 fijado** mientras el repo usa local 3.41.6 / `sdk: ^3.11.4` — verificar que el CI verde coincida antes de confiar en él.

## Backend — datos y migraciones

- Esquema de referencia: `backend/app/db/inventario_db.sql`. La única migración Alembic (`backend/alembic/versions/20260401_00_inventario_db.py`) debe reproducirlo exactamente: si cambia un modelo SQLAlchemy, actualizar **ambos** (SQL + migración).
- `POST /api/inference/` acepta el campo Form `tipo_operacion` (default `entrada`): el reconocimiento registra **entrada** de stock; salida es trabajo futuro.
- `GET /api/health` responde `yolo_disponible`. Es la forma de distinguir "API caída" de "IA sin entrenar": el 503 de `/api/inference/` **no es un error de red** y la app lo muestra como "IA pendiente" (`ApiException` en `core/providers/inventario_provider.dart`), nunca como "sin conexión".
- CORS acepta cualquier puerto local (`localhost`/`127.0.0.1`) vía `allow_origin_regex` en `main.py` (el servidor web de Flutter usa puertos aleatorios).
- Los `Decimal` de los schemas Pydantic salen en JSON como **string** (`"8.00"`): en Flutter parsear con `parseDouble` de `core/models/json_utils.dart` (nunca `as num`, truena en runtime y cae al catch "sin conexion").
- `dataset/` (imágenes YOLO) y `backups/` (SQL dumps) viven en la raíz; ambos están gitignored.

## Qué se versiona y qué no

El repositorio lleva **solo el código del sistema**: `mobile/` (app), `backend/` (API), `scripts/*.ps1` (operación: backup, deploy, `start-dev.ps1`), CI y docker-compose.

Quedan fuera (`.gitignore`, material de trabajo local): documentos del proyecto de grado (`tecnico y original/`, `revision-sistematica/`), generadores de diagramas UML (`scripts/generar_*.py`), hojas de cálculo y documentos de Office (`*.xlsx`, `*.docx`, `*.csv`), fuentes PlantUML (`*.puml`), pesos del modelo (`*.pt`) y resultados de entrenamiento (`runs/`).

Excepción deliberada: `README.md` y `AGENTS.md` **sí** se versionan (regla `!README.md` / `!AGENTS.md` en `.gitignore`), porque son la documentación del código. Si agregas un documento nuevo de trabajo, no lo versiona — esa es la intención.
