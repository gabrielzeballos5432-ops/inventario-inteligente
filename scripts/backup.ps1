# Backup de la base de datos de Inventario Inteligente (PostgreSQL local de Windows)
# Uso:
#   .\scripts\backup.ps1            -> crea un backup con fecha
#   .\scripts\backup.ps1 -Restore   -> restaura el backup mas reciente
#   .\scripts\backup.ps1 -Mantener 10 -> conserva los ultimos 10 backups (default: 7)

param(
    [switch]$Restore,
    [int]$Mantener = 7
)

$ErrorActionPreference = "Stop"

$PG_BIN = "C:\Program Files\PostgreSQL\18\bin"
$PG_DUMP = Join-Path $PG_BIN "pg_dump.exe"
$PSQL = Join-Path $PG_BIN "psql.exe"

$DB_USER   = "admin_user"
$DB_NAME   = "inventario_db"
$DB_HOST   = "localhost"
$DB_PORT   = "5432"
$BACKUP_DIR = Join-Path $PSScriptRoot "..\backups"
$BACKUP_DIR = [System.IO.Path]::GetFullPath($BACKUP_DIR)

if (-not (Test-Path $BACKUP_DIR)) {
    New-Item -ItemType Directory -Path $BACKUP_DIR | Out-Null
}

# Pedir la contrasena del usuario de la base de datos
$pass = Read-Host "Contrasena del usuario $DB_USER" -AsSecureString
$plain = [System.Runtime.InteropServices.Marshal]::PtrToStringUnicode(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass)
)
$env:PGPASSWORD = $plain

if ($Restore) {
    $archivo = Get-ChildItem -Path $BACKUP_DIR -Filter "*.sql" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $archivo) {
        Write-Error "No hay backups en $BACKUP_DIR"
        exit 1
    }
    $contenido = Get-Content -LiteralPath $archivo.FullName -Raw
    $contenido | & $PSQL -U $DB_USER -h $DB_HOST -p $DB_PORT -d $DB_NAME
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "Backup restaurado desde: $($archivo.Name)" -ForegroundColor Green
    exit 0
}

$nombre = "inventario_$(Get-Date -Format 'yyyyMMdd_HHmmss').sql"
$destino = Join-Path $BACKUP_DIR $nombre

& $PG_DUMP -U $DB_USER -h $DB_HOST -p $DB_PORT -d $DB_NAME --clean --if-exists > $destino
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