package neurx.executor.executor

use neurx.agent.tool_registry
use neurx.agent.memory
use neurx.agent.action_schema
use neurx.agent.workspace_tools
use neurx.agent.workspace_search
use neurx.infer
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

func agent_route_for_goal(string goal, string input) string {
    string text = lower(trim(goal + " " + input))
    if agent_text_contains(text, "delete") || agent_text_contains(text, "remove") || agent_text_contains(text, "rm ") || agent_text_contains(text, "trash") {
        return "delete"
    }
    if agent_text_contains(text, "create file") || agent_text_contains(text, "write file") || agent_text_contains(text, "new file") || agent_text_contains(text, "mkdir") || agent_text_contains(text, "create folder") || agent_text_contains(text, "make dir") {
        return "write"
    }
    if agent_text_contains(text, "apply_patch") {
        return "apply_patch"
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
    if agent_text_contains(text, "review") || agent_text_contains(text, "audit") || agent_text_contains(text, "check") || agent_text_contains(text, "test") {
        return "review"
    }
    if agent_text_contains(text, "search") || agent_text_contains(text, "lookup") || agent_text_contains(text, "find") {
        return "search"
    }
    if agent_text_contains(text, "build") || agent_text_contains(text, "compile") {
        return "build"
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
    string route = agent_route_for_goal(goal, input)
    agent_action_state parsed_action = agent_action_parse(input, task)
    agent_memory_state next_memory = agent_memory_write_short(memory, "last_input", input)
    next_memory = agent_memory_write_short(next_memory, "goal", goal)
    next_memory = agent_memory_write_short(next_memory, "route", route)
    next_memory = agent_memory_write_long(next_memory, "last_action_schema", agent_action_summary(parsed_action))

    if task == "analyze" {
        action = "analyze"
        agent_memory_lookup_result replan_result = agent_memory_lookup_short(next_memory, "replan_reason")
        string context_tag = ""
        if replan_result.found && replan_result.value != "" {
            context_tag = ";replan=" + replan_result.value
            next_memory = replan_result.state
        }
        agent_memory_lookup_result prior_infer_result = agent_memory_lookup_long(next_memory, "inferred_model")
        string prior_tag = ""
        if prior_infer_result.found {
            prior_tag = ";has_prior=infer"
            next_memory = prior_infer_result.state
        }
        observation = "analysis:route=" + route + context_tag + prior_tag
        ok = true
        next_memory = agent_memory_write_long(next_memory, "analysis", observation)
    } else if task == "plan" {
        action = "plan"
        agent_memory_lookup_result analysis_result = agent_memory_lookup_long(next_memory, "analysis")
        string analysis_tag = ""
        if analysis_result.found {
            analysis_tag = ";analysis=" + analysis_result.value
            next_memory = analysis_result.state
        }
        observation = "plan:task=" + task + ";route=" + route + analysis_tag
        ok = true
    } else if task == "retrieve" {
        action = "retrieve"
        if agent_tool_registry_has_enabled(tools, "retrieve") {
            tool_name = agent_tool_registry_find_by_capability(tools, "retrieve")
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            tool_retries = agent_tool_registry_retries(tools, tool_name)
            agent_search_result search_result = agent_search_workspace(input, route, 3, 512)
            observation = search_result.observation
            ok = search_result.ok
            if ok {
                next_memory = agent_memory_write_long(next_memory, "retrieved", observation)
            }
        }
    } else if task == "infer" {
        action = "infer"
        if model_path != "" && agent_tool_registry_has_enabled(tools, "infer") {
            tool_name = "infer"
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            tool_retries = agent_tool_registry_retries(tools, tool_name)
            string prompt = "goal=" + goal + "\ninput=" + input
            string infer_out = infer_run(model_path, prompt)
            observation = infer_out
            ok = trim(infer_out) != ""
            if ok {
                next_memory = agent_memory_write_long(next_memory, "inferred_model", infer_out)
            } else {
                observation = "infer:rejected"
            }
        } else if model_path == "" {
            observation = "local_model_config_missing: disabled"
        }
    } else if task == "delete" {
        action = "delete"
        if agent_tool_registry_has_enabled(tools, "delete") {
            tool_name = agent_tool_registry_find_by_capability(tools, "delete")
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            tool_retries = agent_tool_registry_retries(tools, tool_name)
            observation = agent_workspace_delete(input)
            ok = !agent_text_contains(observation, "error")
        }
    } else if task == "write" {
        action = "write"
        if agent_tool_registry_has_enabled(tools, "write") {
            tool_name = agent_tool_registry_find_by_capability(tools, "write")
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            tool_retries = agent_tool_registry_retries(tools, tool_name)
            observation = agent_workspace_write(input)
            ok = !agent_text_contains(observation, "error")
        }
    } else if task == "apply_patch" || task == "patch" {
        action = "apply_patch"
        if agent_tool_registry_has_enabled(tools, "apply_patch") {
            tool_name = agent_tool_registry_find_by_capability(tools, "apply_patch")
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            tool_retries = agent_tool_registry_retries(tools, tool_name)
            observation = agent_workspace_apply_patch(input)
            ok = !agent_text_contains(observation, "error")
        }
    } else if task == "build" {
        action = "build"
        if agent_tool_registry_has_enabled(tools, "build") {
            tool_name = agent_tool_registry_find_by_capability(tools, "build")
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            tool_retries = agent_tool_registry_retries(tools, tool_name)
            observation = "build:not_implemented"
            ok = false
        }
    } else if task == "test" {
        action = "test"
        if agent_tool_registry_has_enabled(tools, "test") {
            tool_name = agent_tool_registry_find_by_capability(tools, "test")
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            tool_retries = agent_tool_registry_retries(tools, tool_name)
            observation = "test:not_implemented"
            ok = false
        }
    } else if task == "verify" {
        action = "verify"
        observation = "verify:route=" + route
        ok = true
    } else if task == "finalize" {
        action = "finalize"
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
