#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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
exec s "${ROOT_DIR}/backend/serve.s"
