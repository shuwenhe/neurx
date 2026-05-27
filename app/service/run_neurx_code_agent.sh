#!/usr/bin/env bash
# NeurX code agent: repo-scoped coding loop (bash runtime) with optional S IR binary.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TOOLS_DIR="${SCRIPT_DIR}/tools"

# shellcheck source=code_agent_model_api.sh
source "${SCRIPT_DIR}/code_agent_model_api.sh"

PROMPT=""
REPO_ROOT=""
FILE_PATH=""
BUILD_COMMAND=""
TEST_COMMAND=""
JSON_MODE=0
MAX_STEPS="${NEURX_CODE_AGENT_STEPS:-16}"
PREFER_S_RUNTIME="${NEURX_CODE_AGENT_PREFER_S_RUNTIME:-0}"

S_COMPILER="${S_COMPILER:-${NEURX_S_COMPILER:-}}"
if [[ -z "$S_COMPILER" ]]; then
  if [[ -x "${NEURX_ROOT}/../s/bin/s" ]]; then
    S_COMPILER="${NEURX_ROOT}/../s/bin/s"
  elif command -v s >/dev/null 2>&1; then
    S_COMPILER="$(command -v s)"
  fi
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt) PROMPT="${2:-}"; shift 2 ;;
    --repo) REPO_ROOT="${2:-}"; shift 2 ;;
    --file) FILE_PATH="${2:-}"; shift 2 ;;
    --build-command) BUILD_COMMAND="${2:-}"; shift 2 ;;
    --test-command) TEST_COMMAND="${2:-}"; shift 2 ;;
    --max-steps) MAX_STEPS="${2:-16}"; shift 2 ;;
    --json) JSON_MODE=1; shift ;;
    *) shift ;;
  esac
done

[[ -z "$REPO_ROOT" ]] && REPO_ROOT="$NEURX_ROOT"
REPO_ROOT="${REPO_ROOT%/}"
[[ -n "$PROMPT" ]] || { echo "error: --prompt is required" >&2; exit 2; }

BIN_DIR="${NEURX_ROOT}/build/bin"
AGENT_BIN="${BIN_DIR}/neurx_code_agent"
REPORT_FILE="${NEURX_ROOT}/build/code_agent/last_report.txt"
LOG_FILE="${NEURX_ROOT}/build/code_agent/last_run.log"
mkdir -p "${BIN_DIR}" "${NEURX_ROOT}/build/code_agent"

try_build_s_agent() {
  [[ -n "$S_COMPILER" && -x "$S_COMPILER" ]] || return 1
  if [[ ! -x "$AGENT_BIN" ]] || [[ "agent/code_agent.s" -nt "$AGENT_BIN" ]]; then
    echo "building neurx_code_agent (S IR launcher)..." >&2
    if ! "$S_COMPILER" build "${NEURX_ROOT}/agent/code_agent.s" -o "$AGENT_BIN" 2>/dev/null; then
      return 1
    fi
  fi
  [[ -x "$AGENT_BIN" ]]
}

run_s_code_agent() {
  export NEURX_CODE_AGENT_TASK="$PROMPT"
  export NEURX_CODE_AGENT_STEPS="$MAX_STEPS"
  export NEURX_CODE_AGENT_FULL_AUTO="${NEURX_CODE_AGENT_FULL_AUTO:-1}"
  export NEURX_AGENT_WORKSPACE_ROOT="$REPO_ROOT"
  export NEURX_CODE_AGENT_REPORT="$REPORT_FILE"
  [[ -n "$BUILD_COMMAND" ]] && export NEURX_CODE_AGENT_BUILD_COMMAND="$BUILD_COMMAND"
  [[ -n "$TEST_COMMAND" ]] && export NEURX_CODE_AGENT_TEST_COMMAND="$TEST_COMMAND"
  "$AGENT_BIN" 2>&1 | tee "$LOG_FILE"
}

repo_rel_path() {
  local path="$1"
  if [[ "$path" == "$REPO_ROOT"/* ]]; then
    printf '%s' "${path#"$REPO_ROOT"/}"
    return 0
  fi
  printf '%s' "$path"
}

safe_repo_path() {
  local path="${1:-}"
  [[ -z "$path" ]] && return 1
  # Clean markdown backticks and trim whitespace
  path="$(printf '%s' "$path" | sed -e 's/[`]//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [[ -z "$path" ]] && return 1
  [[ "$path" == *".."* ]] && return 1

  local rel="$path"
  # 1. If already absolute and within REPO_ROOT
  if [[ "$rel" == "$REPO_ROOT"* ]]; then
    printf '%s' "$rel"
    return 0
  fi

  # 2. Deep correction for common LLM path hallucinations
  # Strip leading / if any
  rel="${rel#/}"

  # Dynamically strip REPO_ROOT components if they appear at the start
  local repo_stripped="${REPO_ROOT#/}"
  if [[ -n "$repo_stripped" ]] && [[ "$rel" == "$repo_stripped"* ]]; then
    rel="${rel#"$repo_stripped"}"
    rel="${rel#/}"
  fi

  # Fallback for known hardcoded variations
  rel="${rel#home/shuwen/shuwen/neurx/}"
  rel="${rel#home/shuwen/shuwen/ne_readx/}"
  rel="${rel#neurx/}"
  rel="${rel#ne_readx/}"
  rel="${rel#/}"

  # 构造最终绝对路径
  local abs="${REPO_ROOT}/${rel}"

  # 只要最终路径在 REPO_ROOT 范围内即可
  if [[ "$abs" == "$REPO_ROOT"* ]]; then
    printf '%s' "$abs"
    return 0
  fi
  return 1
}

run_bash_code_agent() {
  local step=0
  local status="completed"
  local response=""
  local summary_lines=()
  local action_results_json="[]"
  local changed_paths=()

  step=$((step + 1))
  local git_status=""
  git_status="$(cd "$REPO_ROOT" && git status -sb 2>/dev/null || echo "git unavailable")"
  summary_lines+=("step${step}=git_status ok")

  step=$((step + 1))
  local repo_layout=""
  repo_layout="$(cd "$REPO_ROOT" && ls -1 | head -n 40 | tr '\n' ' ')"
  summary_lines+=("step${step}=repo layout captured")

  local file_context=""
  if [[ -n "$FILE_PATH" ]]; then
    step=$((step + 1))
    local abs_file
    if abs_file="$(safe_repo_path "$FILE_PATH")"; then
      file_context="$(bash "${TOOLS_DIR}/read.sh" "$abs_file" 1 160 2>/dev/null || true)"
      summary_lines+=("step${step}=read_file $(repo_rel_path "$abs_file")")
    else
      summary_lines+=("step${step}=read_file skipped (path not allowed)")
    fi
  fi

  step=$((step + 1))
  local search_hits=""
  local query
  query="$(printf '%s' "$PROMPT" | tr '[:space:]' '\n' | awk 'length($0)>=4 {print; exit}')"
  if [[ -n "$query" ]]; then
    search_hits="$(bash "${TOOLS_DIR}/search.sh" "$query" "$REPO_ROOT" 2>/dev/null | head -n 20 || true)"
    summary_lines+=("step${step}=search_files query=${query}")
  else
    summary_lines+=("step${step}=search_files skipped")
  fi

  if code_agent_model_configured; then
    step=$((step + 1))
    local model_prompt=""
    model_prompt="$(cat <<EOF
You are a repository code agent for NeurX. Complete the user task by proposing concrete file edits.

User task:
${PROMPT}

Repository root: ${REPO_ROOT}
Git status:
${git_status}

Top-level layout:
${repo_layout}

Target file context:
${file_context:-none}

Search hits:
${search_hits:-none}

Respond with EXACTLY this format (no markdown fences):
FILE: <relative-path-from-repo-root>
CONTENT:
<full new file content>
EOF
)"
    local model_raw model_text target_rel target_abs
    if model_raw="$(code_agent_call_model "$model_prompt")"; then
      if model_text="$(code_agent_extract_model_text "$model_raw")"; then
        # Robustly extract FILE: path, handle case insensitivity and possible markdown backticks
        target_rel="$(printf '%s' "$model_text" | grep -i "FILE:" | head -n 1 | sed -e 's/.*FILE:[[:space:]]*//i' -e 's/[`]//g' | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

        if [[ -n "$target_rel" ]] && target_abs="$(safe_repo_path "$target_rel")"; then
          local new_content
          # Extract everything after CONTENT: (case-insensitive)
          new_content="$(printf '%s' "$model_text" | sed -e '1,/^[[:space:]]*CONTENT:/Id')"

          # If content starts with a code block fence, try to strip it for a cleaner write
          if [[ "$new_content" =~ ^[[:space:]]*\`{3,} ]]; then
             if command -v python3 >/dev/null 2>&1; then
                new_content="$(printf '%s' "$new_content" | python3 -c "
import sys, re
c = sys.stdin.read()
# Try to match a fenced block
m = re.search(r'^\s*\`{3,}(?:\w+)?\n(.*?)\n\`{3,}', c, re.DOTALL | re.MULTILINE)
if m:
    print(m.group(1), end='')
else:
    # Otherwise just strip the starting fence and any trailing ones
    c = re.sub(r'^\s*\`{3,}(?:\w+)?\n', '', c)
    c = re.sub(r'\n\`{3,}\s*$', '', c)
    print(c, end='')
" 2>/dev/null || printf '%s' "$new_content")"
             fi
          fi

          if [[ -n "$new_content" ]]; then
            # 自动创建父目录 (这是创建新文件的关键)
            mkdir -p "$(dirname "$target_abs")"
            printf '%s' "$new_content" | bash "${TOOLS_DIR}/write.sh" "$target_abs"
            changed_paths+=("$(repo_rel_path "$target_abs")")
            summary_lines+=("step${step}=write_file ${target_rel} ok")
            response="Wrote ${target_rel} from model output."
          else
            summary_lines+=("step${step}=model missing CONTENT")
            response="Model provided FILE but no CONTENT block."
          fi
        else
          summary_lines+=("step${step}=model bad path ${target_rel:-none}")
          response="$model_text"
        fi
      else
        summary_lines+=("step${step}=model parse error")
        response="Failed to parse JSON content from model."
      fi
    else
      status="failed"
      summary_lines+=("step${step}=model call failed")
      response="Model backend call failed (check stderr for curl errors)."
    fi
  else
    response="Code agent inspected the repository (git status, layout, search)."
    response="${response}

No LLM endpoint configured. Set NEURX_CODE_AGENT_BASE_URL, NEURX_CODE_AGENT_MODEL, and NEURX_API_KEY to enable automatic edits."
    summary_lines+=("model=disabled")
  fi

  local build_cmd="${BUILD_COMMAND:-${NEURX_CODE_AGENT_BUILD_COMMAND:-make s-package-index}}"
  if [[ -n "$build_cmd" ]]; then
    step=$((step + 1))
    local build_out=""
    if build_out="$(bash "${TOOLS_DIR}/build.sh" "$REPO_ROOT" "$build_cmd" 2>&1)"; then
      summary_lines+=("step${step}=run_build ok")
      response="${response}

Build OK:
$(printf '%s' "$build_out" | tail -n 12)"
    else
      status="failed"
      summary_lines+=("step${step}=run_build failed")
      response="${response}

Build FAILED:
$(printf '%s' "$build_out" | tail -n 24)"
    fi
  fi

  local test_cmd="${TEST_COMMAND:-${NEURX_CODE_AGENT_TEST_COMMAND:-}}"
  if [[ -n "$test_cmd" ]]; then
    step=$((step + 1))
    local test_out=""
    if test_out="$(bash "${TOOLS_DIR}/test.sh" "$REPO_ROOT" "$test_cmd" 2>&1)"; then
      summary_lines+=("step${step}=run_test ok")
    else
      status="failed"
      summary_lines+=("step${step}=run_test failed")
      response="${response}

Test FAILED:
$(printf '%s' "$test_out" | tail -n 24)"
    fi
  fi

  local git_diff=""
  git_diff="$(cd "$REPO_ROOT" && git diff --stat HEAD 2>/dev/null || true)"

  {
    echo "[meta]"
    echo "status=${status}"
    echo "steps=${step}"
    echo "max_steps=${MAX_STEPS}"
    echo ""
    echo "[response]"
    echo "$response"
    echo ""
    echo "[summary]"
    printf '%s\n' "${summary_lines[@]}"
    echo ""
    if [[ -n "$git_diff" ]]; then
      echo "[git_diff_stat]"
      echo "$git_diff"
    fi
  } >"$REPORT_FILE"

  if [[ "$JSON_MODE" -eq 1 ]]; then
  local changed_json="[]"
  if [[ ${#changed_paths[@]} -gt 0 ]]; then
    changed_json="["
    local cp
    for cp in "${changed_paths[@]}"; do
      changed_json+="$(printf '"%s",' "$(code_agent_json_escape "$cp")")"
    done
    changed_json="${changed_json%,}]"
  fi
  local envelope_status="completed"
  [[ "$status" == "completed" ]] || envelope_status="failed"
  local result_json
  result_json="$(printf '{"ok":%s,"tool":"run_code_agent","summary":"%s","output":"%s","changed_paths":%s,"requires_approval":false}' \
    "$( [[ "$envelope_status" == "completed" ]] && printf true || printf false )" \
    "$(code_agent_json_escape "$(printf '%s' "${summary_lines[*]}")")" \
    "$(code_agent_json_escape "$response")" \
    "$changed_json")"
  printf '{"protocol_version":"neurx.code_agent.v1","status":"%s","mode":"bash-runtime","summary":"%s","response":"%s","plan":"git_status -> repo -> retrieve -> code -> build -> test","file_context":"%s","actions":[],"action_results":[%s],"prompt":"%s","file_path":"%s","repo_root":"%s"}\n' \
    "$envelope_status" \
    "$(code_agent_json_escape "$(printf '%s\n' "${summary_lines[@]}")")" \
    "$(code_agent_json_escape "$response")" \
    "$(code_agent_json_escape "$file_context")" \
    "$result_json" \
    "$(code_agent_json_escape "$PROMPT")" \
    "$(code_agent_json_escape "$FILE_PATH")" \
    "$(code_agent_json_escape "$REPO_ROOT")"
  fi

  [[ "$status" == "completed" ]]
}

agent_exit=0
if [[ "$PREFER_S_RUNTIME" == "1" ]] && try_build_s_agent; then
  set +e
  run_s_code_agent
  agent_exit=$?
  set -e
else
  set +e
  run_bash_code_agent
  agent_exit=$?
  set -e
fi

exit "$agent_exit"
