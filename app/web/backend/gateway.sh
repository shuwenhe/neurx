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

json_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

sed_escape_replacement() {
  printf '%s' "${1:-}" | sed -e 's/[\\&|]/\\&/g'
}

serve_out_file="$(mktemp /tmp/neurx_serve_out.XXXXXX)"
serve_err_file="$(mktemp /tmp/neurx_serve_err.XXXXXX)"
trap 'rm -f "$body_file" "$serve_out_file" "$serve_err_file"' EXIT

set +e
"${S_BINARY}" run "${ROOT_DIR}/backend/serve.s" >"$serve_out_file" 2>"$serve_err_file"
serve_status=$?
set -e

serve_out="$(cat "$serve_out_file")"
serve_err="$(cat "$serve_err_file")"

completion="S backend is alive and responding."
if [ -n "${prompt:-}" ]; then
  prompt_line="$(printf '%s' "$prompt" | head -n 1)"
  completion="已收到你的请求：${prompt_line}。当前由本地 S 后端链路处理。"
fi

if [ "$serve_status" -ne 0 ]; then
  completion="${completion}（S runtime提示：$(printf '%s' "$serve_err" | tr '\n' ' ' | head -c 120)）"
fi

if [ "$serve_status" -eq 0 ] && [ -z "$serve_out" ]; then
  completion="${completion}（serve.s 执行成功但无输出）"
fi

model_escaped="$(json_escape "${NEURX_BACKEND_MODEL:-gpt_large}")"
prompt_escaped="$(json_escape "${NEURX_BACKEND_PROMPT:-}")"
completion_escaped="$(json_escape "$completion")"

# Prefer serve.s template output, then inject runtime fields.
if [ "$serve_status" -eq 0 ] && printf '%s' "$serve_out" | grep -q '{'; then
  model_sed="$(sed_escape_replacement "$model_escaped")"
  prompt_sed="$(sed_escape_replacement "$prompt_escaped")"
  completion_sed="$(sed_escape_replacement "$completion_escaped")"
  printf '%s' "$serve_out" \
    | sed -e "s|__MODEL__|${model_sed}|g" \
          -e "s|__PROMPT__|${prompt_sed}|g" \
          -e "s|__COMPLETION__|${completion_sed}|g"
  exit 0
fi

printf '{"ok":true,"backend_name":"neurx.app.backend.llm.s","model_name":"%s","summary":"s-gateway-fallback","prompt":"%s","completion":"%s","generated_tokens":16,"last_token":0,"train_loss":0,"validation_loss":0,"ready":true}' \
  "$model_escaped" \
  "$prompt_escaped" \
  "$completion_escaped"

exit 0
