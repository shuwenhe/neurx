package neurx.executor.model_tool_select
use neurx.inference
use neurx.agent.memory
use neurx.agent.tool_registry
use neurx.agent.action_schema

func agent_model_clip(string text, int max_chars) string {
    if len(text) <= max_chars {
        return text
    }
    string out = ""
    int i = 0
    for i < max_chars {
        out = out + string(text[i])
        i = i + 1
    }
    out + "\n...[truncated]"
}

func agent_model_route_line_starts_with(string line, string prefix) bool {
    int ll = len(line)
    int pl = len(prefix)
    if ll < pl {
        return false
    }
    int i = 0
    for i < pl {
        if string(line[i]) != string(prefix[i]) {
            return false
        }
        i = i + 1
    }
    true
}

func agent_model_route_extract_value(string line, int key_len) string {
    int ll = len(line)
    int start = key_len
    for start < ll {
        string ch = string(line[start])
        if ch != ":" && ch != " " {
            break
        }
        start = start + 1
    }
    string val = ""
    int i = start
    for i < ll {
        string ch = string(line[i])
        if ch == " " || ch == "\r" || ch == "\n" {
            break
        }
        val = val + ch
        i = i + 1
    }
    lower(trim(val))
}

func agent_model_route_scan_response(string response) string {
    int resp_len = len(response)
    string cur_line = ""
    int i = 0
    for i <= resp_len {
        bool at_end = i == resp_len
        bool at_newline = !at_end && string(response[i]) == "\n"
        if at_newline || at_end {
            string ln = lower(trim(cur_line))
            cur_line = ""
            if agent_model_route_line_starts_with(ln, "route") {
                string val = agent_model_route_extract_value(ln, 5)
                if val != "" {
                    return val
                }
            }
            if agent_model_route_line_starts_with(ln, "tool") {
                string val = agent_model_route_extract_value(ln, 4)
                if val != "" {
                    return val
                }
            }
        } else {
            cur_line = cur_line + string(response[i])
        }
        i = i + 1
    }
    ""
}

func agent_model_route_normalize(string raw) string {
    if raw == "write" || raw == "write_file" || raw == "create" || raw == "create_file" || raw == "new_file" {
        return "write"
    }
    if raw == "mkdir" || raw == "create_directory" || raw == "new_folder" || raw == "create_folder" {
        return "mkdir"
    }
    if raw == "delete" || raw == "remove" || raw == "delete_file" || raw == "rm" || raw == "trash" {
        return "delete"
    }
    if raw == "apply_patch" || raw == "patch" || raw == "edit" || raw == "fix" || raw == "refactor" {
        return "apply_patch"
    }
    if raw == "retrieve" || raw == "read" || raw == "read_file" {
        return "retrieve"
    }
    if raw == "search" || raw == "search_files" || raw == "find" || raw == "lookup" {
        return "search"
    }
    if raw == "build" || raw == "run_build" || raw == "compile" {
        return "build"
    }
    if raw == "test" || raw == "run_test" || raw == "run_tests" {
        return "test"
    }
    if raw == "infer" || raw == "reason" || raw == "think" {
        return "infer"
    }
    if raw == "code" || raw == "implement" || raw == "bug" || raw == "error" {
        return "code"
    }
    if raw == "sql" || raw == "database" || raw == "query" || raw == "migration" || raw == "schema" {
        return "sql"
    }
    if raw == "repo" || raw == "repository" || raw == "architecture" || raw == "readme" {
        return "repo"
    }
    if raw == "review" || raw == "audit" || raw == "check" {
        return "review"
    }
    if raw == "s" || raw == "shell" || raw == "bash" || raw == "run_command" || raw == "exec" || raw == "cmd" || raw == "run_shell" {
        return "s"
    }
    if raw == "apply_unified_diff" || raw == "unified_diff" || raw == "diff" || raw == "udiff" {
        return "apply_unified_diff"
    }
    if raw == "git_status" || raw == "git status" || raw == "status" {
        return "git_status"
    }
    if raw == "git_diff" || raw == "git diff" || raw == "git_changes" {
        return "git_diff"
    }
    if raw == "git_log" || raw == "git log" || raw == "git_history" || raw == "history" {
        return "git_log"
    }
    if raw == "git_commit" || raw == "git commit" || raw == "commit" {
        return "git_commit"
    }
    if raw == "grep" || raw == "grep_search" || raw == "text_search" || raw == "find_text" {
        return "grep"
    }
    if raw == "find_symbol" || raw == "symbol" || raw == "find_definition" || raw == "go_to_definition" || raw == "definition" {
        return "find_symbol"
    }
    if raw == "subagent" || raw == "spawn_subagent" || raw == "sub_agent" || raw == "delegate" || raw == "parallel" {
        return "subagent"
    }
    if raw == "show_pending_changes" || raw == "show_pending" || raw == "pending" {
        return "show_pending_changes"
    }
    if raw == "apply_pending_changes" || raw == "apply_pending" {
        return "apply_pending_changes"
    }
    if raw == "general" || raw == "answer" || raw == "explain" || raw == "describe" {
        return "general"
    }
    ""
}

func agent_model_route_build_prompt(string goal, string task, string input) string {
    string prompt = "You are a tool-routing agent. Select the single best route for the goal.\n"
    prompt = prompt + "Routes and meanings:\n"
    prompt = prompt + "  write       - create or write a new file (`write_file`)\n"
    prompt = prompt + "  delete      - delete or remove a file (`delete_path`)\n"
    prompt = prompt + "  apply_patch - edit, patch, or fix an existing file\n"
    prompt = prompt + "  retrieve    - read or inspect a file (`read_file`)\n"
    prompt = prompt + "  search      - find files, symbols, or text in the codebase (`search_files`)\n"
    prompt = prompt + "  build       - compile or build the project (`run_build`)\n"
    prompt = prompt + "  test        - run tests (`run_test`)\n"
    prompt = prompt + "  s           - run an arbitrary command via the S toolchain\n"
    prompt = prompt + "  infer       - use model reasoning or generation\n"
    prompt = prompt + "  code        - implement a feature or fix a bug\n"
    prompt = prompt + "  apply_unified_diff - apply a unified diff patch\n"
    prompt = prompt + "  review      - audit, check, or review code\n"
    prompt = prompt + "  subagent    - spawn a sub-agent to handle a sub-task in parallel\n"
    prompt = prompt + "  show_pending_changes - inspect staged edits before applying them\n"
    prompt = prompt + "  apply_pending_changes - apply staged edits to the workspace\n"
    prompt = prompt + "  sql         - database or SQL query task\n"
    prompt = prompt + "  repo        - repository structure or architecture question\n"
    prompt = prompt + "  general     - any other task\n"
    prompt = prompt + "\nGoal: " + goal + "\n"
    prompt = prompt + "task: " + task + "\n"
    prompt = prompt + "Input: " + input + "\n"
    prompt = prompt + "\nRespond with exactly one line:\nroute: <route_name>\n"
    prompt
}

func agent_model_route(string goal, string task, string input, string model_path) string {
    if model_path == "" {
        return ""
    }
    string prompt = agent_model_route_build_prompt(goal, task, input)
    string response = infer_run(model_path, prompt)
    if trim(response) == "" {
        return ""
    }
    string raw = agent_model_route_scan_response(response)
    if raw == "" {
        return ""
    }
    agent_model_route_normalize(raw)
}

func agent_model_parse_field(string response, string key) string {
    int resp_len = len(response)
    string cur_line = ""
    int i = 0
    for i <= resp_len {
        bool at_end = i == resp_len
        bool at_newline = !at_end && string(response[i]) == "\n"
        if at_newline || at_end {
            string ln = cur_line
            cur_line = ""
            string ln_lower = lower(trim(ln))
            string key_lower = lower(key)
            if agent_model_route_line_starts_with(ln_lower, key_lower) {
                string val = agent_model_route_extract_value(ln, len(key))
                if val != "" {
                    return val
                }
            }
        } else {
            cur_line = cur_line + string(response[i])
        }
        i = i + 1
    }
    ""
}

func agent_model_str_find(string text, string pattern, int start) int {
    int tl = len(text)
    int pl = len(pattern)
    if pl <= 0 {
        return start
    }
    if tl < pl {
        return -1
    }
    int i = start
    for i <= tl - pl {
        int j = 0
        bool match = true
        for j < pl {
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

func agent_model_parse_block(string response, string begin_marker, string end_marker) string {
    int bm_pos = agent_model_str_find(response, begin_marker, 0)
    if bm_pos < 0 {
        return ""
    }
    int content_start = bm_pos + len(begin_marker)
    if content_start < len(response) && string(response[content_start]) == "\n" {
        content_start = content_start + 1
    }
    int em_pos = agent_model_str_find(response, end_marker, content_start)
    int content_end = em_pos
    if em_pos < 0 {
        content_end = len(response)
    }
    if content_end > content_start && string(response[content_end - 1]) == "\n" {
        content_end = content_end - 1
    }
    string out = ""
    int i = content_start
    for i < content_end {
        out = out + string(response[i])
        i = i + 1
    }
    out
}

func agent_model_tool_call_build_prompt(agent_tool_registry_state tools, agent_memory_state memory, string goal, string task, string input, string model_path) string {
    agent_memory_lookup_result retrieved_result = agent_memory_lookup_long(memory, "retrieved")
    agent_memory_lookup_result inferred_result = agent_memory_lookup_long(memory, "inferred_model")
    agent_memory_lookup_result analysis_result = agent_memory_lookup_long(memory, "analysis")
    agent_memory_lookup_result repo_map_result = agent_memory_lookup_long(memory, "repo_map")
    agent_memory_lookup_result searched_result = agent_memory_lookup_long(memory, "searched")
    string tools_list = agent_tool_registry_summary(tools)
    string prompt = "You are an AI coding agent. Decide the next action and provide all arguments.\n\n"
    prompt = prompt + "GOAL: " + goal + "\n"
    prompt = prompt + "CURRENT TASK: " + task + "\n"
    prompt = prompt + "INPUT: " + input + "\n"
    if analysis_result.found && analysis_result.value != "" {
        prompt = prompt + "ANALYSIS: " + analysis_result.value + "\n"
    }
    if repo_map_result.found && repo_map_result.value != "" {
        prompt = prompt + "REPO MAP:\n" + agent_model_clip(repo_map_result.value, 1500) + "\n"
    }
    if retrieved_result.found && retrieved_result.value != "" {
        prompt = prompt + "RETRIEVED:\n" + agent_model_clip(retrieved_result.value, 3000) + "\n"
    }
    if searched_result.found && searched_result.value != "" {
        prompt = prompt + "SEARCH RESULTS:\n" + agent_model_clip(searched_result.value, 1500) + "\n"
    }
    if inferred_result.found && inferred_result.value != "" {
        prompt = prompt + "PRIOR REASONING:\n" + agent_model_clip(inferred_result.value, 1000) + "\n"
    }
    prompt = prompt + "\nAVAILABLE TOOLS:\n" + tools_list + "\n"
    prompt = prompt + "\nRespond with EXACTLY ONE tool call object and nothing else.\n"
    prompt = prompt + "Use this JSON-like shape:\n"
    prompt = prompt + "{\"action\":\"read_file|write_file|patch|search_files|mkdir|delete_path|run_build|run_test|s|infer|code|review|repo|sql|git_status|git_diff|git_log|git_commit|subagent|general\",\"path\":\"relative/path\",\"query\":\"text\",\"command\":\"command\",\"old_text\":\"exact old text\",\"new_text\":\"replacement text\",\"replace_all\":false}\n"
    prompt = prompt + "Rules:\n"
    prompt = prompt + "- Use action=read_file to inspect a specific file\n"
    prompt = prompt + "- Use action=search_files to search by text or filename\n"
    prompt = prompt + "- Use action=write_file to create or fully replace a file\n"
    prompt = prompt + "- Use action=patch for targeted edits to an existing file\n"
    prompt = prompt + "- Use action=mkdir to create a directory\n"
    prompt = prompt + "- Use action=delete_path only when deletion is required\n"
    prompt = prompt + "- Prefer read_file before patching unless the request is trivial\n"
    prompt = prompt + "- For multi-line file content, keep the JSON object first and then include a content block\n"
    prompt = prompt + "---BEGIN CONTENT---\n"
    prompt = prompt + "<content>\n"
    prompt = prompt + "---END CONTENT---\n"
    prompt
}

func agent_model_tool_call_parse(string response) agent_action_state {
    agent_action_parse(response, "general")
}

func agent_model_tool_call(agent_tool_registry_state tools, agent_memory_state memory, string goal, string task, string input, string model_path) agent_action_state {
    if model_path == "" {
        return new_agent_action_state()
    }
    string prompt = agent_model_tool_call_build_prompt(tools, memory, goal, task, input, model_path)
    string response = infer_run(model_path, prompt)
    if trim(response) == "" {
        return new_agent_action_state()
    }
    agent_model_tool_call_parse(response)
}

func agent_model_plan_build_prompt(string goal, string route, string analysis, string input) string {
    string prompt = "You are a planning agent. Output an ordered task queue to accomplish the goal.\n\n"
    prompt = prompt + "GOAL: " + goal + "\n"
    prompt = prompt + "ROUTE: " + route + "\n"
    prompt = prompt + "INPUT: " + input + "\n"
    if analysis != "" {
        prompt = prompt + "ANALYSIS: " + analysis + "\n"
    }
    prompt = prompt + "\nAVAILABLE TASKS (use only these names):\n"
    prompt = prompt + "  repo             - scan repository file structure\n"
    prompt = prompt + "  retrieve         - read a specific file\n"
    prompt = prompt + "  search           - search codebase for text or symbols\n"
    prompt = prompt + "  grep             - grep for a pattern across files\n"
    prompt = prompt + "  find_symbol      - find definition or usages of a symbol\n"
    prompt = prompt + "  git_status       - show git working tree status\n"
    prompt = prompt + "  git_diff         - show uncommitted changes\n"
    prompt = prompt + "  git_log          - show recent commit history\n"
    prompt = prompt + "  git_commit       - stage and commit all changes\n"
    prompt = prompt + "  infer            - reason or generate with the model\n"
    prompt = prompt + "  code             - generate and write new code to a file\n"
    prompt = prompt + "  write            - write content to a file\n"
    prompt = prompt + "  apply_patch      - edit an existing file (search+replace)\n"
    prompt = prompt + "  apply_unified_diff - apply a unified diff patch to files\n"
    prompt = prompt + "  delete           - delete a file\n"
    prompt = prompt + "  build            - compile or build the project\n"
    prompt = prompt + "  test             - run tests\n"
    prompt = prompt + "  s                - run any command (install, lint, format, etc.)\n"
    prompt = prompt + "  review           - review or audit code\n"
    prompt = prompt + "  subagent         - delegate a sub-task to a parallel sub-agent\n"
    prompt = prompt + "\nRespond with ONLY this line (no explanation):\n"
    prompt = prompt + "plan_queue: [task1, task2, task3]\n"
    prompt = prompt + "\nExamples:\n"
    prompt = prompt + "  Implement a feature: plan_queue: [repo, retrieve, code, build, test]\n"
    prompt = prompt + "  Fix a bug: plan_queue: [grep, retrieve, apply_patch, build, test]\n"
    prompt = prompt + "  Code review: plan_queue: [retrieve, review]\n"
    prompt = prompt + "  Search only: plan_queue: [grep]\n"
    prompt = prompt + "  Check changes: plan_queue: [git_status, git_diff]\n"
    prompt
}

func agent_model_plan(agent_memory_state memory, string goal, string route, string input, string model_path) string {
    if model_path == "" {
        return ""
    }
    agent_memory_lookup_result analysis_result = agent_memory_lookup_long(memory, "analysis")
    string analysis = ""
    if analysis_result.found {
        analysis = analysis_result.value
    }
    string prompt = agent_model_plan_build_prompt(goal, route, analysis, input)
    string response = infer_run(model_path, prompt)
    if trim(response) == "" {
        return ""
    }
    agent_model_parse_field(response, "plan_queue")
}

func agent_model_code_error_context(agent_memory_state memory) string {
    string errors = ""
    agent_memory_lookup_result build_err = agent_memory_lookup_long(memory, "last_build")
    if build_err.found && build_err.value != "" {
        bool is_failure = agent_model_route_line_starts_with(lower(build_err.value), "build:status=failed") || agent_model_route_line_starts_with(lower(build_err.value), "s:status=failed")
        if is_failure {
            errors = errors + "BUILD ERROR:\n" + build_err.value + "\n"
        }
        memory = build_err.state
    }
    agent_memory_lookup_result test_err = agent_memory_lookup_long(memory, "last_test")
    if test_err.found && test_err.value != "" {
        bool is_failure = agent_model_route_line_starts_with(lower(test_err.value), "test:status=failed") || agent_model_route_line_starts_with(lower(test_err.value), "s:status=failed")
        if is_failure {
            errors = errors + "TEST ERROR:\n" + test_err.value + "\n"
        }
        memory = test_err.state
    }
    agent_memory_lookup_result s_err = agent_memory_lookup_long(memory, "last_s")
    if s_err.found && s_err.value != "" {
        bool is_failure = agent_model_route_line_starts_with(lower(s_err.value), "s:status=failed")
        if is_failure {
            errors = errors + "S ERROR:\n" + s_err.value + "\n"
        }
    }
    errors
}

func agent_model_code_build_prompt(agent_memory_state memory, string goal, string route, string input) string {
    string prompt = "You are an expert software engineer. Write a complete, correct implementation.\n\n"
    prompt = prompt + "GOAL: " + goal + "\n"
    prompt = prompt + "TASK: " + input + "\n"
    prompt = prompt + "LANGUAGE/ROUTE: " + route + "\n"
    agent_memory_lookup_result repo_map = agent_memory_lookup_long(memory, "repo_map")
    if repo_map.found && repo_map.value != "" {
        prompt = prompt + "\nREPOSITORY STRUCTURE:\n" + agent_model_clip(repo_map.value, 2000) + "\n"
        memory = repo_map.state
    }
    agent_memory_lookup_result retrieved = agent_memory_lookup_long(memory, "retrieved")
    if retrieved.found && retrieved.value != "" {
        prompt = prompt + "\nEXISTING FILE CONTENT (modify or use as context):\n" + agent_model_clip(retrieved.value, 6000) + "\n"
        memory = retrieved.state
    }
    agent_memory_lookup_result searched = agent_memory_lookup_long(memory, "searched")
    if searched.found && searched.value != "" {
        prompt = prompt + "\nSEARCH RESULTS:\n" + agent_model_clip(searched.value, 2000) + "\n"
        memory = searched.state
    }
    string errors = agent_model_code_error_context(memory)
    if errors != "" {
        prompt = prompt + "\nERROR OUTPUT TO FIX:\n" + errors + "\n"
    }
    agent_memory_lookup_result analysis = agent_memory_lookup_long(memory, "analysis")
    if analysis.found && analysis.value != "" {
        prompt = prompt + "\nANALYSIS: " + analysis.value + "\n"
    }
    prompt = prompt + "\nOutput ALL changed files using this format (repeat for each file):\n"
    prompt = prompt + "path: <relative/path/to/file>\n"
    prompt = prompt + "---BEGIN---\n"
    prompt = prompt + "<complete file content>\n"
    prompt = prompt + "---END---\n"
    prompt = prompt + "\nRepeat the path/---BEGIN---/---END--- block for EACH file that needs to be created or modified.\n"
    prompt = prompt + "Do not add any explanation before the first block or after the last block.\n"
    prompt
}

func agent_model_code_parse(string response) agent_action_state {
    string path = agent_model_parse_field(response, "path")
    string content = agent_model_parse_block(response, "---BEGIN---", "---END---")
    if content == "" {
        content = agent_model_parse_block(response, "---BEGIN CONTENT---", "---END CONTENT---")
    }
    if content == "" {
        content = agent_model_parse_field(response, "content")
    }
    bool structured = path != "" && path != "none" && content != ""
    agent_action_state {
        tool: "code",
        path: path,
        content: content,
        query: "",
        command: "",
        old_text: "",
        new_text: "",
        raw: response,
        replace_all: false,
        structured: structured,
    }
}

func agent_model_code_parse_all_files(string response) string {
    string out = ""
    int pos = 0
    int resp_len = len(response)
    string path_prefix = "path:"
    string begin_marker = "---BEGIN---"
    string end_marker = "---END---"
    int path_prefix_len = len(path_prefix)
    int begin_len = len(begin_marker)
    int end_len = len(end_marker)
    for pos < resp_len {
        int path_start = agent_model_str_find(response, path_prefix, pos)
        if path_start < 0 {
            break
        }
        int line_end = path_start + path_prefix_len
        for line_end < resp_len && string(response[line_end]) != "\n" {
            line_end = line_end + 1
        }
        string raw_path = ""
        int pi = path_start + path_prefix_len
        for pi < line_end {
            raw_path = raw_path + string(response[pi])
            pi = pi + 1
        }
        string file_path = trim(raw_path)
        int begin_pos = agent_model_str_find(response, begin_marker, line_end)
        if begin_pos < 0 {
            break
        }
        int content_start = begin_pos + begin_len
        if content_start < resp_len && string(response[content_start]) == "\n" {
            content_start = content_start + 1
        }
        int end_pos = agent_model_str_find(response, end_marker, content_start)
        if end_pos < 0 {
            break
        }
        string content = ""
        int ci = content_start
        for ci < end_pos {
            content = content + string(response[ci])
            ci = ci + 1
        }
        if file_path != "" && content != "" {
            out = out + "\x00FILE\x00" + file_path + "\x00CONTENT\x00" + content
        }
        pos = end_pos + end_len
    }
    out
}

func agent_model_code(agent_memory_state memory, string goal, string route, string input, string model_path) agent_action_state {
    if model_path == "" {
        return new_agent_action_state()
    }
    string prompt = agent_model_code_build_prompt(memory, goal, route, input)
    string response = infer_run(model_path, prompt)
    if trim(response) == "" {
        return new_agent_action_state()
    }
    agent_model_code_parse(response)
}

func agent_model_verify_build_prompt(string goal, string route, string evidence) string {
    string prompt = "You are a verification agent. Determine whether the goal was achieved.\n\n"
    prompt = prompt + "GOAL: " + goal + "\n"
    prompt = prompt + "ROUTE: " + route + "\n"
    prompt = prompt + "EVIDENCE:\n" + evidence + "\n"
    prompt = prompt + "\nAnswer on the FIRST line with exactly YES or NO.\n"
    prompt = prompt + "Then provide a one-sentence explanation.\n"
    prompt
}

func agent_model_verify(agent_memory_state memory, string goal, string route, string model_path) string {
    if model_path == "" {
        return ""
    }
    string evidence = ""
    agent_memory_lookup_result code_result = agent_memory_lookup_long(memory, "generated_code")
    if code_result.found && code_result.value != "" {
        evidence = evidence + "generated_code: " + agent_model_clip(code_result.value, 2000) + "\n"
        memory = code_result.state
    }
    agent_memory_lookup_result build_result = agent_memory_lookup_long(memory, "last_build")
    if build_result.found && build_result.value != "" {
        evidence = evidence + "last_build: " + agent_model_clip(build_result.value, 600) + "\n"
        memory = build_result.state
    }
    agent_memory_lookup_result test_result = agent_memory_lookup_long(memory, "last_test")
    if test_result.found && test_result.value != "" {
        evidence = evidence + "last_test: " + agent_model_clip(test_result.value, 600) + "\n"
        memory = test_result.state
    }
    agent_memory_lookup_result s_result = agent_memory_lookup_long(memory, "last_s")
    if s_result.found && s_result.value != "" {
        evidence = evidence + "last_s: " + agent_model_clip(s_result.value, 600) + "\n"
        memory = s_result.state
    }
    agent_memory_lookup_result git_diff_result = agent_memory_lookup_long(memory, "last_git_diff")
    if git_diff_result.found && git_diff_result.value != "" {
        evidence = evidence + "git_diff: " + agent_model_clip(git_diff_result.value, 1000) + "\n"
        memory = git_diff_result.state
    }
    agent_memory_lookup_result grep_result = agent_memory_lookup_long(memory, "last_grep")
    if grep_result.found && grep_result.value != "" {
        evidence = evidence + "grep_results: " + agent_model_clip(grep_result.value, 600) + "\n"
        memory = grep_result.state
    }
    agent_memory_lookup_result review_result = agent_memory_lookup_long(memory, "review_result")
    if review_result.found && review_result.value != "" {
        evidence = evidence + "review_result: " + agent_model_clip(review_result.value, 600) + "\n"
        memory = review_result.state
    }
    agent_memory_lookup_result infer_result = agent_memory_lookup_long(memory, "inferred_model")
    if infer_result.found && infer_result.value != "" {
        evidence = evidence + "inferred_model: " + agent_model_clip(infer_result.value, 600) + "\n"
        memory = infer_result.state
    }
    if trim(evidence) == "" {
        return ""
    }
    string prompt = agent_model_verify_build_prompt(goal, route, evidence)
    string response = infer_run(model_path, prompt)
    if trim(response) == "" {
        return ""
    }
    response
}
