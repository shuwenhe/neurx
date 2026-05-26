#!/usr/bin/env bash
# Shared OpenAI-compatible model helpers for code agent runners.
set -euo pipefail

code_agent_json_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

code_agent_normalize_model_url() {
  local base="${1:-}"
  local path="${2:-}"
  [[ -z "$base" ]] && return 1
  base="${base%/}"

  # 如果是 SiliconFlow 或类似的 OpenAI 兼容接口，且 base 已经包含了 /v1
  # 且 path 以 /v1 开头，则需要去重
  if [[ "$base" == */v1 ]] && [[ "$path" == /v1/* ]]; then
    path="${path#/v1}"
  fi

  if [[ "$path" != /* ]]; then
    path="/$path"
  fi
  printf '%s%s' "$base" "$path"
}

code_agent_extract_json_field() {
  local key="$1"
  local text="$2"
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$text" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('$key', ''), end='')
except Exception:
    sys.exit(1)
" 2>/dev/null && return 0
  fi
  # Fallback to sed only for simple cases if python is missing
  printf '%s' "$text" | sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -n 1
}

code_agent_model_configured() {
  [[ -n "${NEURX_CODE_AGENT_BASE_URL:-${NEURX_LLM_BASE_URL:-}}" && -n "${NEURX_CODE_AGENT_MODEL:-${NEURX_LLM_MODEL:-}}" ]]
}

code_agent_call_model() {
  local user_prompt="$1"
  local base_url="${NEURX_CODE_AGENT_BASE_URL:-${NEURX_LLM_BASE_URL:-}}"
  local chat_path="${NEURX_CODE_AGENT_CHAT_PATH:-${NEURX_LLM_CHAT_PATH:-/v1/chat/completions}}"
  local model_name="${NEURX_CODE_AGENT_MODEL:-${NEURX_LLM_MODEL:-code-agent}}"
  local url
  url="$(code_agent_normalize_model_url "$base_url" "$chat_path")" || return 1
  command -v curl >/dev/null 2>&1 || return 1

  local payload
  payload="$(printf '{"model":"%s","messages":[{"role":"user","content":"%s"}],"max_tokens":4096}' \
    "$(code_agent_json_escape "$model_name")" \
    "$(code_agent_json_escape "$user_prompt")")"

  local curl_args=(-fS -X POST "$url" -H 'Content-Type: application/json' --data "$payload")
  if [[ -n "${NEURX_API_KEY:-}" ]]; then
    curl_args+=(-H "Authorization: Bearer ${NEURX_API_KEY}")
  fi

  # Log the request to stderr for terminal visibility
  printf -- '--- LLM Request ---\n' >&2
  printf 'URL: %s\n' "$url" >&2
  printf 'Model: %s\n' "$model_name" >&2

  local response
  # Use a temporary file to avoid subshell capture issues with large responses
  local tmp_resp
  tmp_resp=$(mktemp)
  if ! curl "${curl_args[@]}" >"$tmp_resp" 2>&1; then
    echo "LLM Error: $(cat "$tmp_resp")" >&2
    rm -f "$tmp_resp"
    return 1
  fi

  response=$(cat "$tmp_resp")
  rm -f "$tmp_resp"

  printf -- "--- LLM Response Captured (%d bytes) ---\n" "${#response}" >&2
  printf '%s' "$response"
}

code_agent_extract_model_text() {
  local response="$1"
  local content=""
  content="$(code_agent_extract_json_field "content" "$response")"
  if [[ -n "$content" ]]; then
    printf '%s' "$content"
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$response" | python3 -c '
import json,sys
try:
    data=json.load(sys.stdin)
except Exception:
    sys.exit(1)
choices=data.get("choices") or []
if choices:
    msg=choices[0].get("message") or {}
    text=msg.get("content") or choices[0].get("text") or ""
    if text:
        print(text, end="")
        sys.exit(0)
print(data.get("content",""), end="")
' 2>/dev/null && return 0
  fi
  return 1
}
