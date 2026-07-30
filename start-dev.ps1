$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendPath = Join-Path $projectRoot "backend"
$mobilePath = Join-Path $projectRoot "mobile\inventario_app"

$backendCommand = @"
Set-Location '$backendPath'
if (Test-Path '.\venv\Scripts\Activate.ps1') {
    & '.\venv\Scripts\Activate.ps1'
}
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
"@

$flutterCommand = @"
Set-Location '$mobilePath'
flutter run
"@

Start-Process powershell -ArgumentList "-NoExit", "-Command", $backendCommand
Start-Process powershell -ArgumentList "-NoExit", "-Command", $flutterCommand

Write-Host "Backend: http://192.168.0.70:8000"
