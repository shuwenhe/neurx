package neurx.agent.executor

use neurx.agent.tool_registry
use neurx.agent.memory
use neurx.infer

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
    if agent_text_contains(text, "fix") || agent_text_contains(text, "bug") || agent_text_contains(text, "error") || agent_text_contains(text, "implement") || agent_text_contains(text, "patch") || agent_text_contains(text, "refactor") {
        return "code"
    }
    if agent_text_contains(text, "review") || agent_text_contains(text, "audit") || agent_text_contains(text, "check") || agent_text_contains(text, "test") {
        return "review"
    }
    if agent_text_contains(text, "search") || agent_text_contains(text, "lookup") || agent_text_contains(text, "find") {
        return "search"
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
    agent_memory_state next_memory = agent_memory_write_short(memory, "last_input", input)
    next_memory = agent_memory_write_short(next_memory, "goal", goal)
    next_memory = agent_memory_write_short(next_memory, "route", route)

    if task == "analyze" {
        action = "analyze"
        observation = "analysis:" + route
        ok = true
        next_memory = agent_memory_write_long(next_memory, "analysis", route)
    } else if task == "plan" {
        action = "plan"
        observation = "plan:" + route
        ok = true
        next_memory = agent_memory_write_long(next_memory, "plan", route)
    } else if task == "retrieve" {
        if agent_tool_registry_has_enabled(tools, "retrieve") {
            action = "retrieve"
            observation = "retrieved:" + route
            tool_name = "retrieve"
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            tool_retries = agent_tool_registry_retries(tools, tool_name)
            ok = true
            next_memory = agent_memory_write_long(next_memory, "retrieved", route)
        }
    } else if task == "infer" {
        if model_path != "" && agent_tool_registry_has_enabled(tools, "infer") {
            infer_pipeline_state pipeline = new_infer_pipeline_from_checkpoint(input, model_path, 512, 256, 32, 2048)
            action = "infer"
            observation = infer_pipeline_last_observation(pipeline)
            tool_name = "infer"
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            tool_retries = agent_tool_registry_retries(tools, tool_name)
            ok = true
            next_memory = agent_memory_write_long(next_memory, "inferred_model", model_path)
        }
    } else if task == "verify" {
        action = "verify"
        observation = "verified:" + route
        ok = true
        next_memory = agent_memory_write_long(next_memory, "verified", route)
    } else if task == "finalize" {
        action = "finalize"
        observation = "done"
        ok = true
    } else {
        if agent_tool_registry_has_enabled(tools, "search") {
            action = "search"
            observation = "searched:" + route
            tool_name = "search"
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            tool_retries = agent_tool_registry_retries(tools, tool_name)
            ok = true
            next_memory = agent_memory_write_long(next_memory, "searched", route)
        }
    }

    next_memory = agent_memory_write_short(next_memory, "last_action", action)
    next_memory = agent_memory_write_short(next_memory, "last_observation", observation)

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
