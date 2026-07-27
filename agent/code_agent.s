package neurx.agent.code_agent
use neurx.agent.runtime
use neurx.agent.memory
use neurx.runtime.io.{runtime_env_get, runtime_run_command_output, runtime_write_text_file}
func code_agent_default_step_budget() int {
    64
}

func code_agent_resolve_model_path() string {
    string mp = trim(runtime_env_get("NEURX_AGENT_MODEL_PATH", ""))
    if mp != "" {
        return mp
    }
    string endpoint_url = trim(runtime_env_get("NEURX_CODE_AGENT_BASE_URL", runtime_env_get("NEURX_LLM_BASE_URL", runtime_env_get("NEURX_REMOTE_BASE_URL", ""))))
    string endpoint_model = trim(runtime_env_get("NEURX_CODE_AGENT_MODEL", runtime_env_get("NEURX_LLM_MODEL", runtime_env_get("NEURX_REMOTE_MODEL", ""))))
    string endpoint_path = trim(runtime_env_get("NEURX_CODE_AGENT_CHAT_PATH", runtime_env_get("NEURX_LLM_CHAT_PATH", runtime_env_get("NEURX_REMOTE_CHAT_PATH", "/v1/chat/completions"))))
    string endpoint_backend = trim(runtime_env_get("NEURX_CODE_AGENT_BACKEND", runtime_env_get("NEURX_LLM_BACKEND", "remote")))
    if endpoint_url != "" && endpoint_model != "" && endpoint_backend != "" {
        return "backend=remote url=" + endpoint_url + " model=" + endpoint_model + " path=" + endpoint_path
    }
    mp = trim(runtime_env_get("NEURX_AGENT_CHECKPOINT_FILE", ""))
    if mp != "" {
        return mp
    }
    mp = trim(runtime_env_get("NEURX_BACKEND_CHECKPOINT_FILE", ""))
    if mp != "" {
        return mp
    }
    ""
}

func code_agent_parse_int(string s, int default_val) int {
    string trimmed = trim(s)
    if trimmed == "" {
        return default_val
    }
    int result = 0
    int i = 0
    bool valid = true
    while i < len(trimmed) {
        string ch = string(trimmed[i])
        if ch == "0" {
            result = result * 10 + 0
        } else if ch == "1" {
            result = result * 10 + 1
        } else if ch == "2" {
            result = result * 10 + 2
        } else if ch == "3" {
            result = result * 10 + 3
        } else if ch == "4" {
            result = result * 10 + 4
        } else if ch == "5" {
            result = result * 10 + 5
        } else if ch == "6" {
            result = result * 10 + 6
        } else if ch == "7" {
            result = result * 10 + 7
        } else if ch == "8" {
            result = result * 10 + 8
        } else if ch == "9" {
            result = result * 10 + 9
        } else {
            valid = false
            break
        }
        i = i + 1
    }
    if !valid || result <= 0 {
        return default_val
    }
    result
}

func code_agent_clip(string s, int max_len) string {
    if len(s) <= max_len {
        return s
    }
    string out = ""
    int i = 0
    while i < max_len {
        out = out + string(s[i])
        i = i + 1
    }
    out + "..."
}

func code_agent_pending_count(agent_runtime_state state) int {
    agent_memory_lookup_result r = agent_memory_lookup_short(state.memory, "pending_change_count")
    if !r.found || trim(r.value) == "" {
        return 0
    }
    code_agent_parse_int(r.value, 0)
}

func code_agent_read_line() string {
    trim(runtime_run_command_output("head -1 /dev/stdin 2>/dev/null"))
}

func code_agent_read_stdin() string {
    trim(runtime_run_command_output("cat /dev/stdin 2>/dev/null"))
}

func code_agent_step_label(string action, string observation) string {
    string obs_short = ""
    int max_obs = 120
    if len(observation) <= max_obs {
        obs_short = observation
    } else {
        int i = 0
        while i < max_obs {
            obs_short = obs_short + string(observation[i])
            i = i + 1
        }
        obs_short = obs_short + "..."
    }
    "action=" + action + " obs=" + obs_short
}

func code_agent_find(string text, string pattern, int start) int {
    int tl = len(text)
    int pl = len(pattern)
    if pl <= 0 {
        return start
    }
    if tl < pl || start > tl - pl {
        return -1
    }
    int i = start
    while i <= tl - pl {
        int j = 0
        bool match = true
        while j < pl {
            if text[i + j] != pattern[j] {
                match = false
                break
            }
            j = j + 1
        }
        if match {
            return i
        }
        i = i + 1
    }
    -1
}

func code_agent_starts_with(string text, string prefix) bool {
    if len(prefix) > len(text) {
        return false
    }
    int i = 0
    while i < len(prefix) {
        if text[i] != prefix[i] {
            return false
        }
        i = i + 1
    }
    true
}

func code_agent_extract_trailing_field(string observation, string marker) string {
    int pos = code_agent_find(observation, marker, 0)
    if pos < 0 {
        return ""
    }
    int start = pos + len(marker)
    string out = ""
    int i = start
    while i < len(observation) {
        out = out + string(observation[i])
        i = i + 1
    }
    trim(out)
}

func code_agent_slice(string text, int start, int end) string {
    int lo = start
    int hi = end
    if lo < 0 {
        lo = 0
    }
    if hi < lo {
        hi = lo
    }
    if hi > len(text) {
        hi = len(text)
    }
    string out = ""
    int i = lo
    while i < hi {
        out = out + string(text[i])
        i = i + 1
    }
    out
}

func code_agent_shell_escape(string text) string {
    string out = "'"
    int i = 0
    while i < len(text) {
        string ch = string(text[i])
        if ch == "'" {
            out = out + "'\"'\"'"
        } else {
            out = out + ch
        }
        i = i + 1
    }
    out + "'"
}

func code_agent_normalize_command_text(string task) string {
    string trimmed = trim(task)
    if code_agent_starts_with(trimmed, "```") {
        int first_nl = code_agent_find(trimmed, "\n", 0)
        int last_ticks = code_agent_find(trimmed, "```", 3)
        if first_nl >= 0 && last_ticks > first_nl {
            return trim(code_agent_slice(trimmed, first_nl + 1, last_ticks))
        }
    }
    trimmed
}

func code_agent_resolve_task_path(string rel_path) string {
    string root = trim(runtime_env_get("NEURX_AGENT_WORKSPACE_ROOT", "."))
    string abs_path = rel_path
    if !code_agent_starts_with(rel_path, "/") {
        if root == "" || root == "." {
            abs_path = rel_path
        } else if code_agent_starts_with(root, "/") {
            if code_agent_starts_with(rel_path, "./") {
                abs_path = root + "/" + code_agent_slice(rel_path, 2, len(rel_path))
            } else {
                abs_path = root + "/" + rel_path
            }
        }
    }
    abs_path
}

func code_agent_fast_path_touch_file(string task) string {
    string command = code_agent_normalize_command_text(task)
    string lowered = lower(command)
    string prefix = "touch "
    if !code_agent_starts_with(lowered, prefix) {
        return ""
    }
    string raw_path = trim(code_agent_slice(command, len(prefix), len(command)))
    if raw_path == "" {
        return ""
    }
    string abs_path = code_agent_resolve_task_path(raw_path)
    runtime_run_command_output("mkdir -p $(dirname " + code_agent_shell_escape(abs_path) + ") && : > " + code_agent_shell_escape(abs_path))
    string verify = trim(runtime_run_command_output("test -f " + code_agent_shell_escape(abs_path) + " && printf ok"))
    if verify == "ok" {
        return "created_file path=" + abs_path
    }
    "create_file_failed path=" + abs_path
}

func code_agent_fast_path_create_file(string task) string {
    string trimmed = code_agent_normalize_command_text(task)
    string lowered = lower(trimmed)
    string prefix = "create file "
    string mid = " with content "
    if !code_agent_starts_with(lowered, prefix) {
        return ""
    }
    int mid_pos = code_agent_find(lowered, mid, len(prefix))
    if mid_pos < 0 {
        return ""
    }
    string rel_path = trim(code_agent_slice(trimmed, len(prefix), mid_pos))
    string content = code_agent_slice(trimmed, mid_pos + len(mid), len(trimmed))
    if rel_path == "" {
        return ""
    }
    string abs_path = code_agent_resolve_task_path(rel_path)
    runtime_run_command_output("mkdir -p $(dirname " + code_agent_shell_escape(abs_path) + ") && printf %s " + code_agent_shell_escape(content) + " > " + code_agent_shell_escape(abs_path))
    string verify = trim(runtime_run_command_output("test -f " + code_agent_shell_escape(abs_path) + " && printf ok"))
    if verify == "ok" {
        return "created_file path=" + abs_path
    }
    "create_file_failed path=" + abs_path
}

func code_agent_print_terminal_log(string action, string observation) () {
    string output = code_agent_extract_trailing_field(observation, ";output_summary=")
    if output == "" {
        output = code_agent_extract_trailing_field(observation, ";output=")
    }
    if output == "" {
        return
    }
    println("[code_agent] ── terminal ", action, " ─────────────────────────")
    println(output)
}

func code_agent_print_step(int step, string action, string observation) {
    println("[code_agent] step=", string(step), " ", code_agent_step_label(action, observation))
    code_agent_print_terminal_log(action, observation)
}

func code_agent_resolve_build_command() string {
    trim(runtime_env_get("NEURX_CODE_AGENT_BUILD_COMMAND", runtime_env_get("NEURX_AGENT_BUILD_COMMAND", "")))
}

func code_agent_resolve_test_command() string {
    trim(runtime_env_get("NEURX_CODE_AGENT_TEST_COMMAND", runtime_env_get("NEURX_AGENT_TEST_COMMAND", "")))
}

func code_agent_extract_response(agent_runtime_state state) string {
    agent_memory_lookup_result fa = agent_memory_lookup_long(state.memory, "final_answer")
    if fa.found && trim(fa.value) != "" {
        return fa.value
    }
    agent_memory_lookup_result gen = agent_memory_lookup_long(state.memory, "generated_code")
    if gen.found && trim(gen.value) != "" {
        return gen.value
    }
    state.last_observation
}

func code_agent_run_status(agent_runtime_state state, int steps_done, int max_steps) string {
    if state.finished {
        return "completed"
    }
    if steps_done >= max_steps {
        return "exhausted"
    }
    if agent_runtime_is_stalled(state) {
        return "stalled"
    }
    "running"
}

func code_agent_write_report(agent_runtime_state state, string path, string task, int steps_done, int max_steps) () {
    if trim(path) == "" {
        return
    }
    string status = code_agent_run_status(state, steps_done, max_steps)
    string response = code_agent_extract_response(state)
    string root = trim(runtime_env_get("NEURX_AGENT_WORKSPACE_ROOT", "."))
    string diff = trim(runtime_run_command_output("cd " + root + " && git diff --stat HEAD 2>/dev/null"))
    string report = "[meta]\n"
    report = report + "status=" + status + "\n"
    report = report + "steps=" + string(steps_done) + "\n"
    report = report + "max_steps=" + string(max_steps) + "\n"
    report = report + "agent_status=" + state.plan.status + "\n"
    report = report + "step_count=" + string(state.steps) + "\n"
    report = report + "task=" + task + "\n\n"
    report = report + "[response]\n" + response + "\n\n"
    report = report + "[summary]\n" + agent_runtime_summary(state) + "\n\n"
    if diff != "" {
        report = report + "[git_diff_stat]\n" + diff + "\n"
    }
    runtime_write_text_file(path, report)
}

func code_agent_run(string task, string model_path, int max_steps, bool full_auto, string build_command, string test_command) agent_runtime_state {
    agent_runtime_state state = new_code_agent_runtime_state_with_model(task, max_steps, model_path, build_command, test_command)
    int steps_done = 0
    agent_runtime_state current = state
    while !current.finished && steps_done < max_steps {
        if current.interrupt.pending && full_auto {
            current = agent_runtime_step(current, "yes")
            steps_done = steps_done + 1
            code_agent_print_step(steps_done, current.last_action, current.last_observation)
            int pending = code_agent_pending_count(current)
            if pending > 0 {
                current = agent_runtime_step_with_task(current, "apply_pending_changes", "apply pending changes")
                steps_done = steps_done + 1
                code_agent_print_step(steps_done, current.last_action, current.last_observation)
            }
        } else if current.interrupt.pending && !full_auto {
            println("[code_agent] ── approval required ───────────────────────")
            println("[code_agent]   action : ", current.interrupt.kind)
            println("[code_agent]   reason : ", current.interrupt.reason)
            println("[code_agent] approve? [yes/no]: ")
            string answer = code_agent_read_line()
            if trim(answer) == "" {
                answer = "no"
            }
            current = agent_runtime_step(current, answer)
            steps_done = steps_done + 1
            code_agent_print_step(steps_done, current.last_action, current.last_observation)
            string al = lower(trim(answer))
            if al == "yes" || al == "y" {
                int pending2 = code_agent_pending_count(current)
                if pending2 > 0 {
                    current = agent_runtime_step_with_task(current, "apply_pending_changes", "apply pending changes")
                    steps_done = steps_done + 1
                    code_agent_print_step(steps_done, current.last_action, current.last_observation)
                }
            }
        } else {
            current = agent_runtime_step(current, task)
            steps_done = steps_done + 1
            code_agent_print_step(steps_done, current.last_action, current.last_observation)
        }
        if !agent_subagent_all_done(current.subagents) {
            current = agent_runtime_run_pending_subagents(current)
        }
        if agent_runtime_is_stalled(current) {
            println("[code_agent] stalled after ", string(steps_done), " steps — action=", current.last_action)
            return current
        }
    }
    if current.finished {
        println("[code_agent] finished after ", string(steps_done), " steps")
    } else {
        println("[code_agent] step_budget_exhausted steps=", string(steps_done))
    }
    current
}

func code_agent_print_git_diff() {
    string root = trim(runtime_env_get("NEURX_AGENT_WORKSPACE_ROOT", "."))
    string diff = trim(runtime_run_command_output("cd " + root + " && git diff --stat HEAD 2>/dev/null"))
    if diff != "" {
        println("[code_agent] ── git diff --stat ──────────────────────────────")
        println(diff)
    }
}

func code_agent_print_answer(agent_runtime_state state) {
    agent_memory_lookup_result fa = agent_memory_lookup_long(state.memory, "final_answer")
    if fa.found && trim(fa.value) != "" {
        println("[code_agent] ── answer ─────────────────────────────────────")
        println(fa.value)
        return
    }
    agent_memory_lookup_result gen = agent_memory_lookup_long(state.memory, "generated_code")
    if gen.found && trim(gen.value) != "" {
        println("[code_agent] ── generated_code ──────────────────────────────")
        println(gen.value)
        return
    }
    println("[code_agent] last_observation: ", state.last_observation)
}

func main() int {
    string task = trim(runtime_env_get("NEURX_CODE_AGENT_TASK", ""))
    if task == "" {
        task = code_agent_read_stdin()
    }
    if task == "" {
        println("[code_agent] error: no task provided.")
        println("[code_agent]   Set NEURX_CODE_AGENT_TASK=\"...\" or pipe via stdin:")
        println("[code_agent]   echo \"fix the build error\" | neurx_code_agent")
        return 1
    }
    string model_path  = code_agent_resolve_model_path()
    int max_steps      = code_agent_parse_int(runtime_env_get("NEURX_CODE_AGENT_STEPS", ""), code_agent_default_step_budget())
    string fa_env      = trim(runtime_env_get("NEURX_CODE_AGENT_FULL_AUTO", "1"))
    bool full_auto     = fa_env == "1" || lower(fa_env) == "true" || lower(fa_env) == "yes"
    println("[code_agent] ── code agent ────────────────────────────────────")
    println("[code_agent] task      : ", task)
    if model_path != "" {
        println("[code_agent] model     : ", code_agent_clip(model_path, 80))
    } else {
        println("[code_agent] model     : (none — LLM inference disabled)")
    }
    println("[code_agent] max_steps : ", string(max_steps))
    println("[code_agent] full_auto : ", string(full_auto))
    println("[code_agent] workspace : ", trim(runtime_env_get("NEURX_AGENT_WORKSPACE_ROOT", ".")))
    println("[code_agent] ─────────────────────────────────────────────────")
    string touch_path_result = code_agent_fast_path_touch_file(task)
    if touch_path_result != "" {
        println("[code_agent] fast_path : ", touch_path_result)
        return 0
    }
    string fast_path_result = code_agent_fast_path_create_file(task)
    if fast_path_result != "" {
        println("[code_agent] fast_path : ", fast_path_result)
        return 0
    }
    string build_command = code_agent_resolve_build_command()
    string test_command = code_agent_resolve_test_command()
    string report_path = trim(runtime_env_get("NEURX_CODE_AGENT_REPORT", ""))
    agent_runtime_state result = code_agent_run(task, model_path, max_steps, full_auto, build_command, test_command)
    int steps_done = result.steps
    if report_path != "" {
        code_agent_write_report(result, report_path, task, steps_done, max_steps)
    }
    code_agent_print_git_diff()
    code_agent_print_answer(result)
    0
}
