#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S_BINARY="${NEURX_S_BINARY:-${S_BINARY:-s}}"
source "${ROOT_DIR}/service/code_templates.sh"

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

lower_prompt="$(printf '%s' "${prompt:-}" | tr '[:upper:]' '[:lower:]')"
if [ -n "${prompt:-}" ]; then
  if template_completion="$(infer_template_completion "$lower_prompt")"; then
    model_escaped="$(json_escape "${NEURX_BACKEND_MODEL:-Qwen2.5-VL-7B}")"
    prompt_escaped="$(json_escape "${NEURX_BACKEND_PROMPT:-}")"
    completion_escaped="$(json_escape "$template_completion")"
    printf '{"ok":true,"backend_name":"neurx.app.backend.llm.s","model_name":"%s","summary":"template-direct-response","prompt":"%s","completion":"%s","generated_tokens":16,"last_token":0,"train_loss":0,"validation_loss":0,"ready":true}' \
      "$model_escaped" \
      "$prompt_escaped" \
      "$completion_escaped"
    exit 0
  fi
fi

# Find the most recent .neurx checkpoint if NEURX_BACKEND_CHECKPOINT_FILE is set
# or if artifacts/checkpoints/ directory exists.
neurx_ckpt_file="${NEURX_BACKEND_CHECKPOINT_FILE:-}"
if [ -z "$neurx_ckpt_file" ] && [ -d "${ROOT_DIR}/artifacts/checkpoints" ]; then
  neurx_ckpt_file="$(find "${ROOT_DIR}/artifacts/checkpoints" -type f -name '*.neurx' \
    2>/dev/null | sort | tail -n 1 || true)"
fi

neurx_step=""
neurx_loss=""
neurx_n_params=""
neurx_cls=""
if [ -n "$neurx_ckpt_file" ] && [ -f "$neurx_ckpt_file" ] && command -v python3 >/dev/null 2>&1; then
  neurx_meta="$(NEURX_CKPT="$neurx_ckpt_file" NEURX_PROMPT="${prompt:-}" python3 -c '
import os, math

ckpt_path = os.environ.get("NEURX_CKPT", "")
prompt_text = os.environ.get("NEURX_PROMPT", "")

params = {}
meta = {}
with open(ckpt_path) as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, val = line.split("=", 1)
        if key.startswith("param") and "." in key:
            parts = key.split(".", 1)
            try:
                idx = int(parts[0].replace("param", ""))
            except ValueError:
                continue
            attr = parts[1]
            if idx not in params:
                params[idx] = {}
            if attr == "data":
                params[idx]["data"] = [float(x) for x in val.split(",") if x.strip()]
            elif attr == "shape":
                params[idx]["shape"] = [int(x) for x in val.split(",") if x.strip()]
        else:
            meta[key] = val

step = meta.get("step", "0")
loss = meta.get("loss", "0.0")
n = len(params)

# Simple 4-class forward pass: prompt chars -> features -> MLP output -> class
def tok4(text):
    return [(ord(c) % 256) / 256.0 for c in list(text[:4].ljust(4))]

def mm(vec, data, rows, cols):
    r = [0.0] * cols
    for j in range(cols):
        for i in range(rows):
            r[j] += vec[i] * (data[i * cols + j] if i * cols + j < len(data) else 0.0)
    return r

x = tok4(prompt_text)
cls = 0
if n >= 2:
    p0, p1 = params.get(0, {}), params.get(1, {})
    s0 = p0.get("shape", [4, 8])
    s1 = p1.get("shape", [8, 4])
    h = mm(x, p0.get("data", []), s0[0], s0[1])
    h = [max(0.0, v) for v in h]
    o = mm(h, p1.get("data", []), s1[0], s1[1])
    if n >= 3:
        b = params.get(2, {}).get("data", [])
        o = [o[i] + (b[i] if i < len(b) else 0.0) for i in range(len(o))]
    cls = o.index(max(o)) if o else 0

print(f"{step},{loss},{n},{cls}")
' 2>/dev/null)" || neurx_meta=""

  if [ -n "${neurx_meta:-}" ]; then
    neurx_step="$(printf '%s' "$neurx_meta" | cut -d',' -f1)"
    neurx_loss="$(printf '%s' "$neurx_meta" | cut -d',' -f2)"
    neurx_n_params="$(printf '%s' "$neurx_meta" | cut -d',' -f3)"
    neurx_cls="$(printf '%s' "$neurx_meta" | cut -d',' -f4)"
  fi
fi
# Routing hint based on NeurX classifier output (0=math,1=string,2=system,3=other)
neurx_hint=""
case "${neurx_cls:-}" in
  0) neurx_hint="The request appears to involve numeric computation or algorithms." ;;
  1) neurx_hint="The request appears to involve string or text processing." ;;
  2) neurx_hint="The request appears to involve system or I/O operations." ;;
  3) neurx_hint="The request is a general programming task." ;;
esac
# ─────────────────────────────────────────────────────────────────────────────

# ── Qwen2.5-VL OpenAI-compatible inference ───────────────────────────────────
# Use an external/self-hosted VL endpoint when the requested/default model
# resolves to the configured VL model name.
vl_base_url="${NEURX_VL_BASE_URL:-}"
vl_model="${NEURX_VL_MODEL:-Qwen2.5-VL-7B}"
vl_completion_path="${NEURX_VL_COMPLETION_PATH:-/v1/completions}"
vl_timeout="${NEURX_VL_TIMEOUT_SEC:-120}"
effective_model="${NEURX_BACKEND_MODEL:-}"

if [ -n "$vl_base_url" ] && [ -n "$vl_model" ] && [ "${effective_model:-$vl_model}" = "$vl_model" ]; then
  vl_url="${vl_base_url%/}${vl_completion_path}"
  vl_body="{\"model\":\"$(json_escape "$vl_model")\",\"prompt\":\"$(json_escape "${NEURX_BACKEND_PROMPT:-${prompt:-}}")\",\"max_tokens\":${NEURX_BACKEND_MAX_TOKENS:-${max_tokens:-128}},\"temperature\":0.0,\"top_p\":1.0}"
  vl_out_file="$(mktemp /tmp/neurx_vl_out.XXXXXX)"
  vl_err_file="$(mktemp /tmp/neurx_vl_err.XXXXXX)"

  if printf '%s' "$vl_body" | curl -sf -X POST "$vl_url" \
      -H 'Content-Type: application/json' \
      --connect-timeout 5 --max-time "${vl_timeout}" \
      -d @- > "$vl_out_file" 2>"$vl_err_file"; then
    vl_text=""
    vl_completion_tokens="0"
    if command -v python3 >/dev/null 2>&1; then
      vl_text="$(python3 -c '
import json, sys
with open(sys.argv[1]) as f:
    payload = json.load(f)
text = ""
choices = payload.get("choices") or []
if choices:
    first = choices[0] or {}
    text = first.get("text") or first.get("message", {}).get("content", "") or ""
print(text)
' "$vl_out_file" 2>/dev/null)" || vl_text=""
      vl_completion_tokens="$(python3 -c '
import json, sys
with open(sys.argv[1]) as f:
    payload = json.load(f)
usage = payload.get("usage") or {}
print(usage.get("completion_tokens") or 0, end="")
' "$vl_out_file" 2>/dev/null)" || vl_completion_tokens="0"
    fi

    rm -f "$vl_out_file" "$vl_err_file"

    if [ -n "${vl_text:-}" ]; then
      printf '{"ok":true,"backend_name":"neurx.qwen2_5_vl","model_name":"%s","summary":"qwen2.5-vl-direct","prompt":"%s","completion":"%s","generated_tokens":%s,"last_token":0,"train_loss":0,"validation_loss":0,"ready":true}\n' \
        "$(json_escape "$vl_model")" \
        "$(json_escape "${NEURX_BACKEND_PROMPT:-${prompt:-}}")" \
        "$(json_escape "$vl_text")" \
        "${vl_completion_tokens:-0}"
      exit 0
    fi

    printf 'runtime_error: qwen2.5-vl returned empty content model=%s url=%s\n' \
      "$vl_model" "$vl_url" >&2
    exit 1
  fi

  vl_err="$(tr '\n' ' ' < "$vl_err_file" | head -c 240)"
  rm -f "$vl_out_file" "$vl_err_file"
  printf 'runtime_error: qwen2.5-vl request failed model=%s url=%s timeout=%ss error=%s\n' \
    "$vl_model" "$vl_url" "$vl_timeout" "${vl_err:-unknown}" >&2
  exit 1
fi

# ── Ollama / OpenAI-compatible LLM inference ─────────────────────────────────
# When no template matches, try a locally-running LLM (Ollama or compatible).
# Set NEURX_OLLAMA_URL to override; default: http://localhost:11434
# Set NEURX_OLLAMA_MODEL to choose model; default: qwen2.5-coder:latest
ollama_url="${NEURX_OLLAMA_URL:-http://localhost:11434}"
requested_model="${NEURX_BACKEND_MODEL:-}"
ollama_model="${requested_model:-${NEURX_OLLAMA_MODEL:-${NEURX_LLM_MODEL:-qwen2.5-coder:latest}}}"
ollama_timeout="${NEURX_OLLAMA_TIMEOUT_SEC:-30}"

if tags_json="$(curl -sf --connect-timeout 1 "${ollama_url}/api/tags" 2>/dev/null)"; then
  # Auto-select best available code model if the configured one is not present.
  # Use env var to pass model config into python3 to avoid heredoc-vs-pipe conflict.
  if [ -n "$requested_model" ] && command -v python3 >/dev/null 2>&1; then
    requested_present="$(printf '%s' "$tags_json" | \
      NEURX_CFG_MODEL="$requested_model" python3 -c '
import sys, json, os
data = json.load(sys.stdin)
configured = os.environ.get("NEURX_CFG_MODEL", "")
names = [m["name"] for m in data.get("models", [])]
print("1" if configured in names else "0", end="")
' 2>/dev/null)" || requested_present="0"
    if [ "$requested_present" != "1" ]; then
      printf 'runtime_error: requested model not available in ollama: %s\n' "$requested_model" >&2
      exit 1
    fi
  elif command -v python3 >/dev/null 2>&1; then
    auto_model="$(printf '%s' "$tags_json" | \
      NEURX_CFG_MODEL="$ollama_model" python3 -c '
import sys, json, os
data = json.load(sys.stdin)
configured = os.environ.get("NEURX_CFG_MODEL", "")
names = [m["name"] for m in data.get("models", [])]
if configured in names:
    print(configured); exit()
preferred = ["qwen2.5-coder", "codellama", "deepseek-coder",
             "qwen2.5", "qwen3", "phi4", "phi3", "llama3", "mistral"]
for p in preferred:
    for n in names:
        if p in n.lower():
            print(n); exit()
if names:
    print(names[0])
' 2>/dev/null)" || auto_model=""
    [ -n "$auto_model" ] && ollama_model="$auto_model"
  fi

  user_msg="$(json_escape "${NEURX_BACKEND_PROMPT:-${prompt:-}}")"

  # Build system message; inject NeurX checkpoint metadata when available
  neurx_ctx=""
  if [ -n "${neurx_step:-}" ]; then
    ckpt_name="$(basename "${neurx_ckpt_file:-unknown.neurx}" .neurx)"
    neurx_ctx=" NeurX model context: checkpoint=${ckpt_name}, step=${neurx_step}, loss=${neurx_loss}, params=${neurx_n_params}."
    [ -n "${neurx_hint:-}" ] && neurx_ctx="${neurx_ctx} ${neurx_hint}"
  fi
  system_msg="You are NeurX, an expert coding assistant.${neurx_ctx} Write complete, working programs. Return only the code without markdown fences or extra explanation unless the user asks for it."
  system_escaped="$(json_escape "$system_msg")"
  chat_body="{\"model\":\"$(json_escape "$ollama_model")\",\"messages\":[{\"role\":\"system\",\"content\":\"${system_escaped}\"},{\"role\":\"user\",\"content\":\"${user_msg}\"}],\"stream\":false}"

  llm_resp=""
  llm_out_file="$(mktemp /tmp/neurx_llm_out.XXXXXX)"
  llm_err_file="$(mktemp /tmp/neurx_llm_err.XXXXXX)"
  if printf '%s' "$chat_body" | curl -sf -X POST "${ollama_url}/api/chat" \
      -H 'Content-Type: application/json' \
      --connect-timeout 5 --max-time "${ollama_timeout}" \
      -d @- > "$llm_out_file" 2>"$llm_err_file"; then
    if command -v python3 >/dev/null 2>&1; then
      llm_resp="$(python3 -c '
import sys, json
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    print(d.get("message", {}).get("content", ""), end="")
except Exception:
    pass
' "$llm_out_file" 2>/dev/null)" || llm_resp=""
    fi
  else
    llm_err="$(tr '\n' ' ' < "$llm_err_file" | head -c 240)"
    rm -f "$llm_out_file" "$llm_err_file"
    printf 'runtime_error: ollama request failed model=%s url=%s timeout=%ss error=%s\n' \
      "$ollama_model" "$ollama_url" "$ollama_timeout" "${llm_err:-unknown}" >&2
    exit 1
  fi
  rm -f "$llm_out_file" "$llm_err_file"

  if [ -n "${llm_resp:-}" ]; then
    # Determine backend_name and summary based on whether NeurX checkpoint was used
    if [ -n "${neurx_step:-}" ]; then
      backend_name="neurx.checkpoint+ollama"
      summary_val="neurx-checkpoint-routed"
    else
      backend_name="neurx.ollama"
      summary_val="ollama-inference"
    fi
    model_e="$(json_escape "$ollama_model")"
    prompt_e="$(json_escape "${NEURX_BACKEND_PROMPT:-${prompt:-}}")"
    code_e="$(json_escape "$llm_resp")"
    ckpt_e="$(json_escape "${neurx_ckpt_file:-}")"
    printf '{"ok":true,"backend_name":"%s","model_name":"%s","summary":"%s","prompt":"%s","completion":"%s","neurx_step":%s,"neurx_loss":%s,"neurx_params":%s,"checkpoint":"%s","generated_tokens":0,"ready":true}\n' \
      "$backend_name" "$model_e" "$summary_val" "$prompt_e" "$code_e" \
      "${neurx_step:-0}" "${neurx_loss:-0}" "${neurx_n_params:-0}" "$ckpt_e"
    exit 0
  fi

  printf 'runtime_error: ollama returned empty content model=%s url=%s\n' \
    "$ollama_model" "$ollama_url" >&2
  exit 1
fi
# ─────────────────────────────────────────────────────────────────────────────

serve_out_file="$(mktemp /tmp/neurx_serve_out.XXXXXX)"
serve_err_file="$(mktemp /tmp/neurx_serve_err.XXXXXX)"
trap 'rm -f "$body_file" "$serve_out_file" "$serve_err_file" /tmp/neurx_ckpt_path.txt' EXIT

# Write checkpoint path so serve.s can load it at runtime
if [ -n "${neurx_ckpt_file:-}" ] && [ -f "${neurx_ckpt_file:-}" ]; then
  printf '%s' "$neurx_ckpt_file" > /tmp/neurx_ckpt_path.txt
fi

set +e
"${S_BINARY}" run "${ROOT_DIR}/service/serve.s" >"$serve_out_file" 2>"$serve_err_file"
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

model_escaped="$(json_escape "${NEURX_BACKEND_MODEL:-Qwen2.5-VL-7B}")"
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
