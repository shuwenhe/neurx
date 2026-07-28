package neurx.agent.workspace_tools
use neurx.runtime.io.{runtime_env_get, runtime_read_text_file, runtime_write_text_file, runtime_file_exists, runtime_dir_exists, runtime_make_dirs, runtime_delete_path, runtime_run_command, runtime_run_command_output, runtime_shell_escape}

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

func agent_workspace_observation(string kind, string status, string details) string {
    string obs = kind + ":status=" + status
    if trim(details) != "" {
        obs = obs + ";" + details
    }
    obs
}

func agent_workspace_count_lines(string text) int {
    string trimmed = trim(text)
    if trimmed == "" {
        return 0
    }
    int count = 1
    int i = 0
    while i < len(trimmed) {
        if string(trimmed[i]) == "\n" {
            count = count + 1
        }
        i = i + 1
    }
    count
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

func agent_workspace_command_output_detail(string output, int max_chars) string {
    string trimmed = trim(output)
    if trimmed == "" {
        return ""
    }
    ";output_summary=" + agent_workspace_clip(trimmed, max_chars)
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
        return agent_workspace_result_fail(agent_workspace_observation("retrieve", "blocked", "reason=path_not_allowed;path=" + path), "")
    }
    if !runtime_file_exists(resolved) {
        return agent_workspace_result_fail(agent_workspace_observation("retrieve", "failed", "reason=missing;path=" + resolved), resolved)
    }
    string content = runtime_read_text_file(resolved)
    agent_workspace_result_ok(agent_workspace_observation("retrieve", "ok", "path=" + resolved + ";content=" + agent_workspace_clip(content, max_chars)), resolved)
}

func agent_workspace_read_file(string path, int start_line, int line_count, int max_chars) agent_workspace_result {
    string resolved = agent_workspace_resolve_path(path)
    if resolved == "" {
        return agent_workspace_result_fail(agent_workspace_observation("read_file", "blocked", "reason=path_not_allowed;path=" + path), "")
    }
    if !runtime_file_exists(resolved) {
        return agent_workspace_result_fail(agent_workspace_observation("read_file", "failed", "reason=missing;path=" + resolved), resolved)
    }
    string content = runtime_read_text_file(resolved)
    []string lines = agent_workspace_split_lines(content)
    int start = start_line
    if start <= 0 {
        start = 1
    }
    int count = line_count
    if count <= 0 {
        count = 120
    }
    int begin = start - 1
    if begin < 0 {
        begin = 0
    }
    if begin >= len(lines) {
        begin = len(lines)
    }
    int end = begin + count
    if end > len(lines) {
        end = len(lines)
    }
    string slice = ""
    int i = begin
    while i < end {
        slice = slice + lines[i]
        if i + 1 < end {
            slice = slice + "\n"
        }
        i = i + 1
    }
    agent_workspace_result_ok(
        agent_workspace_observation(
            "read_file",
            "ok",
            "path=" + resolved + ";start_line=" + string(start) + ";line_count=" + string(end - begin) + ";content=" + agent_workspace_clip(slice, max_chars)
        ),
        resolved
    )
}

func agent_workspace_write(string path, string content) agent_workspace_result {
    string resolved = agent_workspace_resolve_path(path)
    if resolved == "" {
        return agent_workspace_result_fail(agent_workspace_observation("write", "blocked", "reason=path_not_allowed;path=" + path), "")
    }
    int last_slash = -1
    int i = 0
    while i < len(resolved) {
        if string(resolved[i]) == "/" {
            last_slash = i
        }
        i = i + 1
    }
    if last_slash > 0 {
        string parent = ""
        i = 0
        while i < last_slash {
            parent = parent + string(resolved[i])
            i = i + 1
        }
        runtime_command_result mkdir_result = runtime_make_dirs(parent)
        if !mkdir_result.ok {
            return agent_workspace_result_fail(agent_workspace_observation("write", "failed", "reason=mkdir_failed;path=" + parent + ";error=" + mkdir_result.error), resolved)
        }
    }
    runtime_write_text_file(resolved, content)
    agent_workspace_result_ok(agent_workspace_observation("write", "ok", "path=" + resolved + ";bytes=" + string(len(content))), resolved)
}

func agent_workspace_write_file(string path, string content) agent_workspace_result {
    agent_workspace_result base = agent_workspace_write(path, content)
    if !base.ok {
        return agent_workspace_result_fail(
            agent_workspace_observation("write_file", "failed", "path=" + path + ";reason=write_failed"),
            base.resolved_path
        )
    }
    agent_workspace_result_ok(
        agent_workspace_observation("write_file", "ok", "path=" + base.resolved_path + ";bytes=" + string(len(content))),
        base.resolved_path
    )
}

func agent_workspace_mkdir(string path) agent_workspace_result {
    string resolved = agent_workspace_resolve_path(path)
    if resolved == "" {
        return agent_workspace_result_fail(agent_workspace_observation("mkdir", "blocked", "reason=path_not_allowed;path=" + path), "")
    }
    if runtime_dir_exists(resolved) {
        return agent_workspace_result_ok(agent_workspace_observation("mkdir", "ok", "path=" + resolved + ";already_exists=true"), resolved)
    }
    runtime_command_result mkdir_result = runtime_make_dirs(resolved)
    if !mkdir_result.ok {
        return agent_workspace_result_fail(agent_workspace_observation("mkdir", "failed", "path=" + resolved + ";error=" + mkdir_result.error), resolved)
    }
    agent_workspace_result_ok(agent_workspace_observation("mkdir", "ok", "path=" + resolved), resolved)
}

func agent_workspace_delete(string path) agent_workspace_result {
    string resolved = agent_workspace_resolve_path(path)
    if resolved == "" {
        return agent_workspace_result_fail(agent_workspace_observation("delete", "blocked", "reason=path_not_allowed;path=" + path), "")
    }
    if !runtime_file_exists(resolved) {
        return agent_workspace_result_fail(agent_workspace_observation("delete", "failed", "reason=missing;path=" + resolved), resolved)
    }
    bool recursive = runtime_dir_exists(resolved)
    runtime_command_result delete_result = runtime_delete_path(resolved, recursive)
    if !delete_result.ok {
        return agent_workspace_result_fail(agent_workspace_observation("delete", "failed", "path=" + resolved + ";error=" + delete_result.error), resolved)
    }
    agent_workspace_result_ok(agent_workspace_observation("delete", "ok", "path=" + resolved), resolved)
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
        return agent_workspace_command_result_fail(command, agent_workspace_observation(tool_name, "blocked", "reason=unconfigured"))
    }
    agent_workspace_command_result_ok(command, agent_workspace_observation(tool_name, "ok", "phase=planned;command=" + command))
}

func agent_workspace_run_command(string tool_name, string requested) agent_workspace_command_result {
    agent_workspace_command_result planned = agent_workspace_plan_command(tool_name, requested)
    if !planned.ok {
        return planned
    }
    string output = trim(runtime_run_command_output(planned.command + " 2>&1"))
    runtime_command_result run = runtime_run_command(planned.command)
    if run.ok {
        string observation = agent_workspace_observation(tool_name, "ok", "command=" + planned.command + ";exit_code=0")
        observation = observation + agent_workspace_command_output_detail(output, 800)
        return agent_workspace_command_result_ok(planned.command, observation)
    }
    string failure = agent_workspace_observation(tool_name, "failed", "command=" + planned.command + ";exit_code=" + string(run.exit_code) + ";reason=command_failed;error=" + run.error)
    failure = failure + agent_workspace_command_output_detail(output, 800)
    agent_workspace_command_result_fail(planned.command, failure)
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
        return agent_workspace_patch_result_fail(agent_workspace_observation("patch", "failed", "reason=empty_old_text"), "")
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
        return agent_workspace_patch_result_fail(agent_workspace_observation("patch", "no_progress", "reason=no_match"), "")
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

func agent_workspace_split_lines(string text) []string {
    int count = agent_workspace_count_lines(text)
    if count < 1 {
        count = 1
    }
    []string result = []string{cap: count + 1}
    string line = ""
    int i = 0
    while i < len(text) {
        string ch = string(text[i])
        if ch == "\n" {
            result.push(line)
            line = ""
        } else if ch != "\r" {
            line = line + ch
        }
        i = i + 1
    }
    result.push(line)
    result
}

func agent_workspace_normalize_line(string line) string {
    string expanded = ""
    int i = 0
    while i < len(line) {
        string ch = string(line[i])
        if ch == "\t" {
            expanded = expanded + "    "
        } else {
            expanded = expanded + ch
        }
        i = i + 1
    }
    trim(expanded)
}

func agent_workspace_replace_fuzzy(string content, string old_text, string new_text, bool replace_all) agent_workspace_patch_result {
    []string cl = agent_workspace_split_lines(content)
    []string ol = agent_workspace_split_lines(old_text)
    int nc = len(cl)
    int no = len(ol)
    if no == 0 {
        return agent_workspace_patch_result_fail(agent_workspace_observation("patch", "no_progress", "reason=empty_old_text"), "")
    }
    []string norm_ol = []string{cap: no + 1}
    int oi = 0
    while oi < no {
        norm_ol.push(agent_workspace_normalize_line(ol[oi]))
        oi = oi + 1
    }
    bool content_ends_newline = nc > 0 && len(content) > 0 && string(content[len(content) - 1]) == "\n"
    string out = ""
    int replacements = 0
    int ci = 0
    while ci < nc {
        bool match = no > 0 && ci + no <= nc
        if match {
            int mi = 0
            while mi < no {
                if agent_workspace_normalize_line(cl[ci + mi]) != norm_ol[mi] {
                    match = false
                    break
                }
                mi = mi + 1
            }
        }
        if match {
            out = out + new_text
            bool new_ends_nl = len(new_text) > 0 && string(new_text[len(new_text) - 1]) == "\n"
            if !new_ends_nl && ci + no < nc {
                out = out + "\n"
            }
            ci = ci + no
            replacements = replacements + 1
            if !replace_all {
                while ci < nc {
                    if ci < nc - 1 {
                        out = out + cl[ci] + "\n"
                    } else {
                        out = out + cl[ci]
                        if content_ends_newline {
                            out = out + "\n"
                        }
                    }
                    ci = ci + 1
                }
                break
            }
        } else {
            if ci < nc - 1 {
                out = out + cl[ci] + "\n"
            } else {
                out = out + cl[ci]
                if content_ends_newline {
                    out = out + "\n"
                }
            }
            ci = ci + 1
        }
    }
    if replacements <= 0 {
        return agent_workspace_patch_result_fail(agent_workspace_observation("patch", "no_progress", "reason=no_match"), "")
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
        return agent_workspace_patch_result_fail(agent_workspace_observation("patch", "blocked", "reason=path_not_allowed;path=" + path), "")
    }
    if !runtime_file_exists(resolved) {
        return agent_workspace_patch_result_fail(agent_workspace_observation("patch", "failed", "reason=missing;path=" + resolved), resolved)
    }
    string content = runtime_read_text_file(resolved)
    agent_workspace_patch_result replaced = agent_workspace_replace_exact(content, old_text, new_text, replace_all)
    if !replaced.ok {
        replaced = agent_workspace_replace_fuzzy(content, old_text, new_text, replace_all)
        if !replaced.ok {
            return agent_workspace_patch_result_fail(replaced.observation + ";path=" + resolved, resolved)
        }
    }
    runtime_write_text_file(resolved, replaced.observation)
    agent_workspace_patch_result_ok(agent_workspace_observation("patch", "ok", "path=" + resolved + ";replacements=" + string(replaced.replacements)), resolved, replaced.replacements)
}

func agent_workspace_patch_file(string path, string old_text, string new_text, bool replace_all) agent_workspace_patch_result {
    agent_workspace_apply_patch(path, old_text, new_text, replace_all)
}

func agent_workspace_repo_map(int max_files) string {
    string root = agent_workspace_root()
    string cap_str = string(max_files)
    string cmd = "find " + runtime_shell_escape(root) + " -type f \\( -name '*.s' -o -name '*.md' -o -name 'CMakeLists.txt' -o -name 'Makefile' \\) -not -path '*/.gitbuildnode_modules/*' | sort | head -" + cap_str
    string output = runtime_run_command_output(cmd)
    if trim(output) == "" {
        return agent_workspace_observation("repo_map", "no_progress", "reason=empty")
    }
    agent_workspace_observation("repo_map", "ok", "file_count=" + string(agent_workspace_count_lines(output))) + "\n" + output
}

func agent_workspace_s(string command) agent_workspace_command_result {
    if trim(command) == "" {
        return agent_workspace_command_result_fail("", agent_workspace_observation("s", "blocked", "reason=empty_command"))
    }
    string output = trim(runtime_run_command_output(command))
    runtime_command_result run = runtime_run_command(command)
    int max_out = 2000
    bool truncated = len(output) > max_out
    string capped = output
    if truncated {
        capped = agent_workspace_clip(output, max_out) + ";note=output_truncated_use_retrieve_or_grep_for_full_output"
    }
    if run.ok {
        string obs = agent_workspace_observation("s", "ok", "command=" + agent_workspace_clip(command, 160))
        if capped != "" {
            obs = obs + ";output=" + capped
        }
        return agent_workspace_command_result_ok(command, obs)
    }
    string failure = agent_workspace_observation("s", "failed", "command=" + agent_workspace_clip(command, 160) + ";exit_code=" + string(run.exit_code))
    if capped != "" {
        failure = failure + ";output=" + capped
    }
    agent_workspace_command_result_fail(command, failure)
}

func agent_workspace_shell(string command) agent_workspace_command_result {
    agent_workspace_s(command)
}

func agent_workspace_sql_run(string query) agent_workspace_command_result {
    if trim(query) == "" {
        return agent_workspace_command_result_fail("", agent_workspace_observation("sql", "blocked", "reason=empty_query"))
    }
    string host = trim(runtime_env_get("NEURX_DB_HOST", "127.0.0.1"))
    string port = trim(runtime_env_get("NEURX_DB_PORT", "3306"))
    string user = trim(runtime_env_get("NEURX_DB_USER", "neurx"))
    string pass = trim(runtime_env_get("NEURX_DB_PASS", ""))
    string db   = trim(runtime_env_get("NEURX_DB_NAME", "neurx"))
    if host == "" { host = "127.0.0.1" }
    if port == "" { port = "3306" }
    if user == "" { user = "neurx" }
    if db   == "" { db = "neurx" }
    string cmd = "mysql -h " + runtime_shell_escape(host) + " -P " + port + " -u " + runtime_shell_escape(user)
    if pass != "" {
        cmd = cmd + " -p" + runtime_shell_escape(pass)
    }
    cmd = cmd + " " + runtime_shell_escape(db) + " -e " + runtime_shell_escape(query) + " 2>&1"
    string output = trim(runtime_run_command_output(cmd))
    runtime_command_result run = runtime_run_command(cmd)
    if run.ok {
        string obs = agent_workspace_observation("sql", "ok", "db=" + db)
        if output != "" {
            obs = obs + ";output=" + agent_workspace_clip(output, 1200)
        }
        return agent_workspace_command_result_ok(cmd, obs)
    }
    string failure = agent_workspace_observation("sql", "failed", "db=" + db + ";exit_code=" + string(run.exit_code))
    if output != "" {
        failure = failure + ";output=" + agent_workspace_clip(output, 1200)
    }
    agent_workspace_command_result_fail(cmd, failure)
}

func agent_workspace_apply_unified_diff(string diff_text) agent_workspace_result {
    if trim(diff_text) == "" {
        return agent_workspace_result_fail(agent_workspace_observation("patch", "blocked", "reason=empty_diff"), "")
    }
    string root = agent_workspace_root()
    string tmp = agent_workspace_join_path(root, ".neurx_agent_patch.diff")
    runtime_write_text_file(tmp, diff_text)
    string cmd = "cd " + runtime_shell_escape(root) + " && patch -p1 --batch < " + runtime_shell_escape(tmp) + " 2>&1"
    string output = trim(runtime_run_command_output(cmd))
    runtime_command_result run = runtime_run_command(cmd)
    runtime_run_command("rm -f " + runtime_shell_escape(tmp))
    if run.ok {
        return agent_workspace_result_ok(agent_workspace_observation("patch", "ok", "type=unified;output=" + agent_workspace_clip(output, 400)), "")
    }
    agent_workspace_result_fail(agent_workspace_observation("patch", "failed", "type=unified;output=" + agent_workspace_clip(output, 400)), "")
}

func agent_workspace_git_root() string {
    string output = trim(runtime_run_command_output("git rev-parse --show-toplevel 2>/dev/null"))
    if output == "" {
        return agent_workspace_root()
    }
    output
}

func agent_workspace_git_cmd(string subcmd) agent_workspace_command_result {
    string root = agent_workspace_git_root()
    string cmd = "cd " + runtime_shell_escape(root) + " && git " + subcmd + " 2>&1"
    string output = trim(runtime_run_command_output(cmd))
    runtime_command_result run = runtime_run_command(cmd)
    string kind = "git_" + subcmd
    if run.ok {
        string obs = agent_workspace_observation(kind, "ok", "")
        if output != "" {
            obs = agent_workspace_observation(kind, "ok", "output=" + agent_workspace_clip(output, 1600))
        }
        return agent_workspace_command_result_ok(cmd, obs)
    }
    agent_workspace_command_result_fail(cmd, agent_workspace_observation(kind, "failed", "output=" + agent_workspace_clip(output, 800)))
}

func agent_workspace_git_status() agent_workspace_command_result {
    agent_workspace_git_cmd("status --short")
}

func agent_workspace_git_diff(string args) agent_workspace_command_result {
    string a = trim(args)
    if a == "" {
        return agent_workspace_git_cmd("diff HEAD")
    }
    agent_workspace_git_cmd("diff " + a)
}

func agent_workspace_git_log(int n) agent_workspace_command_result {
    string count = string(n)
    if n <= 0 {
        count = "10"
    }
    agent_workspace_git_cmd("log --oneline -" + count)
}

func agent_workspace_git_commit(string message) agent_workspace_command_result {
    if trim(message) == "" {
        return agent_workspace_command_result_fail("", agent_workspace_observation("git_commit", "blocked", "reason=empty_message"))
    }
    string root = agent_workspace_git_root()
    string add_cmd = "cd " + runtime_shell_escape(root) + " && git add -A 2>&1"
    runtime_run_command(add_cmd)
    string commit_cmd = "cd " + runtime_shell_escape(root) + " && git commit -m " + runtime_shell_escape(message) + " 2>&1"
    string output = trim(runtime_run_command_output(commit_cmd))
    runtime_command_result run = runtime_run_command(commit_cmd)
    if run.ok {
        return agent_workspace_command_result_ok(commit_cmd, agent_workspace_observation("git_commit", "ok", "output=" + agent_workspace_clip(output, 400)))
    }
    agent_workspace_command_result_fail(commit_cmd, agent_workspace_observation("git_commit", "failed", "output=" + agent_workspace_clip(output, 400)))
}

func agent_workspace_grep(string pattern, string path_glob, int max_results) agent_workspace_result {
    if trim(pattern) == "" {
        return agent_workspace_result_fail(agent_workspace_observation("grep", "blocked", "reason=empty_pattern"), "")
    }
    string root = agent_workspace_git_root()
    string glob_arg = "."
    if trim(path_glob) != "" {
        glob_arg = path_glob
    }
    int limit = max_results
    if limit <= 0 {
        limit = 40
    }
    string cmd = "cd " + runtime_shell_escape(root) + " && grep -rn --include=" + runtime_shell_escape(glob_arg) + " -m " + string(limit) + " " + runtime_shell_escape(pattern) + " 2>&1 | head -" + string(limit)
    string output = trim(runtime_run_command_output(cmd))
    runtime_command_result run = runtime_run_command(cmd)
    if output == "" {
        return agent_workspace_result_ok(agent_workspace_observation("grep", "ok", "pattern=" + agent_workspace_clip(pattern, 80) + ";matches=0"), "")
    }
    string details = "pattern=" + agent_workspace_clip(pattern, 80) + ";output=" + agent_workspace_clip(output, 2000)
    if run.ok {
        return agent_workspace_result_ok(agent_workspace_observation("grep", "ok", details), "")
    }
    agent_workspace_result_fail(agent_workspace_observation("grep", "failed", details), "")
}

func agent_workspace_search_files(string query, int max_results) agent_workspace_result {
    string trimmed = trim(query)
    if trimmed == "" {
        return agent_workspace_result_fail(agent_workspace_observation("search_files", "blocked", "reason=empty_query"), "")
    }
    string root = agent_workspace_git_root()
    int limit = max_results
    if limit <= 0 {
        limit = 40
    }
    string grep_cmd = "cd " + runtime_shell_escape(root) + " && grep -rn -m " + string(limit) + " " + runtime_shell_escape(trimmed) + " . 2>/dev/null | head -" + string(limit)
    string grep_out = trim(runtime_run_command_output(grep_cmd))
    if grep_out != "" {
        return agent_workspace_result_ok(
            agent_workspace_observation("search_files", "ok", "query=" + agent_workspace_clip(trimmed, 120) + ";output=" + agent_workspace_clip(grep_out, 2000)),
            root
        )
    }
    string find_cmd = "cd " + runtime_shell_escape(root) + " && find . -type f | grep -i " + runtime_shell_escape(trimmed) + " | head -" + string(limit)
    string find_out = trim(runtime_run_command_output(find_cmd))
    if find_out == "" {
        return agent_workspace_result_ok(
            agent_workspace_observation("search_files", "ok", "query=" + agent_workspace_clip(trimmed, 120) + ";matches=0"),
            root
        )
    }
    agent_workspace_result_ok(
        agent_workspace_observation("search_files", "ok", "query=" + agent_workspace_clip(trimmed, 120) + ";output=" + agent_workspace_clip(find_out, 2000)),
        root
    )
}

func agent_workspace_find_symbol(string symbol, string ext) agent_workspace_result {
    if trim(symbol) == "" {
        return agent_workspace_result_fail(agent_workspace_observation("find_symbol", "blocked", "reason=empty_symbol"), "")
    }
    string root = agent_workspace_git_root()
    string include_arg = "*"
    if trim(ext) != "" {
        include_arg = "*." + ext
    }
    string cmd = "cd " + runtime_shell_escape(root) + " && grep -rn --include=" + runtime_shell_escape(include_arg) + " -m 20 " + runtime_shell_escape("func " + symbol) + " 2>&1 | head -20"
    string output = trim(runtime_run_command_output(cmd))
    if output == "" {
        string cmd2 = "cd " + runtime_shell_escape(root) + " && grep -rn --include=" + runtime_shell_escape(include_arg) + " -m 20 " + runtime_shell_escape(symbol) + " 2>&1 | head -20"
        output = trim(runtime_run_command_output(cmd2))
    }
    if output == "" {
        return agent_workspace_result_ok(agent_workspace_observation("find_symbol", "ok", "symbol=" + symbol + ";matches=0"), "")
    }
    agent_workspace_result_ok(agent_workspace_observation("find_symbol", "ok", "symbol=" + symbol + ";output=" + agent_workspace_clip(output, 1600)), "")
}

func agent_workspace_list_dir(string path, int max_entries) agent_workspace_result {
    string resolved = agent_workspace_resolve_path(path)
    if resolved == "" {
        return agent_workspace_result_fail(agent_workspace_observation("list_dir", "blocked", "reason=path_not_allowed;path=" + path), "")
    }
    if !runtime_dir_exists(resolved) {
        if !runtime_file_exists(resolved) {
            return agent_workspace_result_fail(agent_workspace_observation("list_dir", "failed", "reason=missing;path=" + resolved), resolved)
        }
        return agent_workspace_result_fail(agent_workspace_observation("list_dir", "failed", "reason=not_a_directory;path=" + resolved), resolved)
    }
    int limit = max_entries
    if limit <= 0 {
        limit = 200
    }
    string cmd = "ls -la " + runtime_shell_escape(resolved) + " 2>&1 | head -" + string(limit + 1)
    string output = trim(runtime_run_command_output(cmd))
    if output == "" {
        return agent_workspace_result_ok(agent_workspace_observation("list_dir", "ok", "path=" + resolved + ";entries=0"), resolved)
    }
    agent_workspace_result_ok(agent_workspace_observation("list_dir", "ok", "path=" + resolved + ";output=" + agent_workspace_clip(output, 2000)), resolved)
}
