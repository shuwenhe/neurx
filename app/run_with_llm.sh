#!/usr/bin/env bash
set -euo pipefail

# Start NeurX backend and Qt application with local LLM model

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${APP_DIR}/.." && pwd)"
BUILD_DIR="${APP_DIR}/build"
APP_BINARY="${ROOT_DIR}/bin/linux-x86_64/neurx_app"

# Backend configuration
export PORT=${PORT:-18080}
export NEURX_BACKEND_MODEL=${NEURX_BACKEND_MODEL:-gpt_large}
export NEURX_BACKEND_CHECKPOINT_ROOT=${NEURX_BACKEND_CHECKPOINT_ROOT:-"${ROOT_DIR}/artifacts/checkpoints"}

LATEST_CHECKPOINT_FILE="${NEURX_BACKEND_CHECKPOINT_FILE:-}"
if [ -z "${LATEST_CHECKPOINT_FILE}" ] && [ -d "${NEURX_BACKEND_CHECKPOINT_ROOT}" ]; then
  LATEST_CHECKPOINT_FILE="$(find "${NEURX_BACKEND_CHECKPOINT_ROOT}" -type f -name '*.neurx' 2>/dev/null | sort | tail -n 1 || true)"
fi
export NEURX_BACKEND_CHECKPOINT_FILE="${LATEST_CHECKPOINT_FILE}"

if [ -n "${NEURX_BACKEND_CHECKPOINT_FILE}" ] && [ -z "${NEURX_BACKEND_MODEL_OVERRIDE:-}" ]; then
  NEURX_BACKEND_MODEL="$(basename "${NEURX_BACKEND_CHECKPOINT_FILE}" .neurx)"
  export NEURX_BACKEND_MODEL
fi

echo "Starting NeurX app with local LLM backend..."
echo "  Root: ${ROOT_DIR}"
echo "  Backend port: ${PORT}"

BACKEND_PID=""
HEALTH_URL="http://127.0.0.1:${PORT}/neurx/health"

# Reuse an already-running backend if health probe succeeds.
HEALTH_JSON="$(curl -s "${HEALTH_URL}" 2>/dev/null || true)"
if [ -n "${HEALTH_JSON}" ]; then
  if printf '%s' "${HEALTH_JSON}" | grep -q '"backend":"s-gateway"'; then
    echo "S backend already running on port ${PORT}; reusing existing process."
  else
    echo "Error: port ${PORT} is occupied by a non-S backend."
    echo "Health payload: ${HEALTH_JSON}"
    echo "Please stop the old backend or set PORT to another value."
    exit 1
  fi
else
  (
    cd "${APP_DIR}/web/backend"
    bash ./http_server.sh
  ) &
  BACKEND_PID=$!
  trap '[ -n "${BACKEND_PID}" ] && kill "${BACKEND_PID}" 2>/dev/null || true' EXIT

  sleep 2

  if ! kill -0 "${BACKEND_PID}" >/dev/null 2>&1; then
    echo "Error: backend process exited during startup (PID: ${BACKEND_PID})"
    exit 1
  fi

  if ! curl -s "${HEALTH_URL}" >/dev/null 2>&1; then
    echo "Error: backend failed to start on port ${PORT}"
    kill "${BACKEND_PID}" 2>/dev/null || true
    exit 1
  fi

  echo "Backend started (PID: ${BACKEND_PID})"
fi

# Configure Qt app to use local LLM backend
export NEURX_LLM_ENABLED=1
export NEURX_LLM_BACKEND=openai
export NEURX_LLM_BASE_URL=http://127.0.0.1:${PORT}
export NEURX_LLM_MODEL="${NEURX_LLM_MODEL:-${NEURX_BACKEND_MODEL}}"
export NEURX_LLM_CHAT_PATH=/neurx/api/chat

# Build Qt app if needed
if [ ! -f "${APP_BINARY}" ] || [ ! -f "${BUILD_DIR}/CMakeCache.txt" ]; then
  echo "Building Qt application..."
  cmake -S "${APP_DIR}" -B "${BUILD_DIR}" -DCMAKE_BUILD_TYPE=Release
  cmake --build "${BUILD_DIR}" -j$(nproc)
fi

echo "Launching Qt application..."
echo "  LLM Backend: ${NEURX_LLM_BASE_URL}${NEURX_LLM_CHAT_PATH}"
echo "  Model: ${NEURX_LLM_MODEL}"
echo "  Checkpoint root: ${NEURX_BACKEND_CHECKPOINT_ROOT}"
echo "  Checkpoint file: ${NEURX_BACKEND_CHECKPOINT_FILE}"

# Run Qt app
"${APP_BINARY}"
