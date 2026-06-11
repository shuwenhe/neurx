#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TASK_LIBRARY_DIR="${SCRIPT_DIR}/task_library"
TASK_LIBRARY="${TASK_LIBRARY_DIR}/tasks.tsv"
VALIDATOR_DIR="${TASK_LIBRARY_DIR}/validators"
source "${SCRIPT_DIR}/code_templates.sh"

PROMPT=""
FILE_PATH=""
REPO_ROOT=""
MODEL_LOOP_ENABLED="${NEURX_CODE_AGENT_ENABLE_MODEL_LOOP:-0}"
MODEL_BASE_URL="${NEURX_CODE_AGENT_BASE_URL:-${NEURX_LLM_BASE_URL:-}}"
MODEL_PATH="${NEURX_CODE_AGENT_CHAT_PATH:-${NEURX_LLM_CHAT_PATH:-/v1/chat/completions}}"
MODEL_NAME="${NEURX_CODE_AGENT_MODEL:-${NEURX_LLM_MODEL:-}}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)
      PROMPT="${2:-}"
      shift 2
      ;;
    --file)
      FILE_PATH="${2:-}"
      shift 2
      ;;
    --repo)
      REPO_ROOT="${2:-}"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

json_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

emit_json() {
  local status="$1"
  local mode="$2"
  local response="$3"
  local plan="$4"
  local file_context="${5:-}"
  printf '{"status":"%s","mode":"%s","response":"%s","plan":"%s","file_context":"%s","prompt":"%s","file_path":"%s","repo_root":"%s"}' \
    "$(json_escape "$status")" \
    "$(json_escape "$mode")" \
    "$(json_escape "$response")" \
    "$(json_escape "$plan")" \
    "$(json_escape "$file_context")" \
    "$(json_escape "$PROMPT")" \
    "$(json_escape "$FILE_PATH")" \
    "$(json_escape "$REPO_ROOT")"
}

emit_envelope() {
  local status="$1"
  local mode="$2"
  local response="$3"
  local plan="$4"
  local file_context="${5:-}"
  local summary="${6:-}"
  local actions_json="${7:-[]}"
  local action_results_json="${8:-[]}"
  printf '{"protocol_version":"neurx.code_agent.v1","status":"%s","mode":"%s","summary":"%s","response":"%s","plan":"%s","file_context":"%s","actions":%s,"action_results":%s,"prompt":"%s","file_path":"%s","repo_root":"%s"}' \
    "$(json_escape "$status")" \
    "$(json_escape "$mode")" \
    "$(json_escape "$summary")" \
    "$(json_escape "$response")" \
    "$(json_escape "$plan")" \
    "$(json_escape "$file_context")" \
    "$actions_json" \
    "$action_results_json" \
    "$(json_escape "$PROMPT")" \
    "$(json_escape "$FILE_PATH")" \
    "$(json_escape "$REPO_ROOT")"
}

build_action_json() {
  local tool="$1"
  local args_json="${2:-{}}"
  local summary="${3:-}"
  local requires_approval="${4:-false}"
  printf '%s' '{"tool":"'
  printf '%s' "$(json_escape "$tool")"
  printf '%s' '","args":'
  printf '%s' "$args_json"
  printf '%s' ',"summary":"'
  printf '%s' "$(json_escape "$summary")"
  printf '%s' '","requires_approval":'
  printf '%s' "$requires_approval"
  printf '%s' '}'
}

build_action_result_json() {
  local ok="$1"
  local tool="$2"
  local summary="${3:-}"
  local output="${4:-}"
  local changed_paths_json="${5:-[]}"
  local requires_approval="${6:-false}"
  printf '%s' '{"ok":'
  printf '%s' "$ok"
  printf '%s' ',"tool":"'
  printf '%s' "$(json_escape "$tool")"
  printf '%s' '","summary":"'
  printf '%s' "$(json_escape "$summary")"
  printf '%s' '","output":"'
  printf '%s' "$(json_escape "$output")"
  printf '%s' '","changed_paths":'
  printf '%s' "$changed_paths_json"
  printf '%s' ',"requires_approval":'
  printf '%s' "$requires_approval"
  printf '%s' '}'
}

model_loop_enabled() {
  [[ "$MODEL_LOOP_ENABLED" == "1" || "$MODEL_LOOP_ENABLED" == "true" || "$MODEL_LOOP_ENABLED" == "yes" ]]
}

runtime_loop_enabled() {
  [[ "${NEURX_CODE_AGENT_USE_RUNTIME:-0}" == "1" || "${NEURX_CODE_AGENT_USE_RUNTIME:-}" == "true" || "${NEURX_CODE_AGENT_USE_RUNTIME:-}" == "yes" ]]
}

prompt_wants_repo_agent() {
  local text
  text="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
  if [[ "$text" == *"sum"* || "$text" == *"fibonacci"* || "$text" == *"factorial"* || "$text" == *"prime"* ]]; then
    return 1
  fi
  [[ "$text" == *"fix "* || "$text" == *"fix the"* || "$text" == *"bug"* \
    || "$text" == *"build fail"* || "$text" == *"compile error"* || "$text" == *"test fail"* \
    || "$text" == *"refactor"* || "$text" == *"implement"* || "$text" == *"patch"* \
    || "$text" == *"create "* || "$text" == *"write to"* || "$text" == *"save to"* \
    || "$text" == *"创建"* || "$text" == *"写入"* || "$text" == *"文件"* \
    || "$text" == *"in this repo"* || "$text" == *"in the repo"* || "$text" == *"workspace"* \
    || "$text" == *"codebase"* || "$text" == *"neurx"* ]]
}

run_neurx_runtime_agent() {
  local runner="${SCRIPT_DIR}/run_neurx_code_agent.sh"
  if [[ ! -f "$runner" ]]; then
    return 1
  fi
  chmod +x "$runner" 2>/dev/null || true
  local repo="${REPO_ROOT:-$ROOT_DIR}"
  bash "$runner" \
    --json \
    --prompt "$PROMPT" \
    --repo "$repo" \
    ${FILE_PATH:+--file "$FILE_PATH"} \
    ${NEURX_CODE_AGENT_BUILD_COMMAND:+--build-command "$NEURX_CODE_AGENT_BUILD_COMMAND"} \
    ${NEURX_CODE_AGENT_TEST_COMMAND:+--test-command "$NEURX_CODE_AGENT_TEST_COMMAND"}
}

task_supports_language() {
  local languages_csv="$1"
  local language="$2"
  local candidate=""
  while IFS= read -r candidate || [[ -n "$candidate" ]]; do
    if [[ "$candidate" == "$language" ]]; then
      return 0
    fi
  done < <(printf '%s' "$languages_csv" | tr ',' '\n')
  return 1
}

task_matches() {
  local text="$1"
  local task_id="$2"
  local line=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    local row_task_id=""
    local row_languages=""
    local row_terms=""
    local row_validator=""
    local row_priority=""
    local row_mode=""
    IFS='|' read -r row_task_id row_languages row_terms row_validator row_priority row_mode <<< "$line"
    if [[ "$row_task_id" != "$task_id" ]]; then
      continue
    fi
    if [[ "$row_terms" == "extract_sum_upper_bound" ]]; then
      extract_sum_upper_bound "$text" >/dev/null 2>&1
      return $?
    fi
    local term=""
    while IFS= read -r term || [[ -n "$term" ]]; do
      [[ -z "$term" ]] && continue
      if [[ "$text" == *"$term"* ]]; then
        return 0
      fi
    done < <(printf '%s' "$row_terms" | tr ',' '\n')
    return 1
  done < "$TASK_LIBRARY"
  return 1
}

task_enabled() {
  local task_id="$1"
  local language="$2"
  local line=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    local row_task_id=""
    local row_languages=""
    local row_terms=""
    local row_validator=""
    local row_priority=""
    local row_mode=""
    IFS='|' read -r row_task_id row_languages row_terms row_validator row_priority row_mode <<< "$line"
    if [[ "$row_task_id" != "$task_id" ]]; then
      continue
    fi
    task_supports_language "$row_languages" "$language"
    return $?
  done < "$TASK_LIBRARY"
  return 1
}

task_field() {
  local task_id="$1"
  local field_name="$2"
  local line=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    local row_task_id=""
    local row_languages=""
    local row_terms=""
    local row_validator=""
    local row_priority=""
    local row_mode=""
    IFS='|' read -r row_task_id row_languages row_terms row_validator row_priority row_mode <<< "$line"
    if [[ "$row_task_id" != "$task_id" ]]; then
      continue
    fi
    case "$field_name" in
      validator) printf '%s' "$row_validator" ;;
      priority) printf '%s' "$row_priority" ;;
      mode) printf '%s' "$row_mode" ;;
    esac
    return 0
  done < "$TASK_LIBRARY"
  return 1
}

detect_language() {
  local text="$1"
  if contains_any "$text" "c++" "cpp"; then
    echo "cpp"
    return 0
  fi
  if [[ "$text" == *"python"* ]]; then
    echo "python"
    return 0
  fi
  if contains_any "$text" "javascript" "js"; then
    echo "javascript"
    return 0
  fi
  if [[ "$text" == *"go"* ]]; then
    echo "go"
    return 0
  fi
  return 1
}

extract_sum_upper_bound() {
  local text="$1"
  if [[ "$text" =~ 1\+2\+3\+.*\+([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "$text" =~ 1到([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "$text" =~ 1到([0-9]+)求和 ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "$text" =~ sum[[:space:]]+1\.\.([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

build_cpp_sum_program() {
  local upper_bound="$1"
  cat <<EOF
#include <iostream>

int main() {
    int sum = 0;
    for (int i = 1; i <= ${upper_bound}; ++i) {
        sum += i;
    }
    std::cout << sum << std::endl;
    return 0;
}
EOF
}

build_python_sum_program() {
  local upper_bound="$1"
  cat <<EOF
sum_value = 0
for i in range(1, ${upper_bound} + 1):
    sum_value += i

print(sum_value)
EOF
}

build_js_sum_program() {
  local upper_bound="$1"
  cat <<EOF
let sum = 0;
for (let i = 1; i <= ${upper_bound}; i += 1) {
  sum += i;
}
console.log(sum);
EOF
}

build_go_sum_program() {
  local upper_bound="$1"
  cat <<EOF
package main

import "fmt"

func main() {
    sum := 0
    for i := 1; i <= ${upper_bound}; i++ {
        sum += i
    }
    fmt.Println(sum)
}
EOF
}

build_cpp_fibonacci_program() {
  cat <<'EOF'
#include <iostream>

int main() {
    int n = 0;
    std::cin >> n;
    if (n <= 0) {
        std::cout << 0 << std::endl;
        return 0;
    }
    int a = 0;
    int b = 1;
    for (int i = 1; i < n; ++i) {
        int next = a + b;
        a = b;
        b = next;
    }
    std::cout << b << std::endl;
    return 0;
}
EOF
}

build_python_fibonacci_program() {
  cat <<'EOF'
n = int(input().strip())
if n <= 0:
    print(0)
else:
    a, b = 0, 1
    for _ in range(1, n):
        a, b = b, a + b
    print(b)
EOF
}

build_cpp_prime_program() {
  cat <<'EOF'
#include <iostream>

int main() {
    int n = 0;
    std::cin >> n;
    if (n < 2) {
        std::cout << "not prime" << std::endl;
        return 0;
    }
    for (int i = 2; i * i <= n; ++i) {
        if (n % i == 0) {
            std::cout << "not prime" << std::endl;
            return 0;
        }
    }
    std::cout << "prime" << std::endl;
    return 0;
}
EOF
}

build_python_prime_program() {
  cat <<'EOF'
n = int(input().strip())
if n < 2:
    print("not prime")
else:
    is_prime = True
    i = 2
    while i * i <= n:
        if n % i == 0:
            is_prime = False
            break
        i += 1
    print("prime" if is_prime else "not prime")
EOF
}

build_cpp_max_program() {
  cat <<'EOF'
#include <iostream>

int main() {
    int values[] = {3, 7, 2, 9, 4};
    int max_value = values[0];
    for (int value : values) {
        if (value > max_value) {
            max_value = value;
        }
    }
    std::cout << max_value << std::endl;
    return 0;
}
EOF
}

build_python_max_program() {
  cat <<'EOF'
values = [3, 7, 2, 9, 4]
print(max(values))
EOF
}

build_js_even_odd_program() {
  cat <<'EOF'
const fs = require("fs");
const input = fs.readFileSync(0, "utf8").trim();
const value = Number(input);

if (value % 2 === 0) {
  console.log("even");
} else {
  console.log("odd");
}
EOF
}

build_go_even_odd_program() {
  cat <<'EOF'
package main

import "fmt"

func main() {
    var value int
    fmt.Scan(&value)
    if value%2 == 0 {
        fmt.Println("even")
    } else {
        fmt.Println("odd")
    }
}
EOF
}

build_js_reverse_string_program() {
  cat <<'EOF'
const fs = require("fs");
const text = fs.readFileSync(0, "utf8").trimEnd();
console.log(text.split("").reverse().join(""));
EOF
}

build_go_reverse_string_program() {
  cat <<'EOF'
package main

import (
    "bufio"
    "fmt"
    "os"
)

func main() {
    reader := bufio.NewReader(os.Stdin)
    text, _ := reader.ReadString('\n')
    runes := []rune(text)
    for i, j := 0, len(runes)-1; i < j; i, j = i+1, j-1 {
        runes[i], runes[j] = runes[j], runes[i]
    }
    fmt.Print(string(runes))
}
EOF
}

repair_cpp_program() {
  local code="$1"
  local repaired="$code"

  if [[ "$repaired" == *"std::string"* ]] && [[ "$repaired" != *"#include <string>"* ]]; then
    repaired="#include <string>"$'\n'"${repaired}"
  fi
  if [[ "$repaired" == *"std::reverse"* ]] && [[ "$repaired" != *"#include <algorithm>"* ]]; then
    repaired="#include <algorithm>"$'\n'"${repaired}"
  fi
  if [[ "$repaired" == *"std::vector"* ]] && [[ "$repaired" != *"#include <vector>"* ]]; then
    repaired="#include <vector>"$'\n'"${repaired}"
  fi

  printf '%s' "$repaired"
}

validate_cpp_program() {
  local code="$1"
  local tmp_dir
  tmp_dir="$(mktemp -d /tmp/neurx_cpp_validate.XXXXXX)"
  printf '%s\n' "$code" > "${tmp_dir}/main.cpp"
  if bash "${VALIDATOR_DIR}/validate_cpp.sh" "${tmp_dir}/main.cpp" "${tmp_dir}/main" >/dev/null 2>&1; then
    rm -rf "$tmp_dir"
    return 0
  fi
  rm -rf "$tmp_dir"
  return 1
}

validate_python_program() {
  local code="$1"
  local tmp_dir
  tmp_dir="$(mktemp -d /tmp/neurx_python_validate.XXXXXX)"
  printf '%s\n' "$code" > "${tmp_dir}/main.py"
  if bash "${VALIDATOR_DIR}/validate_python.sh" "${tmp_dir}/main.py" >/dev/null 2>&1; then
    rm -rf "$tmp_dir"
    return 0
  fi
  rm -rf "$tmp_dir"
  return 1
}

validate_javascript_program() {
  local code="$1"
  local tmp_dir
  tmp_dir="$(mktemp -d /tmp/neurx_js_validate.XXXXXX)"
  printf '%s\n' "$code" > "${tmp_dir}/main.js"
  if bash "${VALIDATOR_DIR}/validate_javascript.sh" "${tmp_dir}/main.js" >/dev/null 2>&1; then
    rm -rf "$tmp_dir"
    return 0
  fi
  rm -rf "$tmp_dir"
  return 1
}

validate_go_program() {
  local code="$1"
  local tmp_dir
  tmp_dir="$(mktemp -d /tmp/neurx_go_validate.XXXXXX)"
  printf '%s\n' "$code" > "${tmp_dir}/main.go"
  if bash "${VALIDATOR_DIR}/validate_go.sh" "${tmp_dir}/main.go" >/dev/null 2>&1; then
    rm -rf "$tmp_dir"
    return 0
  fi
  rm -rf "$tmp_dir"
  return 1
}

validate_cpp_program_verbose() {
  local code="$1"
  local tmp_dir
  tmp_dir="$(mktemp -d /tmp/neurx_cpp_verbose.XXXXXX)"
  printf '%s\n' "$code" > "${tmp_dir}/main.cpp"
  if ! command -v g++ >/dev/null 2>&1; then
    rm -rf "$tmp_dir"
    return 0
  fi
  local output
  output="$(g++ "${tmp_dir}/main.cpp" -o "${tmp_dir}/main" 2>&1)" || {
    printf '%s' "$output"
    rm -rf "$tmp_dir"
    return 1
  }
  rm -rf "$tmp_dir"
  return 0
}

normalize_model_url() {
  local base="${1:-}"
  local path="${2:-}"
  [[ -z "$base" ]] && return 1
  base="${base%/}"
  if [[ "$path" != /* ]]; then
    path="/$path"
  fi
  printf '%s%s' "$base" "$path"
}

extract_json_field() {
  local key="$1"
  local text="$2"
  printf '%s' "$text" | sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -n 1
}

call_model_backend() {
  local user_prompt="$1"
  local url=""
  url="$(normalize_model_url "$MODEL_BASE_URL" "$MODEL_PATH")" || return 1
  local model="${MODEL_NAME:-code-agent}"
  local payload
  payload="$(printf '{"model":"%s","prompt":"%s","max_tokens":512}' \
    "$(json_escape "$model")" \
    "$(json_escape "$user_prompt")")"
  curl -fsS -X POST "$url" \
    -H 'Content-Type: application/json' \
    --data "$payload"
}

extract_model_content() {
  local response="$1"
  local content=""
  content="$(extract_json_field "content" "$response")"
  if [[ -z "$content" ]]; then
    content="$(extract_json_field "completion" "$response")"
  fi
  printf '%b' "${content//\\n/$'\n'}"
}

looks_like_placeholder_model_output() {
  local text="$1"
  [[ "$text" == *"当前由本地 S 后端链路处理"* ]] \
    || [[ "$text" == *"已收到你的请求"* ]] \
    || [[ "$text" == *"S backend is alive and responding"* ]]
}

build_model_generation_prompt() {
  local language="$1"
  local task_prompt="$2"
  cat <<EOF
You are a coding agent. Generate a complete standalone ${language} program.
Requirements:
- return code only
- do not include markdown fences
- prefer the minimal correct solution
- if input is required, read from standard input
- if output is required, print only the answer

User request:
${task_prompt}
EOF
}

build_model_repair_prompt() {
  local language="$1"
  local task_prompt="$2"
  local code="$3"
  local validation_error="$4"
  cat <<EOF
You are repairing a standalone ${language} program.
Return corrected code only, with no markdown fences.

Original request:
${task_prompt}

Current code:
${code}

Compiler or validator error:
${validation_error}
EOF
}

generate_with_model_loop() {
  local language="$1"
  local task_prompt="$2"
  model_loop_enabled || return 1
  command -v curl >/dev/null 2>&1 || return 1

  local response=""
  local code=""
  response="$(call_model_backend "$(build_model_generation_prompt "$language" "$task_prompt")")" || return 1
  code="$(extract_model_content "$response")"
  [[ -z "$code" ]] && return 1
  looks_like_placeholder_model_output "$code" && return 1

  if [[ "$language" == "cpp" ]]; then
    if validate_cpp_program "$code"; then
      printf '%s' "$code"
      return 0
    fi
    local compile_error=""
    compile_error="$(validate_cpp_program_verbose "$code" || true)"
    response="$(call_model_backend "$(build_model_repair_prompt "$language" "$task_prompt" "$code" "$compile_error")")" || return 1
    code="$(extract_model_content "$response")"
    [[ -z "$code" ]] && return 1
    if validate_cpp_program "$code"; then
      printf '%s' "$code"
      return 0
    fi
    return 1
  fi

  if [[ "$language" == "python" ]] && validate_python_program "$code"; then
    printf '%s' "$code"
    return 0
  fi
  if [[ "$language" == "javascript" ]] && validate_javascript_program "$code"; then
    printf '%s' "$code"
    return 0
  fi
  if [[ "$language" == "go" ]] && validate_go_program "$code"; then
    printf '%s' "$code"
    return 0
  fi

  return 1
}

synthesize_small_program() {
  local text="$1"
  local language="$2"
  local upper_bound=""

  if task_enabled "sum_series" "$language" && upper_bound="$(extract_sum_upper_bound "$text")"; then
    if [[ "$language" == "cpp" ]]; then
      build_cpp_sum_program "$upper_bound"
      return 0
    fi
    if [[ "$language" == "python" ]]; then
      build_python_sum_program "$upper_bound"
      return 0
    fi
    if [[ "$language" == "javascript" ]]; then
      build_js_sum_program "$upper_bound"
      return 0
    fi
    if [[ "$language" == "go" ]]; then
      build_go_sum_program "$upper_bound"
      return 0
    fi
  fi

  if task_enabled "even_odd" "$language" && task_matches "$text" "even_odd"; then
    if [[ "$language" == "cpp" ]]; then
      cat <<'EOF'
#include <iostream>

int main() {
    int value = 0;
    std::cin >> value;
    if (value % 2 == 0) {
        std::cout << "even" << std::endl;
    } else {
        std::cout << "odd" << std::endl;
    }
    return 0;
}
EOF
      return 0
    fi
    if [[ "$language" == "python" ]]; then
      cat <<'EOF'
value = int(input().strip())
if value % 2 == 0:
    print("even")
else:
    print("odd")
EOF
      return 0
    fi
    if [[ "$language" == "javascript" ]]; then
      build_js_even_odd_program
      return 0
    fi
    if [[ "$language" == "go" ]]; then
      build_go_even_odd_program
      return 0
    fi
  fi

  if task_enabled "array_sum" "$language" && task_matches "$text" "array_sum"; then
    if [[ "$language" == "cpp" ]]; then
      cat <<'EOF'
#include <iostream>

int main() {
    int values[] = {1, 2, 3, 4, 5};
    int sum = 0;
    for (int value : values) {
        sum += value;
    }
    std::cout << sum << std::endl;
    return 0;
}
EOF
      return 0
    fi
    if [[ "$language" == "python" ]]; then
      cat <<'EOF'
values = [1, 2, 3, 4, 5]
print(sum(values))
EOF
      return 0
    fi
  fi

  if task_enabled "reverse_string" "$language" && task_matches "$text" "reverse_string"; then
    if [[ "$language" == "cpp" ]]; then
      cat <<'EOF'
#include <algorithm>
#include <iostream>
#include <string>

int main() {
    std::string text;
    std::getline(std::cin, text);
    std::reverse(text.begin(), text.end());
    std::cout << text << std::endl;
    return 0;
}
EOF
      return 0
    fi
    if [[ "$language" == "python" ]]; then
      cat <<'EOF'
text = input()
print(text[::-1])
EOF
      return 0
    fi
    if [[ "$language" == "javascript" ]]; then
      build_js_reverse_string_program
      return 0
    fi
    if [[ "$language" == "go" ]]; then
      build_go_reverse_string_program
      return 0
    fi
  fi

  if task_enabled "fibonacci" "$language" && task_matches "$text" "fibonacci"; then
    if [[ "$language" == "cpp" ]]; then
      build_cpp_fibonacci_program
      return 0
    fi
    if [[ "$language" == "python" ]]; then
      build_python_fibonacci_program
      return 0
    fi
  fi

  if task_enabled "prime_check" "$language" && task_matches "$text" "prime_check"; then
    if [[ "$language" == "cpp" ]]; then
      build_cpp_prime_program
      return 0
    fi
    if [[ "$language" == "python" ]]; then
      build_python_prime_program
      return 0
    fi
  fi

  if task_enabled "max_value" "$language" && task_matches "$text" "max_value"; then
    if [[ "$language" == "cpp" ]]; then
      build_cpp_max_program
      return 0
    fi
    if [[ "$language" == "python" ]]; then
      build_python_max_program
      return 0
    fi
  fi

  if task_enabled "factorial_function" "$language" && task_matches "$text" "factorial_function"; then
      if [[ "$language" == "cpp" ]]; then
        cat <<'EOF'
#include <iostream>

int factorial(int n) {
    if (n <= 1) {
        return 1;
    }
    return n * factorial(n - 1);
}

int main() {
    int n = 0;
    std::cin >> n;
    std::cout << factorial(n) << std::endl;
    return 0;
}
EOF
        return 0
      fi
      if [[ "$language" == "python" ]]; then
        cat <<'EOF'
def factorial(n: int) -> int:
    if n <= 1:
        return 1
    return n * factorial(n - 1)


n = int(input().strip())
print(factorial(n))
EOF
        return 0
      fi
  fi

  return 1
}

lower_prompt="$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')"

should_run_runtime=0
runtime_required=0
if runtime_loop_enabled; then
  should_run_runtime=1
  runtime_required=1
elif [[ "${NEURX_CODE_AGENT_AUTO_RUNTIME:-1}" == "1" ]] && prompt_wants_repo_agent "$lower_prompt"; then
  should_run_runtime=1
  runtime_required=1
fi

if [[ "$should_run_runtime" -eq 1 ]]; then
  runtime_json="$(run_neurx_runtime_agent 2>&1 || true)"
  if [[ -n "$runtime_json" && "$runtime_json" == \{* ]]; then
    printf '%s\n' "$runtime_json"
    exit 0
  fi
  if [[ "$runtime_required" -eq 1 ]]; then
    runtime_summary="S runtime agent failed before producing a JSON envelope."
    runtime_response="$runtime_json"
    if [[ -z "$runtime_response" ]]; then
      runtime_response="runtime agent returned no output"
    fi
    action_result_json="$(build_action_result_json "false" "run_neurx_runtime_agent" "$runtime_summary" "$runtime_response" "[]" "false")"
    emit_envelope "failed" "runtime" "$runtime_response" "git_status -> repo -> retrieve -> code -> build -> test" "" "$runtime_summary" "[]" "[$action_result_json]"
    exit 0
  fi
fi

if template_completion="$(infer_template_completion "$lower_prompt")"; then
  completed_summary="Matched a local code template and returned it directly."
  action_result_json="$(build_action_result_json "true" "generate_completion" "$completed_summary" "$template_completion" "[]" "false")"
  emit_envelope "completed" "template" "$template_completion" "Matched a local code template and returned it directly." "" "$completed_summary" "[]" "[$action_result_json]"
  exit 0
fi

language=""
if language="$(detect_language "$lower_prompt")"; then
  synthesized_code=""
  if synthesized_code="$(synthesize_small_program "$lower_prompt" "$language")"; then
    if [[ "$language" == "cpp" ]]; then
      validated_code="$synthesized_code"
      if ! validate_cpp_program "$validated_code"; then
        validated_code="$(repair_cpp_program "$validated_code")"
      fi
      if validate_cpp_program "$validated_code"; then
        completed_summary="Synthesized a C++ standalone program and validated it with g++."
        action_result_json="$(build_action_result_json "true" "generate_completion" "$completed_summary" "$validated_code" "[]" "false")"
        emit_envelope "completed" "synthesized-cpp" "$validated_code" "Synthesized a C++ standalone program and validated it with g++." "" "$completed_summary" "[]" "[$action_result_json]"
        exit 0
      fi
    fi
    if [[ "$language" == "python" ]] && validate_python_program "$synthesized_code"; then
      completed_summary="Synthesized a Python standalone program and validated it with python3 -m py_compile."
      action_result_json="$(build_action_result_json "true" "generate_completion" "$completed_summary" "$synthesized_code" "[]" "false")"
      emit_envelope "completed" "synthesized-python" "$synthesized_code" "Synthesized a Python standalone program and validated it with python3 -m py_compile." "" "$completed_summary" "[]" "[$action_result_json]"
      exit 0
    fi
    if [[ "$language" == "javascript" ]] && validate_javascript_program "$synthesized_code"; then
      completed_summary="Synthesized a JavaScript standalone program and validated it with node --check."
      action_result_json="$(build_action_result_json "true" "generate_completion" "$completed_summary" "$synthesized_code" "[]" "false")"
      emit_envelope "completed" "synthesized-javascript" "$synthesized_code" "Synthesized a JavaScript standalone program and validated it with node --check." "" "$completed_summary" "[]" "[$action_result_json]"
      exit 0
    fi
    if [[ "$language" == "go" ]] && validate_go_program "$synthesized_code"; then
      completed_summary="Synthesized a Go standalone program and validated it with go build."
      action_result_json="$(build_action_result_json "true" "generate_completion" "$completed_summary" "$synthesized_code" "[]" "false")"
      emit_envelope "completed" "synthesized-go" "$synthesized_code" "Synthesized a Go standalone program and validated it with go build." "" "$completed_summary" "[]" "[$action_result_json]"
      exit 0
    fi
  fi

  model_code=""
  if model_code="$(generate_with_model_loop "$language" "$PROMPT")"; then
    completed_summary="Generated code with the model loop and validated it locally."
    action_result_json="$(build_action_result_json "true" "generate_completion" "$completed_summary" "$model_code" "[]" "false")"
    emit_envelope "completed" "model-loop-${language}" "$model_code" "Generated code with the model loop and validated it locally." "" "$completed_summary" "[]" "[$action_result_json]"
    exit 0
  fi
fi

file_context=""
if [[ -n "$FILE_PATH" && -f "$FILE_PATH" ]]; then
  file_context="$(bash "${SCRIPT_DIR}/tools/read.sh" "$FILE_PATH" 1 120 2>/dev/null || true)"
fi

plan="1. Inspect workspace context. 2. Read target files. 3. Ask model for code or patch. 4. Apply changes. 5. Build and test. 6. Repair failures."
actions_json="[]"
if [[ -n "$FILE_PATH" ]]; then
  actions_json="$(printf '[{"tool":"read_file","args":{"path":"%s","start_line":1,"line_count":120},"summary":"Read the target file before proposing edits.","requires_approval":false}]' \
    "$(json_escape "$FILE_PATH")")"
fi
summary="Runner delegated the request to the bridge planner and attached the first suggested actions."
emit_envelope "unhandled" "planner" "" "$plan" "$file_context" "$summary" "$actions_json" "[]"
