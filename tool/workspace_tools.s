package neurx.agent.workspace_tools

use neurx.runtime.io.{runtime_env_get, runtime_read_text_file, runtime_write_text_file, runtime_file_exists, runtime_run_command}

struct agent_workspace_result {
    bool ok
    string observation
    string resolved_path
}

struct agent_workspace_command_result {
    bool ok
    string command
    string observation
}

struct agent_workspace_patch_result {
    bool ok
    string observation
    string resolved_path
    int replacements
}

func agent_workspace_root() string {
    string root = trim(runtime_env_get("NEURX_AGENT_WORKSPACE_ROOT", "."))
    if root == "" {
        return "."
    }
    root
}

func agent_workspace_text_contains(string text, string pattern) bool {
    string haystack = lower(trim(text))
    string needle = lower(trim(pattern))
    int hay_len = len(haystack)
    int nee_len = len(needle)
    if nee_len <= 0 {
        return true
    }
    if hay_len < nee_len {
        return false
    }
    int i = 0
    while i <= hay_len - nee_len {
        int j = 0
        bool match = true
        while j < nee_len {
            if haystack[i + j] != needle[j] {
                match = false
                break
            }
            j = j + 1
        }
        if match {
            return true
        }
        i = i + 1
    }
    false
}

func agent_workspace_starts_with(string text, string prefix) bool {
    int tl = len(text)
    int pl = len(prefix)
    if pl > tl {
        return false
    }
    int i = 0
    while i < pl {
        if text[i] != prefix[i] {
            return false
        }
        i = i + 1
    }
    true
}

func agent_workspace_join_path(string root, string path) string {
    if path == "" {
        return root
    }
    if agent_workspace_starts_with(path, "/") {
        return path
    }
    if root == "." {
        return path
    }
    if string(root[len(root) - 1]) == "/" {
        return root + path
    }
    root + "/" + path
}

func agent_workspace_path_allowed(string path) bool {
    string trimmed = trim(path)
    if trimmed == "" {
        return false
    }
    if agent_workspace_text_contains(trimmed, "..") {
        return false
    }
    true
}

func agent_workspace_resolve_path(string path) string {
    if !agent_workspace_path_allowed(path) {
        return ""
    }
    string root = agent_workspace_root()
    string resolved = agent_workspace_join_path(root, trim(path))
    if agent_workspace_starts_with(trim(resolved), "/") && root != "." && !agent_workspace_starts_with(resolved, root) {
        return ""
    }
    resolved
}

func agent_workspace_clip(string text, int max_chars) string {
    if max_chars <= 0 || len(text) <= max_chars {
        return text
    }
    string out = ""
    int i = 0
    while i < max_chars {
        out = out + string(text[i])
        i = i + 1
    }
    out + "...[truncated]"
}

func agent_workspace_result_ok(string obs, string path) agent_workspace_result {
    agent_workspace_result {
        ok: true,
        observation: obs,
        resolved_path: path,
    }
}

func agent_workspace_result_fail(string obs, string path) agent_workspace_result {
    agent_workspace_result {
        ok: false,
        observation: obs,
        resolved_path: path,
    }
}

func agent_workspace_command_result_ok(string cmd, string obs) agent_workspace_command_result {
    agent_workspace_command_result {
        ok: true,
        command: cmd,
        observation: obs,
    }
}

func agent_workspace_command_result_fail(string cmd, string obs) agent_workspace_command_result {
    agent_workspace_command_result {
        ok: false,
        command: cmd,
        observation: obs,
    }
}

func agent_workspace_patch_result_ok(string obs, string path, int replacements) agent_workspace_patch_result {
    agent_workspace_patch_result {
        ok: true,
        observation: obs,
        resolved_path: path,
        replacements: replacements,
    }
}

func agent_workspace_patch_result_fail(string obs, string path) agent_workspace_patch_result {
    agent_workspace_patch_result {
        ok: false,
        observation: obs,
        resolved_path: path,
        replacements: 0,
    }
}

func agent_workspace_read(string path, int max_chars) agent_workspace_result {
    string resolved = agent_workspace_resolve_path(path)
    if resolved == "" {
        return agent_workspace_result_fail("retrieve:blocked;path=" + path, "")
    }
    if !runtime_file_exists(resolved) {
        return agent_workspace_result_fail("retrieve:missing;path=" + resolved, resolved)
    }
    string content = runtime_read_text_file(resolved)
    agent_workspace_result_ok("retrieve:ok;path=" + resolved + ";content=" + agent_workspace_clip(content, max_chars), resolved)
}

func agent_workspace_write(string path, string content) agent_workspace_result {
    string resolved = agent_workspace_resolve_path(path)
    if resolved == "" {
        return agent_workspace_result_fail("write:blocked;path=" + path, "")
    }
    runtime_write_text_file(resolved, content)
    agent_workspace_result_ok("write:ok;path=" + resolved + ";bytes=" + string(len(content)), resolved)
}

func agent_workspace_delete(string path) agent_workspace_result {
    string resolved = agent_workspace_resolve_path(path)
    if resolved == "" {
        return agent_workspace_result_fail("delete:blocked;path=" + path, "")
    }
    if !runtime_file_exists(resolved) {
        return agent_workspace_result_fail("delete:missing;path=" + resolved, resolved)
    }
    runtime_write_text_file(resolved, "")
    agent_workspace_result_ok("delete:cleared;path=" + resolved, resolved)
}

func agent_workspace_default_build_command() string {
    if runtime_file_exists("app/CMakeLists.txt") {
        return "cmake --build app/build/make-linux"
    }
    if runtime_file_exists("Makefile") {
        return "make"
    }
    "build_unconfigured"
}

func agent_workspace_default_test_command() string {
    if runtime_file_exists("app/build/make-linux/CTestTestfile.cmake") {
        return "ctest --test-dir app/build/make-linux --output-on-failure"
    }
    if runtime_file_exists("Makefile") {
        return "make test"
    }
    "test_unconfigured"
}

func agent_workspace_plan_command(string tool_name, string requested) agent_workspace_command_result {
    string command = trim(requested)
    if command == "" {
        if tool_name == "build" {
            command = trim(runtime_env_get("NEURX_AGENT_BUILD_COMMAND", agent_workspace_default_build_command()))
        } else if tool_name == "test" {
            command = trim(runtime_env_get("NEURX_AGENT_TEST_COMMAND", agent_workspace_default_test_command()))
        }
    }
    if command == "" || command == "build_unconfigured" || command == "test_unconfigured" {
        return agent_workspace_command_result_fail(command, tool_name + ":unconfigured")
    }
    agent_workspace_command_result_ok(command, tool_name + ":planned;command=" + command)
}

func agent_workspace_run_command(string tool_name, string requested) agent_workspace_command_result {
    agent_workspace_command_result planned = agent_workspace_plan_command(tool_name, requested)
    if !planned.ok {
        return planned
    }
    runtime_command_result run = runtime_run_command(planned.command)
    if run.ok {
        return agent_workspace_command_result_ok(planned.command, tool_name + ":ok;command=" + planned.command + ";exit_code=0")
    }
    agent_workspace_command_result_fail(planned.command, tool_name + ":failed;command=" + planned.command + ";exit_code=" + string(run.exit_code) + ";error=" + run.error)
}

func agent_workspace_find(string text, string pattern, int start) int {
    int text_len = len(text)
    int pat_len = len(pattern)
    if pat_len <= 0 {
        return start
    }
    if text_len < pat_len || start > text_len - pat_len {
        return -1
    }
    int i = start
    while i <= text_len - pat_len {
        int j = 0
        bool match = true
        while j < pat_len {
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

func agent_workspace_replace_exact(string text, string old_text, string new_text, bool replace_all) agent_workspace_patch_result {
    if old_text == "" {
        return agent_workspace_patch_result_fail("patch:empty_old_text", "")
    }
    string out = ""
    int cursor = 0
    int replacements = 0
    int idx = agent_workspace_find(text, old_text, 0)
    while idx >= 0 {
        int i = cursor
        while i < idx {
            out = out + string(text[i])
            i = i + 1
        }
        out = out + new_text
        replacements = replacements + 1
        cursor = idx + len(old_text)
        if !replace_all {
            break
        }
        idx = agent_workspace_find(text, old_text, cursor)
    }
    if replacements <= 0 {
        return agent_workspace_patch_result_fail("patch:no_match", "")
    }
    int tail = cursor
    while tail < len(text) {
        out = out + string(text[tail])
        tail = tail + 1
    }
    agent_workspace_patch_result {
        ok: true,
        observation: out,
        resolved_path: "",
        replacements: replacements,
    }
}

func agent_workspace_apply_patch(string path, string old_text, string new_text, bool replace_all) agent_workspace_patch_result {
    string resolved = agent_workspace_resolve_path(path)
    if resolved == "" {
        return agent_workspace_patch_result_fail("patch:blocked;path=" + path, "")
    }
    if !runtime_file_exists(resolved) {
        return agent_workspace_patch_result_fail("patch:missing;path=" + resolved, resolved)
    }
    string content = runtime_read_text_file(resolved)
    agent_workspace_patch_result replaced = agent_workspace_replace_exact(content, old_text, new_text, replace_all)
    if !replaced.ok {
        return agent_workspace_patch_result_fail(replaced.observation + ";path=" + resolved, resolved)
    }
    runtime_write_text_file(resolved, replaced.observation)
    agent_workspace_patch_result_ok("patch:ok;path=" + resolved + ";replacements=" + string(replaced.replacements), resolved, replaced.replacements)
}
