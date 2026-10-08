# Script de desarrollo local: inicia backend (venv) y app (Android, Windows o Web).
# Requisitos: PostgreSQL local de Windows corriendo, Flutter SDK, venv en backend.
# Uso:
#   .\start-dev.ps1            -> inicia backend + app movil (emulador Android)
#   .\start-dev.ps1 -Web       -> inicia backend + app en el navegador (Flutter web)
#   .\start-dev.ps1 -Windows   -> inicia backend + app en la laptop (Flutter Windows)
#   .\start-dev.ps1 -SinApp    -> solo backend
#   .\start-dev.ps1 -Detener   -> cierra el backend

param(
    [switch]$SinApp,
    [switch]$Web,
    [switch]$Windows,
    [switch]$Detener
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendPath = Join-Path $projectRoot "backend"
$mobilePath = Join-Path $projectRoot "mobile\inventario_app"

if ($Detener) {
    Write-Host "Cerrando el backend local..." -ForegroundColor Yellow
    $procs = Get-CimInstance Win32_Process -Filter "Name='python.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match "uvicorn" }
    if ($procs) {
        $procs | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Write-Host "Backend detenido." -ForegroundColor Green
    } else {
        Write-Host "No hay backend corriendo." -ForegroundColor Yellow
    }
    exit 0
}

# Verificar que PostgreSQL local este disponible
Write-Host "== Verificando PostgreSQL local ==" -ForegroundColor Cyan
$pgReady = $false
try {
    $tcp = Test-NetConnection -ComputerName localhost -Port 5432 -InformationLevel Quiet -WarningAction SilentlyContinue
    $pgReady = $tcp -eq $true
} catch {
    $pgReady = $false
}
if (-not $pgReady) {
    Write-Host "PostgreSQL local no esta respondiendo en el puerto 5432." -ForegroundColor Red
    Write-Host "Verifica que el servicio 'postgresql-x64-18' este corriendo (Servicios de Windows)." -ForegroundColor Yellow
    exit 1
}
Write-Host "PostgreSQL local listo." -ForegroundColor Green

# Iniciar el backend en una ventana nueva
Write-Host "== Iniciando backend ==" -ForegroundColor Cyan
$backendCommand = @"
Set-Location '$backendPath'
if (Test-Path '.\venv\Scripts\Activate.ps1') {
    & '.\venv\Scripts\Activate.ps1'
}
python -m alembic -c alembic.ini upgrade head
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
"@
Start-Process powershell -ArgumentList "-NoExit", "-Command", $backendCommand

# Esperar a que el backend responda
Write-Host "Esperando a que el backend este disponible..." -ForegroundColor Yellow
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 1
    try {
        $null = Invoke-RestMethod -Uri "http://localhost:8000/api/auth/login" -Method Post -ContentType "application/json" -Body '{"email":"admin@zoom.com","password":"Admin12345"}' -TimeoutSec 2
        $ready = $true
        break
    } catch {
        # aun no esta listo
    }
}

if (-not $ready) {
    Write-Host "El backend aun no responde. Revisa la ventana del backend para errores." -ForegroundColor Yellow
} else {
    Write-Host "Backend listo en http://localhost:8000" -ForegroundColor Green
    Write-Host "Swagger: http://localhost:8000/docs" -ForegroundColor Green
}

# Iniciar la app (opcional)
if (-not $SinApp) {
    if ($Windows) {
        Write-Host "== Iniciando app Windows (laptop) ==" -ForegroundColor Cyan
        $flutterCommand = @"
Set-Location '$mobilePath'
flutter run -d windows
"@
    } elseif ($Web) {
        Write-Host "== Iniciando app Web (navegador) ==" -ForegroundColor Cyan
        $flutterCommand = @"
Set-Location '$mobilePath'
flutter run -d chrome
"@
    } else {
        Write-Host "== Iniciando app movil (emulador Android) ==" -ForegroundColor Cyan
        $flutterCommand = @"
Set-Location '$mobilePath'
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
"@
    }
    Start-Process powershell -ArgumentList "-NoExit", "-Command", $flutterCommand
}

Write-Host ""
Write-Host "=== DESARROLLO INICIADO (local) ===" -ForegroundColor Green
Write-Host "PostgreSQL local:  localhost:5432 (inventario_db)"
Write-Host "Backend:           http://localhost:8000  |  /docs"
if ($Windows) {
    Write-Host "App:               Windows (localhost:8000)"
} elseif ($Web) {
    Write-Host "App:               Navegador (localhost:8000)"
} else {
    Write-Host "App movil:         emulador Android (10.0.2.2:8000)"
}
Write-Host ""
Write-Host "Para cerrar el backend: .\start-dev.ps1 -Detener" -ForegroundColor Cyan