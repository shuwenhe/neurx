#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S_BINARY="${NEURX_S_BINARY:-${S_BINARY:-s}}"

pick_s_binary() {
  local candidate="$1"
  if [ -x "$candidate" ]; then
    "$candidate" >/tmp/neurx_s_usage.txt 2>&1 || true
    if grep -q "s run <input.s>" /tmp/neurx_s_usage.txt; then
      rm -f /tmp/neurx_s_usage.txt
      echo "$candidate"
      return 0
    fi
  fi
  return 1
}

if ! pick_s_binary "$S_BINARY" >/dev/null; then
  if [ -x "/home/shuwen/shuwen/s/bin/s" ] && pick_s_binary "/home/shuwen/shuwen/s/bin/s" >/dev/null; then
    S_BINARY="/home/shuwen/shuwen/s/bin/s"
  fi
fi

body_file="$(mktemp /tmp/neurx_backend_body.XXXXXX.json)"
trap 'rm -f "$body_file"' EXIT

cat > "$body_file"

extract_json_string() {
  local key="$1"
  sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$body_file" | head -n 1
}

extract_json_int() {
  local key="$1"
  sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\\([0-9][0-9]*\\).*/\\1/p" "$body_file" | head -n 1
}

model_name="$(extract_json_string model)"
prompt="$(extract_json_string prompt)"
max_tokens="$(extract_json_int max_tokens)"

if [ -n "${model_name:-}" ]; then
  export NEURX_BACKEND_MODEL="$model_name"
fi

if [ -n "${prompt:-}" ]; then
  export NEURX_BACKEND_PROMPT="$prompt"
else
  export NEURX_BACKEND_PROMPT="Explain NeurX LLM backend in one short paragraph."
fi

if [ -n "${max_tokens:-}" ]; then
  export NEURX_BACKEND_MAX_TOKENS="$max_tokens"
fi

export NEURX_BACKEND_REQUEST_FILE=""
exec "${S_BINARY}" run "${ROOT_DIR}/backend/serve.s"
