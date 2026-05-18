#!/usr/bin/env bash
set -euo pipefail

# Start NeurX backend and Qt application with local LLM model

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Backend configuration
export PORT=${PORT:-18080}
export NEURX_BACKEND_MODEL=${NEURX_BACKEND_MODEL:-gpt_large}

echo "Starting NeurX app with local LLM backend..."
echo "  Root: ${ROOT_DIR}"
echo "  Backend port: ${PORT}"

# Start backend in background
(
  cd "${SCRIPT_DIR}/web/backend"
  node server.mjs
) &
BACKEND_PID=$!
trap "kill $BACKEND_PID 2>/dev/null || true" EXIT

# Wait for backend to start
sleep 2

# Check if backend is running
if ! curl -s http://127.0.0.1:${PORT}/neurx/health >/dev/null 2>&1; then
  echo "Error: backend failed to start on port ${PORT}"
  kill $BACKEND_PID 2>/dev/null || true
  exit 1
fi

echo "Backend started (PID: $BACKEND_PID)"

# Configure Qt app to use local LLM backend
export NEURX_LLM_ENABLED=1
export NEURX_LLM_BACKEND=openai
export NEURX_LLM_BASE_URL=http://127.0.0.1:${PORT}
export NEURX_LLM_MODEL=gpt_large
export NEURX_LLM_CHAT_PATH=/neurx/api/chat

# Build Qt app if needed
if [ ! -f "${SCRIPT_DIR}/build/neurx_app" ] || [ ! -f "${SCRIPT_DIR}/build/CMakeCache.txt" ]; then
  echo "Building Qt application..."
  cmake -S "${SCRIPT_DIR}" -B "${SCRIPT_DIR}/build" -DCMAKE_BUILD_TYPE=Release
  cmake --build "${SCRIPT_DIR}/build" -j$(nproc)
fi

echo "Launching Qt application..."
echo "  LLM Backend: ${NEURX_LLM_BASE_URL}${NEURX_LLM_CHAT_PATH}"
echo "  Model: ${NEURX_LLM_MODEL}"

# Run Qt app
"${SCRIPT_DIR}/build/neurx_app"
