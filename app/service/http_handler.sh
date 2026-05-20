#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_inference() {
  echo "[inference] $*" >&2
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

extract_json_string() {
  local key="$1"
  local text="$2"
  printf '%s' "$text" | sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1
}

extract_json_int() {
  local key="$1"
  local text="$2"
  printf '%s' "$text" | sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p" | head -n 1
}

send_response() {
  local status="$1"
  local body="$2"
  local length
  length="$(printf '%s' "$body" | wc -c | tr -d '[:space:]')"
  printf 'HTTP/1.1 %s\r\n' "$status"
  printf 'Content-Type: application/json; charset=utf-8\r\n'
  printf 'Cache-Control: no-store\r\n'
  printf 'Access-Control-Allow-Origin: *\r\n'
  printf 'Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n'
  printf 'Access-Control-Allow-Headers: Content-Type\r\n'
  printf 'Content-Length: %s\r\n' "$length"
  printf 'Connection: close\r\n\r\n'
  printf '%s' "$body"
}

read_request() {
  local req_line=""
  if ! IFS= read -r req_line; then
    return 1
  fi

  req_line="${req_line%$'\r'}"
  METHOD="${req_line%% *}"
  local rest="${req_line#* }"
  PATH_ONLY="${rest%% *}"

  CONTENT_LENGTH=0
  while IFS= read -r line; do
    line="${line%$'\r'}"
    [[ -z "$line" ]] && break
    case "${line,,}" in
      content-length:*)
        local value="${line#*:}"
        value="${value//[[:space:]]/}"
        if [[ "$value" =~ ^[0-9]+$ ]]; then
          CONTENT_LENGTH="$value"
        fi
        ;;
    esac
  done

  REQUEST_BODY=""
  if [[ "$CONTENT_LENGTH" -gt 0 ]]; then
    IFS= read -r -N "$CONTENT_LENGTH" REQUEST_BODY || true
  fi
  return 0
}

handle_health() {
  local body
  body='{"ok":true,"service":"neurx-app-backend","version":"1.0.0","backend":"s-gateway","path":"/neurx/api/chat"}'
  send_response "200 OK" "$body"
}

handle_models() {
  local checkpoint_file="${NEURX_BACKEND_CHECKPOINT_FILE:-}"
  local checkpoint_root="${NEURX_BACKEND_CHECKPOINT_ROOT:-}"
  local body
  body="{\"checkpoint_root\":\"$(json_escape "$checkpoint_root")\",\"models\":[{\"label\":\"$(json_escape "$checkpoint_file")\",\"value\":\"$(json_escape "$checkpoint_file")\"}]}"
  send_response "200 OK" "$body"
}

handle_chat() {
  local model prompt max_tokens req_json response err_text
  local gateway_path serve_path
  model="$(extract_json_string model "$REQUEST_BODY")"
  prompt="$(extract_json_string prompt "$REQUEST_BODY")"
  if [[ -z "$prompt" ]]; then
    local content
    content="$(extract_json_string content "$REQUEST_BODY")"
    if [[ -n "$content" ]]; then
      prompt="user: $content"
    fi
  fi
  max_tokens="$(extract_json_int max_tokens "$REQUEST_BODY")"
  [[ -z "$model" ]] && model="${NEURX_BACKEND_MODEL:-gpt_large}"
  [[ -z "$prompt" ]] && prompt="Please provide your request."
  [[ -z "$max_tokens" ]] && max_tokens="16"

  req_json="{\"model\":\"$(json_escape "$model")\",\"prompt\":\"$(json_escape "$prompt")\",\"max_tokens\":${max_tokens}}"
  gateway_path="${ROOT_DIR}/gateway.sh"
  serve_path="${ROOT_DIR}/serve.s"

  log_inference "chat.start model=${model} prompt_len=${#prompt} max_tokens=${max_tokens}"
  log_inference "chat.code_path handler=${ROOT_DIR}/http_handler.sh gateway=${gateway_path} serve=${serve_path}"

  local err_file
  err_file="$(mktemp /tmp/neurx_gateway_err.XXXXXX)"
  if response="$(printf '%s' "$req_json" | "${ROOT_DIR}/gateway.sh" 2>"$err_file")"; then
    log_inference "chat.done model=${model} bytes=${#response}"
    send_response "200 OK" "$response"
  else
    err_text="$(cat "$err_file")"
    log_inference "chat.error error=$(printf '%s' "$err_text" | tr '\n' ' ' | head -c 240)"
    send_response "500 Internal Server Error" "{\"ok\":false,\"error\":\"$(json_escape "$err_text")\"}"
  fi
  rm -f "$err_file"
}

handle_agent_suggest() {
  local prompt file_name suggestion
  prompt="$(extract_json_string prompt "$REQUEST_BODY")"
  file_name="$(extract_json_string filePath "$REQUEST_BODY")"
  if [[ "$prompt" == *"serving a local checkpoint snapshot"* ]] || [[ "$prompt" == *"token_trace="* ]]; then
    suggestion="这是 checkpoint 调试快照，不应直接作为回答正文。请保持回答简洁，把 checkpoint、token_trace、stage_signature 等内容写入 make app 的 inference 日志。"
  elif [[ -n "$file_name" ]]; then
    suggestion="已收到问题。建议先在 ${file_name} 中定位报错上下文并最小改动修复，再复测。"
  elif [[ -n "$prompt" ]]; then
    suggestion="已收到问题：${prompt}。建议补充报错与目标行为，我会给出可执行修改步骤。"
  else
    suggestion="已收到代码助手请求，请补充具体报错或目标行为。"
  fi
  log_inference "agent.suggest.done summary=$(printf '%s' "$suggestion" | head -c 120)"
  send_response "200 OK" "{\"ok\":true,\"suggestion\":\"$(json_escape "$suggestion")\"}"
}

METHOD=""
PATH_ONLY=""
CONTENT_LENGTH=0
REQUEST_BODY=""

if ! read_request; then
  exit 0
fi

case "$METHOD $PATH_ONLY" in
  "OPTIONS "*)
    send_response "204 No Content" ""
    ;;
  "GET /health"|"GET /neurx/health")
    handle_health
    ;;
  "GET /api/models"|"GET /neurx/api/models")
    handle_models
    ;;
  "POST /neurx/api/chat"|"POST /v1/chat/completions")
    handle_chat
    ;;
  "POST /neurx/api/agent/suggest")
    handle_agent_suggest
    ;;
  *)
    send_response "404 Not Found" "{\"ok\":false,\"error\":\"not found\",\"path\":\"$(json_escape "$PATH_ONLY")\"}"
    ;;
esac
