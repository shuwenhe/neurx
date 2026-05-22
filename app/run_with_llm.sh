#!/usr/bin/env bash
set -euo pipefail

# Start NeurX backend and Qt application with local LLM model

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${APP_DIR}/.." && pwd)"
HOST_UNAME="$(uname -s)"
PLATFORM_TAG="$(printf '%s' "${HOST_UNAME}" | tr '[:upper:]' '[:lower:]')"

# Detect WSL (Linux kernel running inside Windows)
IS_WSL=0
if [[ "${PLATFORM_TAG}" == linux ]] && grep -qi microsoft /proc/version 2>/dev/null; then
  IS_WSL=1
fi

normalize_target_platform() {
  local raw="${1:-}"
  case "${raw}" in
    linux|windows|macos|ios|android|harmony)
      printf '%s' "${raw}"
      ;;
    win|mingw|msys|cygwin)
      printf '%s' "windows"
      ;;
    mac|darwin|osx)
      printf '%s' "macos"
      ;;
    *)
      return 1
      ;;
  esac
}

detect_host_platform() {
  if [[ "${PLATFORM_TAG}" == mingw* || "${PLATFORM_TAG}" == msys* || "${PLATFORM_TAG}" == cygwin* ]]; then
    printf '%s' "windows"
  elif [[ "${HOST_UNAME}" == "Darwin" ]]; then
    printf '%s' "macos"
  else
    printf '%s' "linux"
  fi
}

HOST_PLATFORM="$(detect_host_platform)"
TARGET_PLATFORM="$(normalize_target_platform "${NEURX_APP_TARGET_PLATFORM:-${HOST_PLATFORM}}" || true)"
if [ -z "${TARGET_PLATFORM}" ]; then
  echo "Error: unsupported NEURX_APP_TARGET_PLATFORM=${NEURX_APP_TARGET_PLATFORM:-}"
  echo "Hint: use one of linux/windows/macos/ios/android/harmony."
  exit 1
fi

case "${TARGET_PLATFORM}" in
  linux)
    if [[ "$(uname -m)" == aarch64 || "$(uname -m)" == arm64 ]]; then
      APP_OUTPUT_SUBDIR="linux-arm64"
    else
      APP_OUTPUT_SUBDIR="linux-x86_64"
    fi
    ;;
  windows)
    APP_OUTPUT_SUBDIR="windows-x86_64"
    ;;
  macos)
    if [[ "$(uname -m)" == arm64 ]]; then
      APP_OUTPUT_SUBDIR="macos-arm64"
    else
      APP_OUTPUT_SUBDIR="macos-x86_64"
    fi
    ;;
  ios)
    exec "${APP_DIR}/scripts/run_ios.sh" "$@"
    ;;
  android)
    exec "${APP_DIR}/scripts/run_android.sh" "$@"
    ;;
  harmony)
    exec "${APP_DIR}/scripts/run_harmony.sh" "$@"
    ;;
esac

BUILD_DIR="${NEURX_APP_BUILD_DIR:-${APP_DIR}/build/make-${TARGET_PLATFORM}}"
APP_BINARY_BASE="${ROOT_DIR}/bin/${APP_OUTPUT_SUBDIR}/neurx_app"

to_native_path() {
  local input_path="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -m "${input_path}"
  elif [[ "${IS_WSL}" == "1" ]] && command -v wslpath >/dev/null 2>&1; then
    wslpath -m "${input_path}"
  else
    printf '%s' "${input_path}"
  fi
}

resolve_cmake() {
  if [ -n "${NEURX_CMAKE:-}" ] && [ -x "${NEURX_CMAKE}" ]; then
    printf '%s' "${NEURX_CMAKE}"
    return 0
  fi

  if command -v cmake >/dev/null 2>&1; then
    command -v cmake
    return 0
  fi

  local candidates=(
    "/c/Users/Public/qt/Tools/CMake_64/bin/cmake.exe"
    "/c/Program Files/CMake/bin/cmake.exe"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [ -x "${candidate}" ]; then
      printf '%s' "${candidate}"
      return 0
    fi
  done

  return 1
}

resolve_qt6_dir() {
  if [ -n "${Qt6_DIR:-}" ] && [ -f "${Qt6_DIR}/Qt6Config.cmake" ]; then
    printf '%s' "${Qt6_DIR}"
    return 0
  fi

  local candidates=()
  case "${TARGET_PLATFORM}" in
    linux)
      candidates=(
        "/usr/lib/x86_64-linux-gnu/cmake/Qt6"
        "/usr/lib/aarch64-linux-gnu/cmake/Qt6"
        "/usr/lib64/cmake/Qt6"
        "/usr/lib/cmake/Qt6"
        "/usr/local/lib/cmake/Qt6"
        # Qt official installer (x86_64)
        "${HOME}/Qt/6.11.0/gcc_64/lib/cmake/Qt6"
        "${HOME}/Qt/6.10.0/gcc_64/lib/cmake/Qt6"
        "${HOME}/Qt/6.9.0/gcc_64/lib/cmake/Qt6"
        "${HOME}/Qt/6.8.0/gcc_64/lib/cmake/Qt6"
      )
      if command -v qtpaths6 >/dev/null 2>&1; then
        local prefix=""
        prefix="$(qtpaths6 --install-prefix 2>/dev/null || true)"
        if [ -n "${prefix}" ]; then
          candidates+=("${prefix}/lib/cmake/Qt6")
        fi
      fi
      ;;
    macos)
      candidates=(
        "/opt/homebrew/opt/qt/lib/cmake/Qt6"
        "/usr/local/opt/qt/lib/cmake/Qt6"
        # Qt official installer (Apple Silicon)
        "${HOME}/Qt/6.11.0/macos/lib/cmake/Qt6"
        "${HOME}/Qt/6.10.0/macos/lib/cmake/Qt6"
        "${HOME}/Qt/6.9.0/macos/lib/cmake/Qt6"
        "${HOME}/Qt/6.8.0/macos/lib/cmake/Qt6"
      )
      if command -v brew >/dev/null 2>&1; then
        local brew_prefix=""
        brew_prefix="$(brew --prefix qt 2>/dev/null || true)"
        if [ -n "${brew_prefix}" ]; then
          candidates=("${brew_prefix}/lib/cmake/Qt6" "${candidates[@]}")
        fi
      fi
      ;;
    windows)
      candidates=(
        "/c/Users/Public/qt/6.11.0/mingw_64/lib/cmake/Qt6"
      )
      ;;
  esac

  local candidate
  for candidate in "${candidates[@]}"; do
    if [ -f "${candidate}/Qt6Config.cmake" ]; then
      printf '%s' "${candidate}"
      return 0
    fi
  done

  return 1
}

resolve_qt_bin_dir() {
  local qt6_dir
  qt6_dir="$(resolve_qt6_dir || true)"
  if [ -z "${qt6_dir}" ]; then
    return 1
  fi

  local candidate
  candidate="$(cd "${qt6_dir}/../../.." && pwd)/bin"
  if [ -d "${candidate}" ]; then
    printf '%s' "${candidate}"
    return 0
  fi

  return 1
}

resolve_windeployqt() {
  if [ -n "${NEURX_WINDEPLOYQT:-}" ] && [ -x "${NEURX_WINDEPLOYQT}" ]; then
    printf '%s' "${NEURX_WINDEPLOYQT}"
    return 0
  fi

  local candidates=(
    "/c/Users/Public/qt/6.11.0/mingw_64/bin/windeployqt.exe"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [ -x "${candidate}" ]; then
      printf '%s' "${candidate}"
      return 0
    fi
  done

  return 1
}

resolve_mingw_gpp() {
  if [ -n "${CXX:-}" ] && [ -x "${CXX}" ]; then
    printf '%s' "${CXX}"
    return 0
  fi

  if command -v g++ >/dev/null 2>&1; then
    command -v g++
    return 0
  fi

  local candidates=(
    "/c/Users/Public/qt/Tools/mingw1310_64/bin/g++.exe"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [ -x "${candidate}" ]; then
      printf '%s' "${candidate}"
      return 0
    fi
  done

  return 1
}

resolve_mingw_make() {
  if [ -n "${CMAKE_MAKE_PROGRAM:-}" ] && [ -x "${CMAKE_MAKE_PROGRAM}" ]; then
    printf '%s' "${CMAKE_MAKE_PROGRAM}"
    return 0
  fi

  if command -v mingw32-make >/dev/null 2>&1; then
    command -v mingw32-make
    return 0
  fi

  local candidates=(
    "/c/Users/Public/qt/Tools/mingw1310_64/bin/mingw32-make.exe"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [ -x "${candidate}" ]; then
      printf '%s' "${candidate}"
      return 0
    fi
  done

  return 1
}

resolve_ollama() {
  if [ -n "${NEURX_OLLAMA_BIN:-}" ] && [ -x "${NEURX_OLLAMA_BIN}" ]; then
    printf '%s' "${NEURX_OLLAMA_BIN}"
    return 0
  fi

  if command -v ollama >/dev/null 2>&1; then
    command -v ollama
    return 0
  fi

  # In WSL, ollama.exe may be on the Windows PATH forwarded into WSL
  if [[ "${IS_WSL}" == "1" ]] && command -v ollama.exe >/dev/null 2>&1; then
    command -v ollama.exe
    return 0
  fi

  # Determine the Windows username when running in WSL
  local win_user=""
  if [[ "${IS_WSL}" == "1" ]]; then
    win_user="$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r\n' || true)"
  fi

  local candidates=(
    "/c/Users/${USERNAME:-${USER:-}}/AppData/Local/Programs/Ollama/ollama.exe"
    "/c/Program Files/Ollama/ollama.exe"
  )

  if [[ "${IS_WSL}" == "1" ]] && [ -n "${win_user}" ]; then
    candidates+=(
      "/mnt/c/Users/${win_user}/AppData/Local/Programs/Ollama/ollama.exe"
      "/mnt/c/Program Files/Ollama/ollama.exe"
    )
  fi

  local candidate
  for candidate in "${candidates[@]}"; do
    if [ -x "${candidate}" ]; then
      printf '%s' "${candidate}"
      return 0
    fi
  done

  return 1
}

ollama_model_exists() {
  local ollama_bin="$1"
  local model="$2"
  "${ollama_bin}" list 2>/dev/null | awk 'NR>1 {print $1}' | grep -Fxq "${model}"
}

to_ollama_model_path() {
  local input_path="$1"
  local ollama_bin="$2"
  if [[ "${ollama_bin}" == *.exe ]]; then
    to_native_path "${input_path}"
  else
    printf '%s' "${input_path}"
  fi
}

ensure_local_ollama_model() {
  local ollama_bin="$1"
  local model_name="$2"
  local model_dir="$3"

  if [ ! -d "${model_dir}" ]; then
    return 1
  fi

  if ollama_model_exists "${ollama_bin}" "${model_name}"; then
    return 0
  fi

  local tmp_dir=""
  local modelfile=""
  local ollama_model_dir=""
  tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t neurx-ollama)"
  modelfile="${tmp_dir}/Modelfile"
  ollama_model_dir="$(to_ollama_model_path "${model_dir}" "${ollama_bin}")"

  cat > "${modelfile}" <<EOF
FROM ${ollama_model_dir}
PARAMETER temperature 0.2
EOF

  echo "Creating local Ollama model ${model_name} from ${model_dir}..."
  "${ollama_bin}" create "${model_name}" -f "$(to_ollama_model_path "${modelfile}" "${ollama_bin}")"
  rm -rf "${tmp_dir}"
}

ensure_optional_local_ollama_model() {
  local ollama_bin="$1"
  local model_name="$2"
  local model_dir="$3"

  if [ -z "${model_name}" ] || [ -z "${model_dir}" ] || [ ! -d "${model_dir}" ]; then
    return 0
  fi

  ensure_local_ollama_model "${ollama_bin}" "${model_name}" "${model_dir}"
}

ensure_repo_ollama_server() {
  local ollama_bin="$1"
  local ollama_url="${NEURX_OLLAMA_URL:-http://127.0.0.1:11435}"
  local ollama_host="${ollama_url#http://}"
  ollama_host="${ollama_host#https://}"

  if curl -sf --connect-timeout 1 "${ollama_url}/api/tags" >/dev/null 2>&1; then
    return 0
  fi

  mkdir -p "${ROOT_DIR}/build/logs"
  local log_file="${ROOT_DIR}/build/logs/ollama.log"
  echo "Starting dedicated Ollama server..."
  echo "  URL: ${ollama_url}"
  echo "  Store: ${OLLAMA_MODELS}"
  OLLAMA_HOST="${ollama_host}" OLLAMA_MODELS="${OLLAMA_MODELS}" "${ollama_bin}" serve >"${log_file}" 2>&1 &

  local attempt
  for attempt in $(seq 1 30); do
    if curl -sf --connect-timeout 1 "${ollama_url}/api/tags" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  echo "Error: dedicated Ollama server did not become ready at ${ollama_url}"
  echo "Hint: inspect ${log_file}"
  exit 1
}

ensure_ollama_and_model() {
  local model="$1"
  local ollama_bin=""

  ollama_bin="$(resolve_ollama || true)"
  if [ -z "${ollama_bin}" ] || ! "${ollama_bin}" list >/dev/null 2>&1; then
    if [[ "${TARGET_PLATFORM}" == "windows" ]] && [[ "${PLATFORM_TAG}" == mingw* || "${PLATFORM_TAG}" == msys* || "${PLATFORM_TAG}" == cygwin* || "${IS_WSL}" == "1" ]]; then
      echo "Ollama not found or not ready; installing and preparing ${model}..."
      powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(to_native_path "${APP_DIR}/scripts/setup_ollama.ps1")" -Model "${model}"
      ollama_bin="$(resolve_ollama || true)"
    else
      echo "Error: ollama not found."
      echo "Hint: install Ollama first or set NEURX_OLLAMA_BIN=/path/to/ollama."
      exit 1
    fi
  fi

  ensure_repo_ollama_server "${ollama_bin}"

  if [ -n "${NEURX_OLLAMA_MODEL_DIR:-}" ] && [ -d "${NEURX_OLLAMA_MODEL_DIR}" ]; then
    local local_model_name="${NEURX_OLLAMA_LOCAL_MODEL_NAME:-neurx-qwen2.5-0.5b-instruct-local:latest}"
    ensure_local_ollama_model "${ollama_bin}" "${local_model_name}" "${NEURX_OLLAMA_MODEL_DIR}"
    ensure_optional_local_ollama_model \
      "${ollama_bin}" \
      "${NEURX_CUSTOMER_SERVICE_FALLBACK_MODEL:-${NEURX_OLLAMA_FALLBACK_MODEL:-}}" \
      "${NEURX_CUSTOMER_SERVICE_FALLBACK_MODEL_DIR:-${NEURX_OLLAMA_FALLBACK_MODEL_DIR:-}}"
  elif ! ollama_model_exists "${ollama_bin}" "${model}"; then
    echo "Pulling Ollama model ${model}..."
    "${ollama_bin}" pull "${model}"
  fi

  export NEURX_OLLAMA_BIN="${ollama_bin}"
}

stop_running_app_before_build() {
  local app_name="neurx_app.exe"
  local taskkill_bin=""

  # Resolve taskkill — works in mingw, WSL, and cygwin
  if command -v taskkill.exe >/dev/null 2>&1; then
    taskkill_bin="$(command -v taskkill.exe)"
  elif [ -x "/mnt/c/Windows/System32/taskkill.exe" ]; then
    taskkill_bin="/mnt/c/Windows/System32/taskkill.exe"
  elif [ -x "/c/Windows/System32/taskkill.exe" ]; then
    taskkill_bin="/c/Windows/System32/taskkill.exe"
  fi

  if [ "${TARGET_PLATFORM}" = "windows" ] && [ -n "${taskkill_bin}" ]; then
    "${taskkill_bin}" /F /IM "${app_name}" /T >/dev/null 2>&1 || true

    local tasklist_bin=""
    if command -v tasklist.exe >/dev/null 2>&1; then
      tasklist_bin="$(command -v tasklist.exe)"
    elif [ -x "/mnt/c/Windows/System32/tasklist.exe" ]; then
      tasklist_bin="/mnt/c/Windows/System32/tasklist.exe"
    elif [ -x "/c/Windows/System32/tasklist.exe" ]; then
      tasklist_bin="/c/Windows/System32/tasklist.exe"
    fi

    if [ -n "${tasklist_bin}" ]; then
      local attempt
      for attempt in 1 2 3 4 5; do
        if "${tasklist_bin}" /FI "IMAGENAME eq ${app_name}" 2>/dev/null | grep -qi "${app_name}"; then
          sleep 1
        else
          break
        fi
      done
    else
      sleep 2
    fi
  else
    pkill -f neurx_app 2>/dev/null || true
    sleep 1
  fi

  # Wait until the file lock on the binary is actually released.
  # Windows may still hold the lock briefly after the process exits.
  local bin_path="${APP_BINARY_BASE}.exe"
  if [ ! -f "${bin_path}" ]; then
    bin_path="${APP_BINARY_BASE}"
  fi
  if [ -f "${bin_path}" ]; then
    local tmp_path="${bin_path}.old.$$"
    local lock_wait
    for lock_wait in $(seq 1 10); do
      if mv -f "${bin_path}" "${tmp_path}" 2>/dev/null; then
        mv -f "${tmp_path}" "${bin_path}" 2>/dev/null || true
        break
      fi
      sleep 1
    done
  fi
}

# Backend configuration
export PORT=${PORT:-18080}
export NEURX_BACKEND_MODEL=${NEURX_BACKEND_MODEL:-Qwen2.5-VL-7B}
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
echo "  Host platform: ${HOST_PLATFORM}"
echo "  Target platform: ${TARGET_PLATFORM}"
echo "  Backend port: ${PORT}"

BACKEND_PID=""
HEALTH_URL="http://127.0.0.1:${PORT}/neurx/health"

BACKEND_DIR=""
if [ -d "${APP_DIR}/service" ]; then
  BACKEND_DIR="${APP_DIR}/service"
elif [ -d "${APP_DIR}/web/backend" ]; then
  BACKEND_DIR="${APP_DIR}/web/backend"
elif [ -d "${APP_DIR}/backend" ]; then
  BACKEND_DIR="${APP_DIR}/backend"
else
  echo "Error: backend directory not found under ${APP_DIR}."
  exit 1
fi

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
    cd "${BACKEND_DIR}"
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
export NEURX_CODE_AGENT_ENABLE_MODEL_LOOP="${NEURX_CODE_AGENT_ENABLE_MODEL_LOOP:-0}"
export NEURX_CODE_AGENT_BASE_URL="${NEURX_CODE_AGENT_BASE_URL:-${NEURX_LLM_BASE_URL}}"
export NEURX_CODE_AGENT_CHAT_PATH="${NEURX_CODE_AGENT_CHAT_PATH:-${NEURX_LLM_CHAT_PATH}}"
export NEURX_CODE_AGENT_MODEL="${NEURX_CODE_AGENT_MODEL:-${NEURX_LLM_MODEL}}"
export NEURX_CODE_AGENT_REMOTE_BASE_URL="${NEURX_CODE_AGENT_REMOTE_BASE_URL:-http://111.202.231.146:8080}"
export NEURX_CODE_AGENT_REMOTE_CHAT_PATH="${NEURX_CODE_AGENT_REMOTE_CHAT_PATH:-/neurx/api/chat}"
export NEURX_CODE_AGENT_REMOTE_MODEL="${NEURX_CODE_AGENT_REMOTE_MODEL:-Qwen2.5-VL-7B}"

# Ollama inference endpoint for arbitrary code generation (gateway.sh fallback)
# Override with:
#   NEURX_OLLAMA_URL=http://host:11435
#   NEURX_OLLAMA_MODEL=qwen2.5:0.5b
#   NEURX_OLLAMA_MODEL_DIR=/path/to/local/safetensors/model
export NEURX_OLLAMA_MODELS="${NEURX_OLLAMA_MODELS:-${ROOT_DIR}/artifacts/checkpoints}"
mkdir -p "${NEURX_OLLAMA_MODELS}"
export OLLAMA_MODELS="${NEURX_OLLAMA_MODELS}"
export NEURX_OLLAMA_URL="${NEURX_OLLAMA_URL:-http://127.0.0.1:11435}"
export NEURX_OLLAMA_LOCAL_MODEL_NAME="${NEURX_OLLAMA_LOCAL_MODEL_NAME:-neurx-qwen2.5-0.5b-instruct-local:latest}"
export NEURX_CUSTOMER_SERVICE_FALLBACK_MODEL="${NEURX_CUSTOMER_SERVICE_FALLBACK_MODEL:-neurx-qwen2.5-vl-7b-local:latest}"
NEURX_VL_BASE_URL="${NEURX_VL_BASE_URL:-http://127.0.0.1:8004}"
NEURX_VL_MODEL="${NEURX_VL_MODEL:-Qwen2.5-VL-7B}"
NEURX_VL_CHAT_PATH="${NEURX_VL_CHAT_PATH:-/v1/chat/completions}"
# Prefer the Instruct model by default; keep VL-7B as a fallback if present.
DEFAULT_OLLAMA_MODEL_DIR_PRIMARY="${ROOT_DIR}/artifacts/checkpoints/Qwen2.5-0.5B-Instruct"
DEFAULT_OLLAMA_MODEL_DIR_FALLBACK="${ROOT_DIR}/artifacts/checkpoints/Qwen2.5-VL-7B"
if [ -z "${NEURX_OLLAMA_MODEL_DIR:-}" ] && [ -d "${DEFAULT_OLLAMA_MODEL_DIR_PRIMARY}" ]; then
  export NEURX_OLLAMA_MODEL_DIR="${DEFAULT_OLLAMA_MODEL_DIR_PRIMARY}"
fi
if [ -z "${NEURX_CUSTOMER_SERVICE_FALLBACK_MODEL_DIR:-}" ] && [ -d "${DEFAULT_OLLAMA_MODEL_DIR_FALLBACK}" ]; then
  export NEURX_CUSTOMER_SERVICE_FALLBACK_MODEL_DIR="${DEFAULT_OLLAMA_MODEL_DIR_FALLBACK}"
fi
if [ -n "${NEURX_OLLAMA_MODEL_DIR:-}" ] && [ -d "${NEURX_OLLAMA_MODEL_DIR}" ]; then
  export NEURX_OLLAMA_MODEL="${NEURX_OLLAMA_MODEL:-${NEURX_OLLAMA_LOCAL_MODEL_NAME}}"
else
  export NEURX_OLLAMA_MODEL="${NEURX_OLLAMA_MODEL:-qwen2.5:0.5b}"
fi
if ! curl -sf --connect-timeout 1 "${NEURX_VL_BASE_URL}/health" >/dev/null 2>&1; then
  ensure_ollama_and_model "${NEURX_OLLAMA_MODEL}"
fi

# If a local Ollama model directory is configured, route the main LLM chat
# directly to Ollama. Keep the smaller configured Ollama model as the default;
# the imported local directory model remains available for explicit selection.
# The code agent and NeurX-specific API paths (/neurx/api/*) still go through
# the s-backend at port ${PORT} — those endpoints don't exist on Ollama.
if [ -n "${NEURX_OLLAMA_MODEL_DIR:-}" ] && [ -d "${NEURX_OLLAMA_MODEL_DIR}" ]; then
  export NEURX_BACKEND_MODEL="${NEURX_OLLAMA_MODEL}"
  export NEURX_LLM_MODEL="${NEURX_OLLAMA_MODEL}"
  export NEURX_LLM_BASE_URL="${NEURX_OLLAMA_URL}"
  export NEURX_LLM_CHAT_PATH="/api/chat"
  # Code agent stays on s-backend so /neurx/api/chat and /neurx/api/agent/* resolve
  export NEURX_CODE_AGENT_BASE_URL="http://127.0.0.1:${PORT}"
  export NEURX_CODE_AGENT_CHAT_PATH="/neurx/api/chat"
  export NEURX_CODE_AGENT_MODEL="${NEURX_OLLAMA_MODEL}"
fi

if curl -sf --connect-timeout 1 "${NEURX_VL_BASE_URL}/health" >/dev/null 2>&1; then
  export NEURX_BACKEND_MODEL="${NEURX_VL_MODEL}"
  export NEURX_LLM_MODEL="${NEURX_VL_MODEL}"
  export NEURX_LLM_BASE_URL="${NEURX_VL_BASE_URL}"
  export NEURX_LLM_CHAT_PATH="${NEURX_VL_CHAT_PATH}"
  export NEURX_CODE_AGENT_BASE_URL="http://127.0.0.1:${PORT}"
  export NEURX_CODE_AGENT_CHAT_PATH="/neurx/api/chat"
  export NEURX_CODE_AGENT_MODEL="${NEURX_CODE_AGENT_MODEL:-${NEURX_LLM_MODEL}}"
fi

CMAKE_BIN="$(resolve_cmake || true)"
if [ -z "${CMAKE_BIN}" ]; then
  echo "Error: cmake not found."
  echo "Hint: install CMake or set NEURX_CMAKE=/path/to/cmake(.exe)."
  exit 1
fi

QT6_DIR_RESOLVED="$(resolve_qt6_dir || true)"
if [ -z "${QT6_DIR_RESOLVED}" ]; then
  echo "Error: Qt6_DIR not found."
  echo "Hint: set Qt6_DIR=/path/to/Qt6 or install the Qt 6 MinGW kit."
  exit 1
fi
export Qt6_DIR="${QT6_DIR_RESOLVED}"
QT_BIN_DIR="$(resolve_qt_bin_dir || true)"

CMAKE_CONFIGURE_ARGS=()
EXPECTED_GENERATOR=""
CMAKE_CONFIGURE_ARGS+=(
  -DNEURX_APP_TARGET_PLATFORM="${TARGET_PLATFORM}"
  -DQt6_DIR="$(to_native_path "${QT6_DIR_RESOLVED}")"
  -DCMAKE_PREFIX_PATH="$(to_native_path "$(cd "${QT6_DIR_RESOLVED}/../../.." && pwd)")"
)

if [[ "${TARGET_PLATFORM}" == "windows" ]]; then
  if [[ ! "${PLATFORM_TAG}" == mingw* && ! "${PLATFORM_TAG}" == msys* && ! "${PLATFORM_TAG}" == cygwin* && ! "${IS_WSL}" == "1" ]]; then
    echo "Error: windows app target requires Windows, MSYS2, Git Bash, or WSL."
    exit 1
  fi
  MINGW_GPP="$(resolve_mingw_gpp || true)"
  MINGW_MAKE="$(resolve_mingw_make || true)"
  if [ -z "${MINGW_GPP}" ] || [ -z "${MINGW_MAKE}" ]; then
    echo "Error: MinGW toolchain not found."
    echo "Hint: install the Qt MinGW kit or set CXX and CMAKE_MAKE_PROGRAM explicitly."
    exit 1
  fi

  EXPECTED_GENERATOR="MinGW Makefiles"
  CMAKE_CONFIGURE_ARGS+=(
    -G "${EXPECTED_GENERATOR}"
    -DCMAKE_CXX_COMPILER="$(to_native_path "${MINGW_GPP}")"
    -DCMAKE_MAKE_PROGRAM="$(to_native_path "${MINGW_MAKE}")"
  )

  if [ -n "${QT_BIN_DIR}" ]; then
    export PATH="${QT_BIN_DIR}:${PATH}"
  fi
  export PATH="$(dirname "${MINGW_GPP}"):${PATH}"
fi

mkdir -p "${BUILD_DIR}"

# Reconfigure if the build cache belongs to a different source tree.
CACHE_FILE="${BUILD_DIR}/CMakeCache.txt"
if [ -f "${CACHE_FILE}" ]; then
  CACHE_HOME_DIR="$(sed -n 's/^CMAKE_HOME_DIRECTORY:INTERNAL=//p' "${CACHE_FILE}" | head -n 1)"
  CACHE_GENERATOR="$(sed -n 's/^CMAKE_GENERATOR:INTERNAL=//p' "${CACHE_FILE}" | head -n 1)"
  APP_DIR_NATIVE="$(to_native_path "${APP_DIR}")"
  if [ -n "${CACHE_HOME_DIR}" ] && [ "${CACHE_HOME_DIR}" != "${APP_DIR}" ] && [ "${CACHE_HOME_DIR}" != "${APP_DIR_NATIVE}" ]; then
    echo "CMake cache points to a different source tree; recreating build directory..."
    echo "  cached source: ${CACHE_HOME_DIR}"
    echo "  current source: ${APP_DIR_NATIVE}"
    rm -rf "${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}"
  elif [ -n "${EXPECTED_GENERATOR}" ] && [ -n "${CACHE_GENERATOR}" ] && [ "${CACHE_GENERATOR}" != "${EXPECTED_GENERATOR}" ]; then
    echo "CMake cache uses the wrong generator; recreating build directory..."
    echo "  cached generator: ${CACHE_GENERATOR}"
    echo "  expected generator: ${EXPECTED_GENERATOR}"
    rm -rf "${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}"
  fi
fi

# Kill any running neurx_app instance so the linker can overwrite the binary.
stop_running_app_before_build

# Rebuild Qt app on every launch so make app picks up the latest local changes.
if [ ! -f "${BUILD_DIR}/CMakeCache.txt" ]; then
  echo "Configuring Qt application..."
  "${CMAKE_BIN}" -S "$(to_native_path "${APP_DIR}")" -B "$(to_native_path "${BUILD_DIR}")" -DCMAKE_BUILD_TYPE=Release "${CMAKE_CONFIGURE_ARGS[@]}"
fi
echo "Building Qt application..."
BUILD_JOBS="$(command -v nproc >/dev/null 2>&1 && nproc || getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || printf '4')"
"${CMAKE_BIN}" --build "$(to_native_path "${BUILD_DIR}")" --clean-first -j"${BUILD_JOBS}"

APP_BINARY="${APP_BINARY_BASE}"
if [ ! -x "${APP_BINARY}" ] && [ -x "${APP_BINARY_BASE}.exe" ]; then
  APP_BINARY="${APP_BINARY_BASE}.exe"
fi
if [ ! -x "${APP_BINARY}" ] && [ -x "${APP_BINARY_BASE}.app/Contents/MacOS/neurx_app" ]; then
  APP_BINARY="${APP_BINARY_BASE}.app/Contents/MacOS/neurx_app"
fi

if [ ! -x "${APP_BINARY}" ]; then
  echo "Error: Qt application binary not found: ${APP_BINARY_BASE}"
  exit 1
fi

if [[ "${APP_BINARY}" == *.exe ]] && [[ "${TARGET_PLATFORM}" == "windows" ]] && [[ "${PLATFORM_TAG}" == mingw* || "${PLATFORM_TAG}" == msys* || "${PLATFORM_TAG}" == cygwin* ]]; then
  WINDEPLOYQT_BIN="$(resolve_windeployqt || true)"
  if [ -n "${WINDEPLOYQT_BIN}" ]; then
    echo "Deploying Qt runtime beside the app..."
    "${WINDEPLOYQT_BIN}" \
      --qmldir "$(to_native_path "${APP_DIR}")" \
      --dir "$(to_native_path "$(dirname "${APP_BINARY}")")" \
      "$(to_native_path "${APP_BINARY}")" >/dev/null
  fi
fi

echo "Launching Qt application..."
echo "  LLM Backend: ${NEURX_LLM_BASE_URL}${NEURX_LLM_CHAT_PATH}"
echo "  Model: ${NEURX_LLM_MODEL}"
if [ -n "${NEURX_CUSTOMER_SERVICE_FALLBACK_MODEL_DIR:-}" ]; then
  echo "  Customer-service fallback model: ${NEURX_CUSTOMER_SERVICE_FALLBACK_MODEL}"
fi
echo "  Code agent model loop: ${NEURX_CODE_AGENT_ENABLE_MODEL_LOOP}"
echo "  Code agent backend: ${NEURX_CODE_AGENT_BASE_URL}${NEURX_CODE_AGENT_CHAT_PATH}"
echo "  Code agent model: ${NEURX_CODE_AGENT_MODEL}"
echo "  Checkpoint root: ${NEURX_BACKEND_CHECKPOINT_ROOT}"
echo "  Checkpoint file: ${NEURX_BACKEND_CHECKPOINT_FILE}"
if [ -n "${NEURX_OLLAMA_MODEL_DIR:-}" ]; then
  echo "  Ollama model dir: ${NEURX_OLLAMA_MODEL_DIR}"
fi
echo "  Ollama store: ${NEURX_OLLAMA_MODELS}"
echo "  Ollama URL: ${NEURX_OLLAMA_URL}"
echo "  Ollama model: ${NEURX_OLLAMA_MODEL}"
echo "  Build dir: ${BUILD_DIR}"
echo "  CMake: ${CMAKE_BIN}"
if [ -n "${EXPECTED_GENERATOR}" ]; then
  echo "  Generator: ${EXPECTED_GENERATOR}"
fi
if [ -n "${QT_BIN_DIR}" ]; then
  echo "  Qt bin: ${QT_BIN_DIR}"
fi

# Run Qt app
# Use Fusion style to allow full QML contentItem customization (avoids native-style warnings)
export QT_QUICK_CONTROLS_STYLE="${QT_QUICK_CONTROLS_STYLE:-Fusion}"
# Prevent Git Bash / MSYS from converting env-var values that start with '/'
# into Windows paths (e.g. /neurx/api/chat → C:/Program Files/Git/neurx/api/chat)
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"
"${APP_BINARY}"
