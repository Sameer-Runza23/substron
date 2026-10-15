#!/bin/bash
# Substron 2050 Launcher for macOS (Apple Silicon M2)

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
ENGINE_DIR="$BASE_DIR/SubstronEngine"
APP_BUNDLE="$BASE_DIR/Substron.app"

echo "=========================================================="
echo "   ⚡ SUBSTRON 2050 - Autonomous Silicon Agent (macOS)    "
echo "=========================================================="

# 1. Start Ollama if not already running
if ! curl -s http://127.0.0.1:11434/api/version > /dev/null; then
    echo "[*] Launching local Ollama engine (Metal GPU)..."
    export HOME="$ENGINE_DIR"
    export OLLAMA_MODELS="$ENGINE_DIR/models"
    "$ENGINE_DIR/bin/ollama" serve > /tmp/ollama_substron.log 2>&1 &
    sleep 3
else
    echo "[✓] Local Ollama engine is active on Apple Metal GPU."
fi

# 2. Start Substron Engine Server if not running
if ! curl -s http://127.0.0.1:8000/api/status > /dev/null; then
    echo "[*] Launching Substron Engine Daemon & 2.6K Skills Router..."
    "$ENGINE_DIR/venv/bin/python3" "$ENGINE_DIR/server.py" > /tmp/substron_server.log 2>&1 &
    sleep 2
else
    echo "[✓] Substron Engine Server is active on port 8000."
fi

# 3. Launch Native Apple macOS App
echo "[*] Launching Native Apple macOS App: Substron.app..."
open "$APP_BUNDLE"

echo "[✓] Substron is now running on your desktop!"
