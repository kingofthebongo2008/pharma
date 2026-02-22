# Pharma Dev Setup - Windows
# Run from D:\code\pharma

Write-Host "=== Pharma Dev Environment ===" -ForegroundColor Cyan

# 1. Start PostgreSQL
Write-Host "`n[1/3] Starting PostgreSQL..." -ForegroundColor Yellow
docker-compose -f docker/docker-compose.yml up -d
Start-Sleep -Seconds 3

# 2. Build Elm
Write-Host "`n[2/3] Building Elm frontend..." -ForegroundColor Yellow
Push-Location src/Frontend
elm make src/Main.elm --output=public/elm.js
Pop-Location

Write-Host "`nDone! Now start these in separate terminals:" -ForegroundColor Green
Write-Host "  Backend:  cd src/Backend/Pharma.Api && dotnet watch run" -ForegroundColor White
Write-Host "  Frontend: cd src/Frontend && python -m http.server 8000 --directory public" -ForegroundColor White
Write-Host "`nOpen http://localhost:8000 in your browser." -ForegroundColor Cyan
