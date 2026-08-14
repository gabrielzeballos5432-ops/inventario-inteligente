# Despliegue productivo del sistema en la laptop del salon (costo cero).
# Requisitos: Docker Desktop instalado y Docker daemon corriendo.
# Uso:
#   .\scripts\deploy-salud.ps1            -> despliega el sistema
#   .\scripts\deploy-salud.ps1 -Modelo .\best.pt  -> copia el modelo YOLO y despliega
#   .\scripts\deploy-salud.ps1 -Restart   -> reinicia los contenedores
#   .\scripts\deploy-salud.ps1 -Down      -> detiene y elimina los contenedores

param(
    [string]$Modelo = "",
    [switch]$Restart,
    [switch]$Down
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $projectRoot ".env.prod"

if (-not (Test-Path $envFile)) {
    Copy-Item (Join-Path $projectRoot ".env.prod.example") $envFile
    Write-Host "Cree .env.prod a partir de .env.prod.example. EDITALO y cambia la SECRET_KEY." -ForegroundColor Yellow
}

if ($Modelo) {
    $destino = Join-Path $projectRoot "backend\app\models\best.pt"
    Copy-Item -LiteralPath $Modelo -Destination $destino -Force
    Write-Host "Modelo copiado a $destino" -ForegroundColor Green
}

if ($Down) {
    docker compose -f "$projectRoot\docker-compose.prod.yml" --env-file $envFile down
    Write-Host "Sistema detenido." -ForegroundColor Green
    exit 0
}

if ($Restart) {
    docker compose -f "$projectRoot\docker-compose.prod.yml" --env-file $envFile restart
    Write-Host "Sistema reiniciado." -ForegroundColor Green
    exit 0
}

docker compose -f "$projectRoot\docker-compose.prod.yml" --env-file $envFile up -d --build

# Obtener la IP local de la laptop para que los celulares se conecten
$ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } |
    Select-Object -ExpandProperty IPAddress

Write-Host ""
Write-Host "=== SISTEMA DESPLEGADO ===" -ForegroundColor Green
Write-Host "API local:      http://localhost:8001"
Write-Host "Docs Swagger:   http://localhost:8001/docs"
if ($ips) {
    Write-Host "API en la red:  http://$($ips[0]):8001  (usar esta IP en la app movil)"
}
Write-Host ""
Write-Host "Para la app movil usa:"
Write-Host "  flutter run --dart-define=API_BASE_URL=http://IP_DE_LA_LAPTOP:8001" -ForegroundColor Cyan