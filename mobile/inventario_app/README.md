# inventario_app

Aplicacion Flutter del sistema de inventario inteligente para Salon de Belleza Zoom. Corre en **Android (celular/emulador)**, **Web (navegador)** y **Windows (laptop)**.

## Modulos

- **Login:** autenticacion con email y password (roles administrador / vendedor).
- **Dashboard:** resumen de productos y alertas de stock bajo.
- **Productos:** catalogo con stock, busqueda por nombre, filtro por categoria, registro/edicion/baja de productos y configuracion de stock minimo (solo administrador).
- **Movimiento:** registro manual de entradas, salidas y ajustes de inventario.
- **Reportes:** stock actual, movimientos y exportacion a CSV.
- **Deteccion:** captura de imagen para reconocimiento de productos (requiere el modelo YOLO en el backend). En Windows no hay camara: se selecciona una imagen de disco en su lugar.
- **Historial:** trazabilidad de movimientos de inventario.
- **Usuarios:** gestion de cuentas y roles (solo administrador).

## Ejecutar en Android

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

En un dispositivo real apunta a la IP del backend:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000
```

La variable `API_BASE_URL` es opcional en el emulador (`10.0.2.2:8000` es el default), en Windows y en web (`localhost:8000` es el default).

## Ejecutar en Web (navegador)

No requiere herramientas adicionales (sin Visual Studio). El backend debe estar corriendo en `localhost:8000`:

```powershell
flutter pub get
flutter run -d chrome
```

O sin abrir Chrome (servidor web propio, puerto aleatorio):

```powershell
flutter run -d web-server
```

Compilar la version estatica (quedan archivos listos para servir):

```powershell
flutter build web
# salida: build\web  -> servirla con cualquier servidor estatico
```

Diferencias respecto a Android:

- **Sin camara:** el modulo de deteccion permite seleccionar una imagen de disco.
- La BD local offline vive solo en memoria (en web la sesion siempre esta en linea).
- El backend acepta cualquier puerto local via CORS (`localhost`/`127.0.0.1`).

## Ejecutar en Windows (laptop)

Requisito previo: **Visual Studio** con la carga "Desarrollo de escritorio con C++" (lo pide Flutter; se instala desde https://visualstudio.microsoft.com/downloads/).

```powershell
flutter pub get
flutter run -d windows
```

La app se conecta a `http://localhost:8000` por defecto (el backend debe estar corriendo en la misma laptop). Si el backend esta en otro equipo, usa `--dart-define=API_BASE_URL=http://IP_DEL_BACKEND:8000`.

Diferencias respecto a Android:

- **Sin camara:** el modulo de deteccion permite seleccionar una imagen existente (el modulo de captura con camara queda solo para el celular).
- La BD local offline (sqflite) funciona via FFI con el SQLite incluido (`sqlite3_flutter_libs`).

## Compilar APK de distribucion

```powershell
flutter build apk --release --dart-define=API_BASE_URL=http://IP_DEL_BACKEND:8000
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`.

## Compilar ejecutable de Windows

```powershell
flutter build windows --release --dart-define=API_BASE_URL=http://IP_DEL_BACKEND:8000
```

El ejecutable queda en `build\windows\x64\runner\Release\inventario_app.exe`.