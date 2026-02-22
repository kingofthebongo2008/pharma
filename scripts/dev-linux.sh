#!/usr/bin/env bash
set -e

# Pharma Dev Setup - Linux/macOS
# Run from the pharma/ root directory

echo "=== Pharma Dev Environment ==="

# 1. Start PostgreSQL
echo -e "\n[1/3] Starting PostgreSQL..."
docker-compose -f docker/docker-compose.yml up -d
sleep 3

# 2. Build Elm
echo -e "\n[2/3] Building Elm frontend..."
cd src/Frontend
elm make src/Main.elm --output=public/elm.js
cd ../..

echo -e "\nDone! Now start these in separate terminals:"
echo "  Backend:  cd src/Backend/Pharma.Api && dotnet watch run"
echo "  Frontend: cd src/Frontend && python3 -m http.server 8000 --directory public"
echo -e "\nOpen http://localhost:8000 in your browser."
