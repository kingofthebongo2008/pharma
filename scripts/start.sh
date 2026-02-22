#!/usr/bin/env bash
# Pharma - Full Start Script (Linux / macOS)
# Run from anywhere - script locates the project root automatically
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo ""
echo "======================================"
echo "  Pharma - Starting All Services"
echo "======================================"

# --- Helper: open a new terminal window ---
open_term() {
    local title="$1"
    local cmd="$2"

    if command -v gnome-terminal &>/dev/null; then
        gnome-terminal --title="$title" -- bash -c "$cmd; exec bash"
    elif command -v konsole &>/dev/null; then
        konsole --new-tab -p tabtitle="$title" -e bash -c "$cmd; exec bash" &
    elif command -v xfce4-terminal &>/dev/null; then
        xfce4-terminal --title="$title" -e "bash -c '$cmd; exec bash'" &
    elif command -v xterm &>/dev/null; then
        xterm -title "$title" -e bash -c "$cmd; exec bash" &
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        osascript -e "tell application \"Terminal\" to do script \"$cmd\""
    else
        echo "  [!] No terminal emulator found. Running '$title' in background."
        bash -c "$cmd" &> "$ROOT/logs/${title// /_}.log" &
        echo "      Log: $ROOT/logs/${title// /_}.log"
    fi
}

mkdir -p "$ROOT/logs"

# --- 1. PostgreSQL ---
echo ""
echo "[1/4] Starting PostgreSQL..."
docker-compose -f "$ROOT/docker/docker-compose.yml" up -d
echo "      Waiting for PostgreSQL to be ready..."
sleep 5

# --- 2. Backend ---
echo "[2/4] Opening backend terminal (F# / Falco on :5000)..."
open_term "Pharma Backend" "echo '--- Pharma Backend ---'; cd '$ROOT/src/Backend/Pharma.Api'; dotnet run"
echo "      Waiting for backend to start..."
sleep 6

# --- 3. Build Elm ---
echo "[3/4] Building Elm frontend..."
cd "$ROOT/src/Frontend"
elm make src/Main.elm --output=public/elm.js
cd "$ROOT"
echo "      Elm build successful."

# --- 4. Frontend server ---
echo "[4/4] Opening frontend terminal (static server on :8000)..."
open_term "Pharma Frontend" "echo '--- Pharma Frontend ---'; cd '$ROOT/src/Frontend'; python3 -m http.server 8000 --directory public"

# --- Done ---
echo ""
echo "======================================"
echo "  All services started!"
echo "======================================"
echo ""
echo "  Frontend : http://localhost:8000"
echo "  API      : http://localhost:5000/api/today/latest"
echo "  Health   : http://localhost:5000/api/health"
echo ""
