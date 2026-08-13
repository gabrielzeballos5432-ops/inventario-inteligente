# Backup de la base de datos de Inventario Inteligente (Docker)
# Uso:
#   .\scripts\backup.ps1            -> crea un backup con fecha
#   .\scripts\backup.ps1 -Restore   -> restaura el backup mas reciente
#   .\scripts\backup.ps1 -Mantener 10 -> conserva los ultimos 10 backups (default: 7)

param(
    [switch]$Restore,
    [int]$Mantener = 7
)

$ErrorActionPreference = "Stop"

$CONTAINER = "inventario_db"
$DB_USER   = "zoom_user"
$DB_NAME   = "inventario_zoom"
$BACKUP_DIR = Join-Path $PSScriptRoot "..\backups"
$BACKUP_DIR = [System.IO.Path]::GetFullPath($BACKUP_DIR)

if (-not (Test-Path $BACKUP_DIR)) {
    New-Item -ItemType Directory -Path $BACKUP_DIR | Out-Null
}

if ($Restore) {
    $archivo = Get-ChildItem -Path $BACKUP_DIR -Filter "*.sql" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $archivo) {
        Write-Error "No hay backups en $BACKUP_DIR"
        exit 1
    }
    $contenido = Get-Content -LiteralPath $archivo.FullName -Raw
    $contenido = $contenido | & docker exec -i $CONTAINER psql -U $DB_USER -d $DB_NAME
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "Backup restaurado desde: $($archivo.Name)" -ForegroundColor Green
    exit 0
}

$nombre = "inventario_$(Get-Date -Format 'yyyyMMdd_HHmmss').sql"
$destino = Join-Path $BACKUP_DIR $nombre

docker exec $CONTAINER pg_dump -U $DB_USER -d $DB_NAME --clean --if-exists > $destino
if ($LASTEXITCODE -ne 0) {
    Write-Error "Error al generar el backup"
    exit $LASTEXITCODE
}

Write-Host "Backup creado: $destino" -ForegroundColor Green

$viejos = Get-ChildItem -Path $BACKUP_DIR -Filter "*.sql" | Sort-Object LastWriteTime -Descending | Select-Object -Skip $Mantener
foreach ($viejo in $viejos) {
    Remove-Item -LiteralPath $viejo.FullName -Force
    Write-Host "Eliminado backup antiguo: $($viejo.Name)" -ForegroundColor Yellow
}