# Pharma - Full Start Script (Windows)
# Run from anywhere - script locates the project root automatically

$Root = Split-Path -Parent $PSScriptRoot

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Pharma - Starting All Services" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

# --- 1. PostgreSQL ---
Write-Host ""
Write-Host "[1/4] Starting PostgreSQL..." -ForegroundColor Yellow
docker-compose -f "$Root\docker\docker-compose.yml" up -d
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to start PostgreSQL. Is Docker running?" -ForegroundColor Red
    exit 1
}

Write-Host "      Waiting for PostgreSQL to be ready..." -ForegroundColor DarkGray
Start-Sleep -Seconds 5

# --- 2. Backend ---
Write-Host "[2/4] Opening backend terminal (F# / Falco on :5000)..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", `
    "Write-Host '--- Pharma Backend ---' -ForegroundColor Cyan; Set-Location '$Root\src\Backend\Pharma.Api'; dotnet run"

Write-Host "      Waiting for backend to start..." -ForegroundColor DarkGray
Start-Sleep -Seconds 6

# --- 3. Build Elm ---
Write-Host "[3/4] Building Elm frontend..." -ForegroundColor Yellow
Push-Location "$Root\src\Frontend"
elm make src/Main.elm --output=public/elm.js
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Elm build failed. Is elm installed?" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location
Write-Host "      Elm build successful." -ForegroundColor DarkGray

# --- 4. Frontend server ---
Write-Host "[4/4] Opening frontend terminal (static server on :8000)..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", `
    "Write-Host '--- Pharma Frontend ---' -ForegroundColor Cyan; Set-Location '$Root\src\Frontend'; python -m http.server 8000 --directory public"

# --- Done ---
Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "  All services started!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Frontend : http://localhost:8000" -ForegroundColor White
Write-Host "  API      : http://localhost:5000/api/today/latest" -ForegroundColor White
Write-Host "  Health   : http://localhost:5000/api/health" -ForegroundColor White
Write-Host ""
