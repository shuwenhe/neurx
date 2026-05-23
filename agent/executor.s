package neurx.agent.executor

use neurx.agent.tool_registry
use neurx.agent.memory
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
            analysis_tag = ";" + analysis_result.value
            next_memory = analysis_result.state
        }
        string plan_steps = ""
        if route == "code" {
            plan_steps = "steps=[analyze_code,identify_issue,patch,test]"
        } else if route == "repo" {
            plan_steps = "steps=[inspect_readme,map_modules,trace_entrypoints,summarize_architecture]"
        } else if route == "sql" {
            plan_steps = "steps=[inspect_schema,review_constraints,propose_migration,verify_change]"
        } else if route == "review" {
            plan_steps = "steps=[load_context,check_logic,flag_issues,summarize]"
        } else if route == "search" {
            plan_steps = "steps=[formulate_query,retrieve,rank,return_top]"
        } else {
            plan_steps = "steps=[understand_goal,gather_context,synthesize,respond]"
        }
        observation = "plan:route=" + route + ";" + plan_steps + analysis_tag
        ok = true
        next_memory = agent_memory_write_long(next_memory, "plan", observation)
        next_memory = agent_memory_write_long(next_memory, "plan_queue", plan_steps)
    } else if task == "retrieve" {
        if agent_tool_registry_has_enabled(tools, "retrieve") {
            action = "retrieve"
            tool_name = agent_tool_registry_find_by_capability(tools, "retrieve")
            if tool_name == "" {
                tool_name = "retrieve"
            }
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            tool_retries = agent_tool_registry_retries(tools, tool_name)
            int max_tries = tool_retries + 1
            if max_tries < 1 {
                max_tries = 1
            }

            string index_path = runtime_env_get("NEURX_RETRIEVE_INDEX_PATH", "")
            string doc_path = runtime_env_get("NEURX_RETRIEVE_DOC_PATH", "")
            if doc_path == "" {
                if route == "sql" {
                    if runtime_file_exists("sql/neurx_init.sql") {
                        doc_path = "sql/neurx_init.sql"
                    } else if runtime_file_exists("neurx/sql/neurx_init.sql") {
                        doc_path = "neurx/sql/neurx_init.sql"
                    }
                } else if route == "repo" {
                    if runtime_file_exists("README.md") {
                        doc_path = "README.md"
                    } else if runtime_file_exists("neurx/README.md") {
                        doc_path = "neurx/README.md"
                    } else if runtime_file_exists("doc/README.md") {
                        doc_path = "doc/README.md"
                    } else if runtime_file_exists("neurx/doc/README.md") {
                        doc_path = "neurx/doc/README.md"
                    } else if runtime_file_exists("app/README.md") {
                        doc_path = "app/README.md"
                    } else if runtime_file_exists("neurx/app/README.md") {
                        doc_path = "neurx/app/README.md"
                    }
                }
            }
            string retrieved_content = ""
            int try_i = 0
            while try_i < max_tries {
                if doc_path != "" && runtime_file_exists(doc_path) {
                    string raw = runtime_read_text_file(doc_path)
                    int max_chars = 1024
                    if len(raw) <= max_chars {
                        retrieved_content = raw
                    } else {
                        int ci = 0
                        while ci < max_chars {
                            retrieved_content = retrieved_content + string(raw[ci])
                            ci = ci + 1
                        }
                        retrieved_content = retrieved_content + "...[truncated]"
                    }
                } else if index_path != "" && runtime_file_exists(index_path) {
                    string idx = runtime_read_text_file(index_path)
                    int max_chars = 512
                    if len(idx) <= max_chars {
                        retrieved_content = idx
                    } else {
                        int ci = 0
                        while ci < max_chars {
                            retrieved_content = retrieved_content + string(idx[ci])
                            ci = ci + 1
                        }
                        retrieved_content = retrieved_content + "...[truncated]"
                    }
                }
                if retrieved_content != "" {
                    break
                }
                try_i = try_i + 1
            }

            if retrieved_content != "" {
                observation = "retrieved:route=" + route + ";content=" + retrieved_content
            } else {
                observation = "retrieved:route=" + route + ";source=none"
            }
            ok = true
            next_memory = agent_memory_write_long(next_memory, "retrieved", observation)
        }
    } else if task == "infer" {
        if model_path != "" && agent_tool_registry_has_enabled(tools, "infer") {
            tool_name = "infer"
            tool_timeout_ms = agent_tool_registry_timeout_ms(tools, tool_name)
            tool_retries = agent_tool_registry_retries(tools, tool_name)
            int max_tries = tool_retries + 1
            if max_tries < 1 {
                max_tries = 1
            }
            int try_i = 0
            while try_i < max_tries {
                infer_pipeline_state pipeline = new_infer_pipeline_from_checkpoint(input, model_path, 512, 256, 32, 2048)
                string infer_obs = infer_pipeline_last_observation(pipeline)
                if infer_obs != "" && infer_obs != "tool_unavailable" {
                    action = "infer"
                    observation = infer_obs
                    ok = true
                    next_memory = agent_memory_write_long(next_memory, "inferred_model", model_path)
                    break
                }
                try_i = try_i + 1
            }
            if !ok {
                observation = "tool_unavailable"
            }
        }
    } else if task == "verify" {
        action = "verify"
        agent_memory_lookup_result plan_result = agent_memory_lookup_long(next_memory, "plan")
        string plan_tag = ""
        if plan_result.found {
            plan_tag = ";plan_ok=true"
            next_memory = plan_result.state
        }
        agent_memory_lookup_result infer_result = agent_memory_lookup_long(next_memory, "inferred_model")
        string infer_tag = ""
        if infer_result.found {
            infer_tag = ";infer_used=true"
            next_memory = infer_result.state
        }
        agent_memory_lookup_result retrieved_result = agent_memory_lookup_long(next_memory, "retrieved")
        string retrieved_tag = ""
        if retrieved_result.found {
            retrieved_tag = ";retrieved_ok=true"
            if route == "repo" && (agent_text_contains(retrieved_result.value, "layout") || agent_text_contains(retrieved_result.value, "directory layout") || agent_text_contains(retrieved_result.value, "architecture")) {
                retrieved_tag = retrieved_tag + ";repo_context=true"
            }
            if route == "sql" && agent_text_contains(retrieved_result.value, "create table") {
                retrieved_tag = retrieved_tag + ";schema_context=true"
            }
            next_memory = retrieved_result.state
        }
        observation = "verified:route=" + route + plan_tag + infer_tag + retrieved_tag
        ok = true
        next_memory = agent_memory_write_long(next_memory, "verified", observation)
    } else if task == "finalize" {
        action = "finalize"
        agent_memory_lookup_result verified_result = agent_memory_lookup_long(next_memory, "verified")
        string verified_tag = ""
        if verified_result.found {
            verified_tag = ";" + verified_result.value
            next_memory = verified_result.state
        }
        observation = "done"
        ok = true
        next_memory = agent_memory_write_long(next_memory, "final_summary", "route=" + route + verified_tag)
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
