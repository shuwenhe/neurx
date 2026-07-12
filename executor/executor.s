package neurx.executor.executor

use neurx.agent.tool_registry
use neurx.agent.memory
use neurx.agent.action_schema
use neurx.agent.observation
use neurx.agent.workspace_tools
use neurx.agent.workspace_search
use neurx.inference
use neurx.executor.model_tool_select
use neurx.safety.safety
use neurx.runtime.io.{runtime_env_get, runtime_read_text_file, runtime_file_exists}

struct agent_execute_result {
    agent_tool_registry_state tools
    agent_memory_state memory
    string action
    string observation
    string tool_name
    int tool_timeout_ms
    int tool_retries
    bool ok
}

func agent_text_contains(string text, string pattern) bool {
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

func agent_execute_observation(string kind, string status, string details) string {
    string obs = kind + ":status=" + status
    if trim(details) != "" {
        obs = obs + ";" + details
    }
    obs
}

func agent_execute_clip(string text, int max_chars) string {
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

func agent_execute_observation_value(string observation, string key) string {
    string raw = trim(observation)
    string needle = key + "="
    int i = 0
    while i < len(raw) {
        bool matched = true
        int j = 0
        while j < len(needle) {
            if i + j >= len(raw) || string(raw[i + j]) != string(needle[j]) {
                matched = false
                break
            }
            j = j + 1
        }
        if matched {
            int start = i + len(needle)
            string value = ""
            int k = start
            while k < len(raw) {
                string ch = string(raw[k])
                if ch == ";" || ch == "\n" {
                    break
                }
                value = value + ch
                k = k + 1
            }
            return trim(value)
        }
        i = i + 1
    }
    ""
}

func agent_execute_failure_summary(string kind, string observation) string {
    string summary = kind + ":status=failed"
    string reason = agent_execute_observation_value(observation, "reason")
    if reason == "" {
        reason = "command_failed"
    }
    summary = summary + ";reason=" + reason
    string exit_code = agent_execute_observation_value(observation, "exit_code")
    if exit_code != "" {
        summary = summary + ";exit_code=" + exit_code
    }
    string command = agent_execute_observation_value(observation, "command")
    if command != "" {
        summary = summary + ";command=" + agent_execute_clip(command, 120)
    }
    string output_summary = agent_execute_observation_value(observation, "output_summary")
    if output_summary != "" {
        summary = summary + ";output_summary=" + agent_execute_clip(output_summary, 160)
    }
    string error = agent_execute_observation_value(observation, "error")
    if error != "" {
        summary = summary + ";error=" + agent_execute_clip(error, 120)
    }
    summary
}

func agent_execute_memory_preferred_command(agent_memory_state memory, string key) string {
    agent_memory_lookup_result preferred = agent_memory_lookup_long(memory, key)
    if preferred.found && trim(preferred.value) != "" {
        return trim(preferred.value)
    }
    ""
}

func agent_route_for_goal(string goal, string input) string {
    string text = lower(trim(goal + " " + input))
    if agent_text_contains(text, "delete_path") || agent_text_contains(text, "delete") || agent_text_contains(text, "remove") || agent_text_contains(text, "rm ") || agent_text_contains(text, "trash") {
        return "delete"
    }
    if agent_text_contains(text, "write_file") || agent_text_contains(text, "create_file") || agent_text_contains(text, "create file") || agent_text_contains(text, "write file") || agent_text_contains(text, "new file") || agent_text_contains(text, "make file") || agent_text_contains(text, "touch ") {
        return "write"
    }
    if agent_text_contains(text, "mkdir") || agent_text_contains(text, "create folder") || agent_text_contains(text, "make dir") || agent_text_contains(text, "create directory") || agent_text_contains(text, "new folder") {
        return "mkdir"
    }
    if agent_text_contains(text, "apply_patch") {
        return "apply_patch"
    }
    if agent_text_contains(text, "show pending") || agent_text_contains(text, "show_pending_changes") {
        return "show_pending_changes"
    }
    if agent_text_contains(text, "apply pending") || agent_text_contains(text, "apply_pending_changes") {
        return "apply_pending_changes"
    }
    if agent_text_contains(text, "fix") || agent_text_contains(text, "bug") || agent_text_contains(text, "error") || agent_text_contains(text, "implement") || agent_text_contains(text, "patch") || agent_text_contains(text, "refactor") {
        return "code"
    }
    if agent_text_contains(text, "repo") || agent_text_contains(text, "repository") || agent_text_contains(text, "architecture") || agent_text_contains(text, "module layout") || agent_text_contains(text, "directory layout") || agent_text_contains(text, "entrypoint") || agent_text_contains(text, "readme") {
        return "repo"
    }
    if agent_text_contains(text, "sql") || agent_text_contains(text, "mysql") || agent_text_contains(text, "database") || agent_text_contains(text, "schema") || agent_text_contains(text, "migration") || agent_text_contains(text, "table") || agent_text_contains(text, "ddl") || agent_text_contains(text, "query") {
        return "sql"
    }
    if agent_text_contains(text, "git status") || agent_text_contains(text, "git_status") {
        return "git_status"
    }
    if agent_text_contains(text, "git diff") || agent_text_contains(text, "git_diff") || agent_text_contains(text, "show changes") {
        return "git_diff"
    }
    if agent_text_contains(text, "git log") || agent_text_contains(text, "git_log") || agent_text_contains(text, "commit history") {
        return "git_log"
    }
    if agent_text_contains(text, "git commit") || agent_text_contains(text, "git_commit") {
        return "git_commit"
    }
    if agent_text_contains(text, "grep ") || agent_text_contains(text, "grep_search") || agent_text_contains(text, "text search") {
        return "grep"
    }
    if agent_text_contains(text, "find symbol") || agent_text_contains(text, "find_symbol") || agent_text_contains(text, "go to definition") || agent_text_contains(text, "find definition") {
        return "find_symbol"
    }
    if agent_text_contains(text, "list_dir") || agent_text_contains(text, "list dir") || agent_text_contains(text, "list directory") || agent_text_contains(text, "list files") || agent_text_contains(text, "show files") || agent_text_contains(text, "ls ") {
        return "list_dir"
    }
    if agent_text_contains(text, "search_files") || agent_text_contains(text, "search") || agent_text_contains(text, "lookup") || agent_text_contains(text, "find") {
        return "search"
    }
    if agent_text_contains(text, "run_build") || agent_text_contains(text, "build") || agent_text_contains(text, "compile") {
        return "build"
    }
    if agent_text_contains(text, "read_file") || agent_text_contains(text, "read file") || agent_text_contains(text, "inspect file") {
        return "retrieve"
    }
    if agent_text_contains(text, "run_test") || agent_text_contains(text, "run tests") {
        return "test"
    }
    if agent_text_contains(text, "review") || agent_text_contains(text, "audit") || agent_text_contains(text, "check") {
        return "review"
    }
    if agent_text_contains(text, "shell") || agent_text_contains(text, "bash") || agent_text_contains(text, "run command") || agent_text_contains(text, "execute command") {
        return "s"
    }
    "general"
}

func agent_execute_step(agent_tool_registry_state tools, agent_memory_state memory, string goal, string task, string input, string model_path) agent_execute_result {
    string action = "noop"
    string observation = "tool_unavailable"
    string tool_name = ""
    int tool_timeout_ms = 0
    int tool_retries = 0
    bool ok = false
    bool is_meta = task == "analyze" || task == "plan" || task == "verify" || task == "finalize" || task == "git_status" || task == "git_diff" || task == "git_log" || task == "git_commit"
    agent_action_state parsed_action = agent_action_parse(input, task)
    string route = agent_route_for_goal(goal, input)
    if !is_meta && model_path != "" {
        agent_action_state llm_action = agent_model_tool_call(tools, memory, goal, task, input, model_path)
        if llm_action.structured {
            parsed_action = llm_action
        }
    }
    if parsed_action.tool != "" {
        route = parsed_action.tool
    }
    string dispatch = task
    if !is_meta && parsed_action.tool != "" {
        dispatch = parsed_action.tool
    }
    agent_memory_state next_memory = agent_memory_write_short(memory, "last_input", input)
    next_memory = agent_memory_write_short(next_memory, "goal", goal)
    next_memory = agent_memory_write_short(next_memory, "route", route)
    next_memory = agent_memory_write_long(next_memory, "last_action_schema", agent_action_summary(parsed_action))

    if task == "analyze" {
        action = "analyze"
        next_memory = agent_memory_delete(next_memory, "inferred_route")
        next_memory = agent_memory_delete(next_memory, "searched")
        next_memory = agent_memory_delete(next_memory, "plan_queue")
        next_memory = agent_memory_delete(next_memory, "retrieved")
        agent_memory_lookup_result replan_result = agent_memory_lookup_short(next_memory, "replan_reason")
        string details = "route=" + route
        if replan_result.found && replan_result.value != "" {
            details = details + ";replan=" + replan_result.value
            next_memory = replan_result.state
        }
        agent_memory_lookup_result prior_infer_result = agent_memory_lookup_long(next_memory, "inferred_model")
        if prior_infer_result.found {
            details = details + ";has_prior=infer"
            next_memory = prior_infer_result.state
        }
        if model_path != "" {
            agent_action_state infer_action = agent_model_tool_call(tools, memory, goal, "analyze", input, model_path)
            if infer_action.structured && infer_action.tool != "" {
                next_memory = agent_memory_write_long(next_memory, "inferred_route", infer_action.tool)
                details = details + ";inferred=" + infer_action.tool
            }
        }
        observation = agent_execute_observation("analysis", "ok", details)
        ok = true
        next_memory = agent_memory_write_long(next_memory, "analysis", observation)
    } else if task == "plan" {
        action = "plan"
        agent_memory_lookup_result analysis_result = agent_memory_lookup_long(next_memory, "analysis")
        string details = "task=" + task + ";route=" + route
        if analysis_result.found {
            details = details + ";analysis=" + analysis_result.value
            next_memory = analysis_result.state
        }
        if model_path != "" {
            string plan_queue_raw = agent_model_plan(next_memory, goal, route, input, model_path)
            if plan_queue_raw != "" {
                next_memory = agent_memory_write_long(next_memory, "plan_queue", plan_queue_raw)
                details = details + ";queued=" + plan_queue_raw
            }
        }
        observation = agent_execute_observation("plan", "ok", details)
        ok = true
    } else if dispatch == "retrieve" || dispatch == "read_file" {
        action = "retrieve"
        if agent_tool_registry_has_enabled(tools, "retrieve") {
            tool_name = agent_tool_registry_find_by_capability(tools, "retrieve")
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            tool_retries = agent_tool_registry_retries(tools, tool_name)
            string retrieve_path = parsed_action.path
            if task == "read_file" && retrieve_path != "" {
                agent_workspace_result read_result = agent_workspace_read_file(retrieve_path, 1, 160, 4096)
                observation = read_result.observation
                ok = read_result.ok
            } else {
                string retrieve_query = parsed_action.query
                if retrieve_path != "" {
                    agent_workspace_result read_result = agent_workspace_read_file(retrieve_path, 1, 160, 4096)
                    observation = read_result.observation
                    ok = read_result.ok
                } else {
                    if retrieve_query == "" {
                        retrieve_query = input
                    }
                    agent_search_result search_result = agent_search_workspace(retrieve_query, route, 3, 512)
                    observation = search_result.observation
                    ok = search_result.ok
                }
            }
            if ok {
                next_memory = agent_memory_write_long(next_memory, "retrieved", observation)
            }
        }
    } else if dispatch == "search" || dispatch == "search_files" {
        action = "search"
        if agent_tool_registry_has_enabled(tools, "search") {
            tool_name = agent_tool_registry_find_by_capability(tools, "search")
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            tool_retries = agent_tool_registry_retries(tools, tool_name)
            string search_query = parsed_action.query
            if search_query == "" {
                search_query = parsed_action.path
            }
            if search_query == "" {
                search_query = input
            }
            agent_workspace_result search_files_result = agent_workspace_search_files(search_query, 40)
            observation = search_files_result.observation
            ok = search_files_result.ok
            if !ok {
                agent_search_result fallback_result = agent_search_workspace(search_query, route, 3, 512)
                observation = fallback_result.observation
                ok = fallback_result.ok
            }
            if ok {
                next_memory = agent_memory_write_long(next_memory, "searched", observation)
            }
        }
    } else if dispatch == "infer" {
        action = "infer"
        if model_path != "" && agent_tool_registry_has_enabled(tools, "infer") {
            tool_name = "infer"
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            tool_retries = agent_tool_registry_retries(tools, tool_name)
            string infer_query = parsed_action.query
            if infer_query == "" {
                infer_query = input
            }
            string prompt = "GOAL: " + goal + "\nINPUT: " + infer_query
            agent_memory_lookup_result infer_analysis = agent_memory_lookup_long(next_memory, "analysis")
            if infer_analysis.found && infer_analysis.value != "" {
                prompt = prompt + "\nANALYSIS: " + infer_analysis.value
                next_memory = infer_analysis.state
            }
            agent_memory_lookup_result infer_repo = agent_memory_lookup_long(next_memory, "repo_map")
            if infer_repo.found && infer_repo.value != "" {
                prompt = prompt + "\nREPO_MAP:\n" + agent_execute_clip(infer_repo.value, 800)
                next_memory = infer_repo.state
            }
            agent_memory_lookup_result infer_retrieved = agent_memory_lookup_long(next_memory, "retrieved")
            if infer_retrieved.found && infer_retrieved.value != "" {
                prompt = prompt + "\nCONTEXT:\n" + agent_execute_clip(infer_retrieved.value, 2000)
                next_memory = infer_retrieved.state
            }
            agent_memory_lookup_result infer_searched = agent_memory_lookup_long(next_memory, "searched")
            if infer_searched.found && infer_searched.value != "" {
                prompt = prompt + "\nSEARCH_RESULTS:\n" + agent_execute_clip(infer_searched.value, 800)
                next_memory = infer_searched.state
            }
            agent_memory_lookup_result infer_build_err = agent_memory_lookup_long(next_memory, "last_build_failure_summary")
            if infer_build_err.found && infer_build_err.value != "" {
                prompt = prompt + "\nBUILD_ERROR:\n" + agent_execute_clip(infer_build_err.value, 400)
                next_memory = infer_build_err.state
            }
            string infer_out = infer_run(model_path, prompt)
            observation = agent_execute_observation("infer", "ok", "route=" + route + ";response=" + agent_execute_clip(infer_out, 240))
            ok = trim(infer_out) != ""
            if ok {
                next_memory = agent_memory_write_long(next_memory, "inferred_model", infer_out)
            } else {
                observation = "infer:status=blocked;reason=rejected"
            }
        } else if model_path == "" {
            observation = "infer:status=blocked;reason=model_disabled"
        }
    } else if dispatch == "delete" || dispatch == "delete_path" {
        action = "delete"
        if agent_tool_registry_has_enabled(tools, "delete") {
            tool_name = agent_tool_registry_find_by_capability(tools, "delete")
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            tool_retries = agent_tool_registry_retries(tools, tool_name)
            string del_path = parsed_action.path
            if del_path == "" && !parsed_action.structured && !agent_text_contains(lower(trim(input)), " ") {
                del_path = trim(input)
            }
            if trim(del_path) == "" {
                observation = "delete:status=failed;reason=path_missing"
                ok = false
            } else {
                agent_workspace_result del_result = agent_workspace_delete(del_path)
                observation = del_result.observation
                ok = del_result.ok
            }
        }
    } else if dispatch == "mkdir" || dispatch == "create_directory" {
        action = "mkdir"
        if agent_tool_registry_has_enabled(tools, "mkdir") {
            tool_name = agent_tool_registry_find_by_capability(tools, "mkdir")
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            string mkdir_path = parsed_action.path
            if trim(mkdir_path) == "" && !parsed_action.structured {
                mkdir_path = trim(input)
            }
            if trim(mkdir_path) == "" {
                observation = "mkdir:status=failed;reason=path_missing"
                ok = false
            } else {
                agent_workspace_result mkdir_result = agent_workspace_mkdir(mkdir_path)
                observation = mkdir_result.observation
                ok = mkdir_result.ok
            }
        }
    } else if dispatch == "write" || dispatch == "write_file" || dispatch == "create_file" {
        action = "write"
        if agent_tool_registry_has_enabled(tools, "write") {
            tool_name = agent_tool_registry_find_by_capability(tools, "write")
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            tool_retries = agent_tool_registry_retries(tools, tool_name)
            string write_path = parsed_action.path
            string write_content = parsed_action.content
            if trim(write_path) == "" {
                observation = "write:status=failed;reason=path_missing"
                ok = false
            } else {
                // Allow empty content: creates an empty file (touch semantics).
                agent_workspace_result write_result = agent_workspace_write_file(write_path, write_content)
                observation = write_result.observation
                ok = write_result.ok
            }
        }
    } else if dispatch == "apply_patch" || dispatch == "patch" {
        action = "apply_patch"
        if agent_tool_registry_has_enabled(tools, "apply_patch") {
            tool_name = agent_tool_registry_find_by_capability(tools, "apply_patch")
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            tool_retries = agent_tool_registry_retries(tools, tool_name)
            string patch_path = parsed_action.path
            string patch_old = parsed_action.old_text
            string patch_new = parsed_action.new_text
            bool patch_replace_all = parsed_action.replace_all
            if trim(patch_path) == "" {
                observation = "apply_patch:status=failed;reason=path_missing"
                ok = false
            } else if patch_old == "" || patch_new == "" {
                observation = "apply_patch:status=failed;reason=args_missing;path=" + patch_path
                ok = false
            } else {
                agent_workspace_patch_result patch_result = agent_workspace_patch_file(patch_path, patch_old, patch_new, patch_replace_all)
                observation = patch_result.observation
                ok = patch_result.ok
            }
        }
    } else if dispatch == "build" || dispatch == "run_build" {
        action = "build"
        if agent_tool_registry_has_enabled(tools, "build") {
            tool_name = agent_tool_registry_find_by_capability(tools, "build")
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            tool_retries = agent_tool_registry_retries(tools, tool_name)
            string build_command = parsed_action.command
            if trim(build_command) == "" {
                build_command = agent_execute_memory_preferred_command(next_memory, "preferred_build_command")
            }
            agent_workspace_command_result build_result = agent_workspace_run_command("build", build_command)
            observation = build_result.observation
            ok = build_result.ok
            next_memory = agent_memory_write_long(next_memory, "last_build", observation)
            if !ok {
                next_memory = agent_memory_write_long(next_memory, "last_build_failure_summary", agent_execute_failure_summary("build", observation))
            } else {
                next_memory = agent_memory_delete(next_memory, "last_build_failure_summary")
            }
        }
    } else if dispatch == "test" || dispatch == "run_test" {
        action = "test"
        if agent_tool_registry_has_enabled(tools, "test") {
            tool_name = agent_tool_registry_find_by_capability(tools, "test")
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            tool_retries = agent_tool_registry_retries(tools, tool_name)
            string test_command = parsed_action.command
            if trim(test_command) == "" {
                test_command = agent_execute_memory_preferred_command(next_memory, "preferred_test_command")
            }
            agent_workspace_command_result test_result = agent_workspace_run_command("test", test_command)
            observation = test_result.observation
            ok = test_result.ok
            next_memory = agent_memory_write_long(next_memory, "last_test", observation)
            if !ok {
                next_memory = agent_memory_write_long(next_memory, "last_test_failure_summary", agent_execute_failure_summary("test", observation))
            } else {
                next_memory = agent_memory_delete(next_memory, "last_test_failure_summary")
            }
        }
    } else if dispatch == "code" {
        action = "code"
        if model_path != "" && agent_tool_registry_has_enabled(tools, "code") {
            tool_name = agent_tool_registry_find_by_capability(tools, "code")
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            tool_retries = agent_tool_registry_retries(tools, tool_name)
            string code_path = parsed_action.path
            string code_content = parsed_action.content
            string multi_files = ""
            if code_content == "" {
                // Auto-retrieve the existing file for context when 'retrieved' is empty
                if code_path != "" {
                    agent_memory_lookup_result ar = agent_memory_lookup_long(next_memory, "retrieved")
                    if !ar.found || ar.value == "" {
                        agent_workspace_result auto_read = agent_workspace_read(code_path, 6000)
                        if auto_read.ok {
                            next_memory = agent_memory_write_long(next_memory, "retrieved", auto_read.observation)
                        }
                    }
                }
                agent_action_state gen_action = agent_model_code(next_memory, goal, route, input, model_path)
                if gen_action.structured {
                    multi_files = agent_model_code_parse_all_files(gen_action.raw)
                    code_path = gen_action.path
                    code_content = gen_action.content
                }
            }
            if multi_files != "" {
                string file_sep = "\x00FILE\x00"
                string content_sep = "\x00CONTENT\x00"
                int file_sep_len = len(file_sep)
                int content_sep_len = len(content_sep)
                int mf_pos = 0
                int mf_len = len(multi_files)
                int files_written = 0
                string written_paths = ""
                bool all_ok = true
                while mf_pos < mf_len {
                    int next_file = agent_model_str_find(multi_files, file_sep, mf_pos)
                    if next_file < 0 {
                        break
                    }
                    int path_start = next_file + file_sep_len
                    int content_pos = agent_model_str_find(multi_files, content_sep, path_start)
                    if content_pos < 0 {
                        break
                    }
                    string mf_path = ""
                    int pi = path_start
                    while pi < content_pos {
                        mf_path = mf_path + string(multi_files[pi])
                        pi = pi + 1
                    }
                    int content_start = content_pos + content_sep_len
                    int next_file2 = agent_model_str_find(multi_files, file_sep, content_start)
                    int content_end = mf_len
                    if next_file2 >= 0 {
                        content_end = next_file2
                    }
                    string mf_content = ""
                    int ci = content_start
                    while ci < content_end {
                        mf_content = mf_content + string(multi_files[ci])
                        ci = ci + 1
                    }
                    if trim(mf_path) != "" && trim(mf_content) != "" {
                        agent_workspace_result mf_result = agent_workspace_write(mf_path, mf_content)
                        if mf_result.ok {
                            files_written = files_written + 1
                            if written_paths == "" {
                                written_paths = mf_path
                            } else {
                                written_paths = written_paths + "," + mf_path
                            }
                        } else {
                            all_ok = false
                        }
                    }
                    if next_file2 < 0 {
                        break
                    }
                    mf_pos = next_file2
                }
                ok = all_ok && files_written > 0
                if ok {
                    observation = agent_execute_observation("code", "ok", "files=" + string(files_written) + ";paths=" + written_paths)
                    next_memory = agent_memory_write_long(next_memory, "generated_code", "files=" + string(files_written) + ";paths=" + written_paths)
                } else if files_written > 0 {
                    observation = agent_execute_observation("code", "ok", "files=" + string(files_written) + ";paths=" + written_paths + ";partial=true")
                    next_memory = agent_memory_write_long(next_memory, "generated_code", "files=" + string(files_written) + ";paths=" + written_paths)
                    ok = true
                } else {
                    observation = "code:status=failed;reason=write_failed"
                    ok = false
                }
            } else if trim(code_path) == "" {
                observation = "code:status=failed;reason=path_missing"
                ok = false
            } else if code_content != "" {
                agent_workspace_result code_write_result = agent_workspace_write(code_path, code_content)
                ok = code_write_result.ok
                if ok {
                    observation = agent_execute_observation("code", "ok", "path=" + code_path + ";bytes=" + string(len(code_content)))
                    next_memory = agent_memory_write_long(next_memory, "generated_code", "path=" + code_path + ";bytes=" + string(len(code_content)))
                } else {
                    observation = code_write_result.observation
                }
            } else {
                observation = "code:status=failed;reason=content_missing;path=" + code_path
                ok = false
            }
        } else if model_path != "" {
            observation = "code:status=blocked;reason=tool_disabled"
            ok = false
        } else {
            observation = "code:status=blocked;reason=model_disabled"
        }
    } else if dispatch == "review" {
        action = "review"
        if model_path != "" {
            tool_name = agent_tool_registry_find_by_capability(tools, "review")
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            tool_retries = agent_tool_registry_retries(tools, tool_name)
            string review_path = parsed_action.path
            string file_content = ""
            if review_path != "" {
                agent_workspace_result review_read = agent_workspace_read(review_path, 4096)
                if review_read.ok {
                    file_content = review_read.observation
                }
            }
            if review_path == "" {
                agent_memory_lookup_result retrieved_path = agent_memory_lookup_long(next_memory, "retrieved")
                if retrieved_path.found && retrieved_path.value != "" {
                    file_content = agent_execute_clip(retrieved_path.value, 4096)
                    next_memory = retrieved_path.state
                }
            }
            string review_query = parsed_action.query
            if review_query == "" {
                review_query = input
            }
            string review_prompt = "GOAL: " + goal + "\nREVIEW_REQUEST: " + review_query + "\nFILE_CONTENT:\n" + file_content
            string review_out = infer_run(model_path, review_prompt)
            observation = agent_execute_observation("review", "ok", "path=" + review_path + ";query=" + review_query + ";response=" + agent_execute_clip(review_out, 240))
            ok = trim(review_out) != ""
            if ok {
                next_memory = agent_memory_write_long(next_memory, "review_result", review_out)
            } else {
                observation = "review:status=blocked;reason=rejected"
            }
        } else {
            observation = "review:status=blocked;reason=model_disabled"
        }
    } else if dispatch == "repo" {
        action = "repo"
        string repo_map = agent_workspace_repo_map(120)
        observation = repo_map
        ok = trim(repo_map) != "" && !agent_observation_is_no_progress(repo_map)
        if ok {
            next_memory = agent_memory_write_long(next_memory, "repo_map", repo_map)
        }
    } else if dispatch == "s" || dispatch == "shell" || dispatch == "bash" || dispatch == "run_shell" {
        action = "s"
        if agent_tool_registry_has_enabled(tools, "s") {
            string s_cmd = parsed_action.command
            if s_cmd == "" {
                s_cmd = parsed_action.query
            }
            if s_cmd == "" {
                s_cmd = input
            }
            agent_safety_result s_safety = agent_safety_check("s", s_cmd, goal)
            if !s_safety.allowed {
                observation = agent_execute_observation("s", "blocked", "reason=" + s_safety.reason + ";category=" + s_safety.category + ";severity=" + string(s_safety.severity))
                ok = false
            } else {
                agent_workspace_command_result s_result = agent_workspace_s(s_cmd)
                observation = s_result.observation
                ok = s_result.ok
                next_memory = agent_memory_write_long(next_memory, "last_s", observation)
            }
        } else {
            observation = "s:status=blocked;reason=tool_disabled"
        }
    } else if dispatch == "apply_unified_diff" || dispatch == "unified_diff" || dispatch == "udiff" {
        action = "apply_unified_diff"
        if agent_tool_registry_has_enabled(tools, "apply_patch") {
            string diff_text = parsed_action.content
            if diff_text == "" {
                diff_text = input
            }
            agent_workspace_result diff_result = agent_workspace_apply_unified_diff(diff_text)
            observation = diff_result.observation
            ok = diff_result.ok
        } else {
            observation = "apply_unified_diff:status=blocked;reason=tool_disabled"
        }
    } else if dispatch == "git_status" {
        action = "git_status"
        if agent_tool_registry_has_enabled(tools, "git_status") {
            agent_workspace_command_result gs_result = agent_workspace_git_status()
            observation = gs_result.observation
            ok = gs_result.ok
            next_memory = agent_memory_write_long(next_memory, "last_git_status", observation)
        } else {
            observation = "git_status:status=blocked;reason=tool_disabled"
        }
    } else if dispatch == "git_diff" {
        action = "git_diff"
        if agent_tool_registry_has_enabled(tools, "git_diff") {
            string diff_args = parsed_action.query
            if diff_args == "" {
                diff_args = parsed_action.command
            }
            agent_workspace_command_result gd_result = agent_workspace_git_diff(diff_args)
            observation = gd_result.observation
            ok = gd_result.ok
            next_memory = agent_memory_write_long(next_memory, "last_git_diff", observation)
        } else {
            observation = "git_diff:status=blocked;reason=tool_disabled"
        }
    } else if dispatch == "git_log" {
        action = "git_log"
        if agent_tool_registry_has_enabled(tools, "git_log") {
            agent_workspace_command_result gl_result = agent_workspace_git_log(10)
            observation = gl_result.observation
            ok = gl_result.ok
            next_memory = agent_memory_write_long(next_memory, "last_git_log", observation)
        } else {
            observation = "git_log:status=blocked;reason=tool_disabled"
        }
    } else if dispatch == "git_commit" {
        action = "git_commit"
        if agent_tool_registry_has_enabled(tools, "git_commit") {
            string commit_msg = parsed_action.query
            if commit_msg == "" {
                commit_msg = parsed_action.command
            }
            if commit_msg == "" {
                commit_msg = input
            }
            agent_workspace_command_result gc_result = agent_workspace_git_commit(commit_msg)
            observation = gc_result.observation
            ok = gc_result.ok
            next_memory = agent_memory_write_long(next_memory, "last_git_commit", observation)
        } else {
            observation = "git_commit:status=blocked;reason=tool_disabled"
        }
    } else if dispatch == "grep" || dispatch == "grep_search" {
        action = "grep"
        if agent_tool_registry_has_enabled(tools, "grep") {
            string grep_pattern = parsed_action.query
            if grep_pattern == "" {
                grep_pattern = input
            }
            string grep_glob = parsed_action.path
            agent_workspace_result grep_result = agent_workspace_grep(grep_pattern, grep_glob, 40)
            observation = grep_result.observation
            ok = grep_result.ok
            next_memory = agent_memory_write_long(next_memory, "last_grep", observation)
            next_memory = agent_memory_write_long(next_memory, "searched", observation)
        } else {
            observation = "grep:status=blocked;reason=tool_disabled"
        }
    } else if dispatch == "find_symbol" || dispatch == "symbol" || dispatch == "find_definition" {
        action = "find_symbol"
        if agent_tool_registry_has_enabled(tools, "find_symbol") {
            string sym = parsed_action.query
            if sym == "" {
                sym = input
            }
            string sym_ext = parsed_action.path
            agent_workspace_result sym_result = agent_workspace_find_symbol(sym, sym_ext)
            observation = sym_result.observation
            ok = sym_result.ok
            next_memory = agent_memory_write_long(next_memory, "last_find_symbol", observation)
            next_memory = agent_memory_write_long(next_memory, "searched", observation)
        } else {
            observation = "find_symbol:status=blocked;reason=tool_disabled"
        }
    } else if dispatch == "list_dir" {
        action = "list_dir"
        if agent_tool_registry_has_enabled(tools, "list_dir") {
            string ld_path = parsed_action.path
            if ld_path == "" {
                ld_path = "."
            }
            agent_workspace_result ld_result = agent_workspace_list_dir(ld_path, 200)
            observation = ld_result.observation
            ok = ld_result.ok
            next_memory = agent_memory_write_long(next_memory, "last_list_dir", observation)
        } else {
            observation = "list_dir:status=blocked;reason=tool_disabled"
        }
    } else if dispatch == "sql" {
        action = "sql"
        if agent_tool_registry_has_enabled(tools, "sql") {
            tool_name = agent_tool_registry_find_by_capability(tools, "sql")
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            tool_retries = agent_tool_registry_retries(tools, tool_name)
            string sql_query = parsed_action.query
            if sql_query == "" {
                sql_query = parsed_action.content
            }
            if sql_query == "" {
                sql_query = input
            }
            agent_workspace_command_result sql_result = agent_workspace_sql_run(sql_query)
            observation = sql_result.observation
            ok = sql_result.ok
            next_memory = agent_memory_write_long(next_memory, "last_sql", observation)
            if !ok {
                next_memory = agent_memory_write_long(next_memory, "last_sql_failure_summary", agent_execute_failure_summary("sql", observation))
            } else {
                next_memory = agent_memory_delete(next_memory, "last_sql_failure_summary")
            }
        } else {
            observation = "sql:status=blocked;reason=tool_disabled"
        }
    } else if dispatch == "subagent" || dispatch == "spawn_subagent" {
        action = "subagent"
        string sub_goal = parsed_action.query
        if sub_goal == "" {
            sub_goal = goal
        }
        string sub_input = input
        int sub_max_steps = 16
        next_memory = agent_memory_write_long(next_memory, "subagent_goal", sub_goal)
        next_memory = agent_memory_write_long(next_memory, "subagent_input", sub_input)
        next_memory = agent_memory_write_short(next_memory, "subagent_max_steps", string(sub_max_steps))
        observation = "subagent:status=ok;goal=" + agent_execute_clip(sub_goal, 80)
        ok = true
    } else if task == "verify" {
        action = "verify"
        string verify_details = "route=" + route
        agent_memory_lookup_result vbuild = agent_memory_lookup_long(next_memory, "last_build")
        if vbuild.found {
            verify_details = verify_details + ";build=" + agent_execute_clip(vbuild.value, 120)
            next_memory = vbuild.state
        }
        agent_memory_lookup_result vbuild_summary = agent_memory_lookup_long(next_memory, "last_build_failure_summary")
        if vbuild_summary.found && vbuild_summary.value != "" {
            verify_details = verify_details + ";build_failure_summary=" + agent_execute_clip(vbuild_summary.value, 160)
            next_memory = vbuild_summary.state
        }
        agent_memory_lookup_result vtest = agent_memory_lookup_long(next_memory, "last_test")
        if vtest.found {
            verify_details = verify_details + ";test=" + agent_execute_clip(vtest.value, 120)
            next_memory = vtest.state
        }
        agent_memory_lookup_result vtest_summary = agent_memory_lookup_long(next_memory, "last_test_failure_summary")
        if vtest_summary.found && vtest_summary.value != "" {
            verify_details = verify_details + ";test_failure_summary=" + agent_execute_clip(vtest_summary.value, 160)
            next_memory = vtest_summary.state
        }
        agent_memory_lookup_result vcode = agent_memory_lookup_long(next_memory, "generated_code")
        if vcode.found {
            verify_details = verify_details + ";code=" + agent_execute_clip(vcode.value, 80)
            next_memory = vcode.state
        }
        if model_path != "" {
            string verify_response = agent_model_verify(next_memory, goal, route, model_path)
            if trim(verify_response) != "" {
                next_memory = agent_memory_write_long(next_memory, "verify_summary", verify_response)
                string first_line = ""
                int vri = 0
                while vri < len(verify_response) {
                    if string(verify_response[vri]) == "\n" {
                        break
                    }
                    first_line = first_line + string(verify_response[vri])
                    vri = vri + 1
                }
                string vfl = lower(trim(first_line))
                if agent_text_contains(vfl, "no") || agent_text_contains(vfl, "fail") || agent_text_contains(vfl, "not achieved") {
                    observation = agent_execute_observation("verify", "failed", "reason=goal_not_met;" + verify_details)
                    ok = false
                } else {
                    verify_details = verify_details + ";llm=confirmed"
                    observation = agent_execute_observation("verify", "ok", verify_details)
                    ok = true
                }
            } else {
                observation = agent_execute_observation("verify", "ok", verify_details)
                ok = true
            }
        } else {
            observation = agent_execute_observation("verify", "ok", verify_details)
            ok = true
        }
    } else if task == "finalize" {
        action = "finalize"
        string final_answer = "goal=" + goal
        agent_memory_lookup_result fa_git_status = agent_memory_lookup_long(next_memory, "last_git_status")
        if fa_git_status.found && fa_git_status.value != "" {
            final_answer = final_answer + "\ngit_status=" + agent_execute_clip(fa_git_status.value, 400)
            next_memory = fa_git_status.state
        }
        agent_memory_lookup_result fa_git_log = agent_memory_lookup_long(next_memory, "last_git_log")
        if fa_git_log.found && fa_git_log.value != "" {
            final_answer = final_answer + "\ngit_log=" + agent_execute_clip(fa_git_log.value, 400)
            next_memory = fa_git_log.state
        }
        agent_memory_lookup_result fa_find_sym = agent_memory_lookup_long(next_memory, "last_find_symbol")
        if fa_find_sym.found && fa_find_sym.value != "" {
            final_answer = final_answer + "\nfind_symbol=" + agent_execute_clip(fa_find_sym.value, 400)
            next_memory = fa_find_sym.state
        }
        agent_memory_lookup_result fa_last_grep = agent_memory_lookup_long(next_memory, "last_grep")
        if fa_last_grep.found && fa_last_grep.value != "" {
            final_answer = final_answer + "\ngrep_results=" + agent_execute_clip(fa_last_grep.value, 400)
            next_memory = fa_last_grep.state
        }
        agent_memory_lookup_result fa_code = agent_memory_lookup_long(next_memory, "generated_code")
        if fa_code.found && fa_code.value != "" {
            final_answer = final_answer + "\ngenerated_code=" + fa_code.value
            next_memory = fa_code.state
        }
        agent_memory_lookup_result fa_verify = agent_memory_lookup_long(next_memory, "verify_summary")
        if fa_verify.found && fa_verify.value != "" {
            final_answer = final_answer + "\nverify_summary=" + agent_execute_clip(fa_verify.value, 512)
            next_memory = fa_verify.state
        }
        agent_memory_lookup_result fa_review = agent_memory_lookup_long(next_memory, "review_result")
        if fa_review.found && fa_review.value != "" {
            final_answer = final_answer + "\nreview_result=" + agent_execute_clip(fa_review.value, 512)
            next_memory = fa_review.state
        }
        agent_memory_lookup_result fa_infer = agent_memory_lookup_long(next_memory, "inferred_model")
        if fa_infer.found && fa_infer.value != "" {
            final_answer = final_answer + "\ninferred=" + agent_execute_clip(fa_infer.value, 512)
            next_memory = fa_infer.state
        }
        agent_memory_lookup_result fa_build = agent_memory_lookup_long(next_memory, "last_build")
        if fa_build.found && fa_build.value != "" {
            final_answer = final_answer + "\nbuild=" + agent_execute_clip(fa_build.value, 240)
            next_memory = fa_build.state
        }
        agent_memory_lookup_result fa_test = agent_memory_lookup_long(next_memory, "last_test")
        if fa_test.found && fa_test.value != "" {
            final_answer = final_answer + "\ntest=" + agent_execute_clip(fa_test.value, 240)
            next_memory = fa_test.state
        }
        agent_memory_lookup_result fa_s = agent_memory_lookup_long(next_memory, "last_s")
        if fa_s.found && fa_s.value != "" {
            final_answer = final_answer + "\ns=" + agent_execute_clip(fa_s.value, 240)
            next_memory = fa_s.state
        }
        agent_memory_lookup_result fa_sql = agent_memory_lookup_long(next_memory, "last_sql")
        if fa_sql.found && fa_sql.value != "" {
            final_answer = final_answer + "\nsql=" + agent_execute_clip(fa_sql.value, 400)
            next_memory = fa_sql.state
        }
        agent_memory_lookup_result fa_git_commit = agent_memory_lookup_long(next_memory, "last_git_commit")
        if fa_git_commit.found && fa_git_commit.value != "" {
            final_answer = final_answer + "\ngit_commit=" + agent_execute_clip(fa_git_commit.value, 240)
            next_memory = fa_git_commit.state
        }
        agent_memory_lookup_result fa_git_diff = agent_memory_lookup_long(next_memory, "last_git_diff")
        if fa_git_diff.found && fa_git_diff.value != "" {
            final_answer = final_answer + "\ngit_diff=" + agent_execute_clip(fa_git_diff.value, 400)
            next_memory = fa_git_diff.state
        }
        agent_memory_lookup_result fa_subagents = agent_memory_lookup_long(next_memory, "subagent_results")
        if !fa_subagents.found {
            int sai = 0
            string sub_agg = ""
            agent_memory_lookup_result sub_check = agent_memory_lookup_long(next_memory, "subagent_result_sub_0")
            while sub_check.found && sub_check.value != "" {
                if sub_agg != "" {
                    sub_agg = sub_agg + "\n"
                }
                sub_agg = sub_agg + "sub_" + string(sai) + ": " + agent_execute_clip(sub_check.value, 300)
                sai = sai + 1
                next_memory = sub_check.state
                sub_check = agent_memory_lookup_long(next_memory, "subagent_result_sub_" + string(sai))
            }
            if sub_agg != "" {
                final_answer = final_answer + "\nsubagent_results=" + sub_agg
            }
        } else if fa_subagents.value != "" {
            final_answer = final_answer + "\nsubagent_results=" + agent_execute_clip(fa_subagents.value, 600)
            next_memory = fa_subagents.state
        }
        next_memory = agent_memory_write_long(next_memory, "final_answer", final_answer)
        observation = "done"
        ok = true
    }

    agent_execute_result {
        tools: tools,
        memory: next_memory,
        action: action,
        observation: observation,
        tool_name: tool_name,
        tool_timeout_ms: tool_timeout_ms,
        tool_retries: tool_retries,
        ok: ok,
    }
}

func agent_execute_result_state_dict(agent_execute_result result) agent_execute_result {
    result
}

func agent_execute_result_load_state_dict(agent_execute_result result, agent_execute_result other) agent_execute_result {
    other
}
