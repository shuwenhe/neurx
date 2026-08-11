package neurx.agent.runtime
use neurx.planner
use neurx.agent.memory
use neurx.agent.action_schema
use neurx.agent.tool_registry
use neurx.executor.executor.{agent_execute_step, agent_text_contains}
use neurx.agent.trace
use neurx.registry.skill_registry
use neurx.agent.skill_feedback
use neurx.agent.skill_synthesizer
use neurx.agent.skill_evaluator
use neurx.agent.skill_executor
use neurx.reflection
use neurx.context.context_manager
use neurx.context.context_builder
use neurx.reasoning.reasoning
use neurx.agent.subagent
use neurx.perception.perception
use neurx.agent.answer_synthesizer
use neurx.agent.observation
use neurx.agent.interrupt
use neurx.safety.safety
use neurx.session.session
use neurx.agent.workspace_tools
use neurx.runtime.io.{runtime_env_get, runtime_write_text_file, runtime_read_text_file, runtime_file_exists}
use neurx.agent.call_trace
struct agent_runtime_state {
    agent_plan_state plan
    agent_memory_state memory
    agent_tool_registry_state tools
    agent_trace_state trace
    agent_skill_registry_state skills
    agent_skill_execution_state skill_execution
    agent_reflection_state reflection
    agent_context_state context
    agent_reasoning_state reasoning
    agent_subagent_registry_state subagents
    agent_answer_state answer
    agent_interrupt_state interrupt
    agent_session_state session
    int steps
    bool finished
    string last_action
    string last_observation
    string model_path
}

func trim_or_empty(string value) string {
    string next = trim(value)
    next
}

func agent_runtime_observation(string kind, string status, string details) string {
    string obs = kind + ":status=" + status
    if trim(details) != "" {
        obs = obs + ";" + details
    }
    obs
}

func agent_runtime_finalize_memory(agent_memory_state memory_state, agent_trace_state trace_state) agent_memory_state {
    agent_memory_lookup_result final_result = agent_memory_lookup_long(memory_state, "final_answer")
    if final_result.found && trim(final_result.value) != "" {
        return memory_state
    }
    string fallback = agent_trace_last_progress_observation(trace_state)
    if trim(fallback) == "" {
        return memory_state
    }
    agent_memory_write_long(memory_state, "final_answer", fallback)
}

func agent_runtime_max_repair_attempts() int {
    2
}

func agent_runtime_repair_attempt_count(agent_memory_state memory_state) int {
    agent_memory_lookup_result count_result = agent_memory_lookup_short(memory_state, "repair_attempt_count")
    if !count_result.found || trim(count_result.value) == "" {
        return 0
    }
    string raw = count_result.value
    int value = 0
    int i = 0
    while i < len(raw) {
        if s_char_is_digit(raw, i) {
            value = value * 10 + s_char_digit_val(raw, i)
        }
        i = i + 1
    }
    value
}

func agent_runtime_clear_repair_state(agent_memory_state memory_state) agent_memory_state {
    agent_memory_state next = memory_state
    next = agent_memory_delete(next, "repair_attempt_count")
    next = agent_memory_delete(next, "repair_last_failure")
    next = agent_memory_delete(next, "repair_last_failure_kind")
    next = agent_memory_delete(next, "repair_failure_summary")
    next
}

func agent_runtime_record_repair_failure(agent_memory_state memory_state, string task, string observation) agent_memory_state {
    int attempts = agent_runtime_repair_attempt_count(memory_state) + 1
    agent_memory_state next = agent_memory_write_short(memory_state, "repair_attempt_count", string(attempts))
    next = agent_memory_write_long(next, "repair_last_failure", observation)
    next = agent_memory_write_short(next, "repair_last_failure_kind", lower(trim(task)))
    next
}

func agent_runtime_preferred_failure_summary(agent_memory_state memory_state, string task, string observation) string {
    string kind = lower(trim(task))
    agent_memory_lookup_result summary_result = agent_memory_lookup_long(memory_state, "last_" + kind + "_failure_summary")
    if summary_result.found && trim(summary_result.value) != "" {
        return summary_result.value
    }
    agent_memory_lookup_result repair_result = agent_memory_lookup_long(summary_result.state, "repair_last_failure")
    if repair_result.found && trim(repair_result.value) != "" {
        return repair_result.value
    }
    observation
}

func agent_runtime_repair_failure_summary(string task, string failure_summary_source, int attempts, int limit, string reason) string {
    string details = "kind=" + lower(trim(task))
    details = details + ";attempts=" + string(attempts)
    details = details + ";limit=" + string(limit)
    details = details + ";reason=" + reason
    if trim(failure_summary_source) != "" {
        details = details + ";last_failure=" + agent_workspace_clip(failure_summary_source, 200)
    }
    agent_runtime_observation("repair", "failed", details)
}

func agent_runtime_finish_after_repair_failure(agent_runtime_state state, agent_plan_state next_plan, agent_memory_state memory_state, agent_execute_result result, string input, string failure_summary) agent_runtime_state {
    agent_memory_state final_memory = agent_memory_write_long(memory_state, "repair_failure_summary", failure_summary)
    final_memory = agent_memory_write_long(final_memory, "final_answer", failure_summary)
    agent_reflection_state next_reflection = agent_reflect(
        state.reflection, state.plan.goal, result.action, failure_summary, state.steps + 1
    )
    agent_trace_state next_trace = agent_trace_append(
        state.trace,
        state.steps + 1,
        state.plan.current_task,
        "",
        result.action,
        failure_summary,
        state.skill_execution.active_skill,
        result.tool_name,
        result.tool_timeout_ms,
        result.tool_retries,
        false
    )
    agent_reasoning_state next_reasoning = agent_reasoning_for_goal(
        state.reasoning, state.plan.goal, state.last_observation
    )
    agent_context_state next_context = agent_context_smart_compress(
        agent_context_append(state.context, input),
        state.model_path
    )
    next_context = agent_context_append(next_context, failure_summary)
    next_context = agent_context_build_from_memory(next_context, final_memory)
    agent_session_state next_session = agent_session_assistant(agent_session_user(state.session, input), failure_summary)
    agent_skill_registry_state next_skills = agent_runtime_update_skills(state, next_trace, final_memory)
    agent_skill_execution_state next_skill_execution = agent_skill_execute(next_skills, "complete")
    agent_answer_state next_answer = agent_answer_synthesize(state.answer, next_trace, final_memory, state.steps + 1)
    agent_runtime_state finished_state = agent_runtime_state {
        plan: next_plan,
        memory: final_memory,
        tools: result.tools,
        trace: next_trace,
        skills: next_skills,
        skill_execution: next_skill_execution,
        reflection: next_reflection,
        context: next_context,
        reasoning: next_reasoning,
        subagents: state.subagents,
        answer: next_answer,
        interrupt: state.interrupt,
        session: next_session,
        steps: state.steps + 1,
        finished: true,
        last_action: result.action,
        last_observation: failure_summary,
        model_path: state.model_path,
    }
    agent_runtime_persist_skill_snapshot(finished_state, ".neurx_skills.snapshot")
    finished_state
}

func agent_runtime_requires_approval(string task) bool {
    string t = lower(trim(task))
    t == "write" || t == "write_file" || t == "create_file" || t == "mkdir" || t == "create_directory" || t == "delete" || t == "delete_path" || t == "apply_patch" || t == "patch" || t == "code"
}

func agent_runtime_approval_matches(string granted, string task) bool {
    string g = lower(trim(granted))
    string t = lower(trim(task))
    if g == "" || t == "" {
        return false
    }
    if g == "all" {
        return true
    }
    if g == t {
        return true
    }
    if g == "write" && t == "write_file" {
        return true
    }
    if g == "write" && t == "create_file" {
        return true
    }
    if g == "delete" && t == "delete_path" {
        return true
    }
    if g == "apply_patch" && t == "patch" {
        return true
    }
    if g == "mkdir" && t == "create_directory" {
        return true
    }
    false
}

func agent_runtime_interrupt_observation(string reason, string action) string {
    string details = "reason=" + reason
    if trim(action) != "" {
        details = details + ";action=" + action
    }
    agent_runtime_observation("interrupt", "blocked", details)
}

func agent_runtime_pending_count(agent_memory_state memory_state) int {
    agent_memory_lookup_result count_result = agent_memory_lookup_short(memory_state, "pending_change_count")
    if !count_result.found || trim(count_result.value) == "" {
        return 0
    }
    string raw = count_result.value
    int value = 0
    int i = 0
    while i < len(raw) {
        if s_char_is_digit(raw, i) {
            value = value * 10 + s_char_digit_val(raw, i)
        }
        i = i + 1
    }
    value
}

func agent_runtime_pending_change_path(string action, string raw_input) string {
    agent_action_state parsed = agent_action_parse(raw_input, action)
    string path = trim(parsed.path)
    if path != "" {
        return path
    }
    if action == "delete" || action == "delete_path" {
        return trim(raw_input)
    }
    ""
}

func agent_runtime_pending_change_preview(string action, string raw_input) string {
    agent_action_state parsed = agent_action_parse(raw_input, action)
    if action == "write" || action == "write_file" || action == "create_file" || action == "code" {
        return agent_workspace_clip(parsed.content, 180)
    }
    if action == "mkdir" || action == "create_directory" {
        return "mkdir " + agent_runtime_pending_change_path(action, raw_input)
    }
    if action == "apply_patch" || action == "patch" {
        return "old=" + agent_workspace_clip(parsed.old_text, 80) + " new=" + agent_workspace_clip(parsed.new_text, 80)
    }
    if action == "delete" || action == "delete_path" {
        return "delete " + agent_runtime_pending_change_path(action, raw_input)
    }
    agent_workspace_clip(raw_input, 180)
}

func agent_runtime_stage_pending_change(agent_memory_state memory_state, string action, string raw_input) agent_memory_state {
    int count = agent_runtime_pending_count(memory_state)
    string idx = string(count)
    agent_memory_state next = agent_memory_write_long(memory_state, "pending_change_action_" + idx, action)
    next = agent_memory_write_long(next, "pending_change_input_" + idx, raw_input)
    string path = agent_runtime_pending_change_path(action, raw_input)
    if path != "" {
        next = agent_memory_write_long(next, "pending_change_path_" + idx, path)
    }
    string preview = agent_runtime_pending_change_preview(action, raw_input)
    if preview != "" {
        next = agent_memory_write_long(next, "pending_change_preview_" + idx, preview)
    }
    next = agent_memory_write_short(next, "pending_change_count", string(count + 1))
    next
}

func agent_runtime_pending_summary(agent_memory_state memory_state) string {
    int count = agent_runtime_pending_count(memory_state)
    if count <= 0 {
        return agent_runtime_observation("show_pending_changes", "no_progress", "pending_change_count=0")
    }
    string out = agent_runtime_observation("show_pending_changes", "ok", "pending_change_count=" + string(count))
    int i = 0
    while i < count {
        string idx = string(i)
        agent_memory_lookup_result action_result = agent_memory_lookup_long(memory_state, "pending_change_action_" + idx)
        agent_memory_lookup_result input_result = agent_memory_lookup_long(action_result.state, "pending_change_input_" + idx)
        agent_memory_lookup_result path_result = agent_memory_lookup_long(input_result.state, "pending_change_path_" + idx)
        agent_memory_lookup_result preview_result = agent_memory_lookup_long(path_result.state, "pending_change_preview_" + idx)
        out = out + "\npending_change[" + idx + "].action=" + action_result.value
        if trim(path_result.value) != "" {
            out = out + "\npending_change[" + idx + "].path=" + path_result.value
        }
        if trim(preview_result.value) != "" {
            out = out + "\npending_change[" + idx + "].preview=" + preview_result.value
        }
        i = i + 1
    }
    out
}

func agent_runtime_apply_staged_change(string action, string raw_input) string {
    agent_action_state parsed = agent_action_parse(raw_input, action)
    if action == "write" || action == "write_file" || action == "create_file" {
        string write_path = parsed.path
        string write_content = parsed.content
        if write_path == "" {
            return agent_runtime_observation("apply_pending_changes", "failed", "action=write;reason=path_missing")
        }
        return agent_workspace_write(write_path, write_content).observation
    }
    if action == "delete" || action == "delete_path" {
        string del_path = parsed.path
        if del_path == "" {
            del_path = raw_input
        }
        return agent_workspace_delete(del_path).observation
    }
    if action == "apply_patch" || action == "patch" {
        if parsed.path == "" || parsed.old_text == "" || parsed.new_text == "" {
            return agent_runtime_observation("apply_pending_changes", "failed", "action=apply_patch;reason=args_missing")
        }
        return agent_workspace_apply_patch(parsed.path, parsed.old_text, parsed.new_text, parsed.replace_all).observation
    }
    if action == "mkdir" || action == "create_directory" {
        string mkdir_path = parsed.path
        if mkdir_path == "" {
            mkdir_path = raw_input
        }
        if mkdir_path == "" {
            return agent_runtime_observation("apply_pending_changes", "failed", "action=mkdir;reason=path_missing")
        }
        return agent_workspace_mkdir(mkdir_path).observation
    }
    if action == "code" {
        string code_path = parsed.path
        string code_content = parsed.content
        if code_path == "" || code_content == "" {
            return agent_runtime_observation("apply_pending_changes", "failed", "action=code;reason=args_missing")
        }
        return agent_workspace_write(code_path, code_content).observation
    }
    agent_runtime_observation("apply_pending_changes", "failed", "action=" + action + ";reason=unsupported")
}

func agent_runtime_clear_pending_changes(agent_memory_state memory_state) agent_memory_state {
    int count = agent_runtime_pending_count(memory_state)
    agent_memory_state next = memory_state
    int i = 0
    while i < count {
        string idx = string(i)
        next = agent_memory_delete(next, "pending_change_action_" + idx)
        next = agent_memory_delete(next, "pending_change_input_" + idx)
        next = agent_memory_delete(next, "pending_change_path_" + idx)
        next = agent_memory_delete(next, "pending_change_preview_" + idx)
        i = i + 1
    }
    agent_memory_write_short(next, "pending_change_count", "0")
}

func agent_runtime_apply_pending_changes(agent_memory_state memory_state) agent_workspace_result {
    int count = agent_runtime_pending_count(memory_state)
    if count <= 0 {
        return agent_workspace_result {
            ok: false,
            observation: agent_runtime_observation("apply_pending_changes", "no_progress", "pending_change_count=0"),
            resolved_path: "",
        }
    }
    string out = agent_runtime_observation("apply_pending_changes", "ok", "pending_change_count=" + string(count))
    bool all_ok = true
    int changed_count = 0
    int i = 0
    while i < count {
        string idx = string(i)
        agent_memory_lookup_result action_result = agent_memory_lookup_long(memory_state, "pending_change_action_" + idx)
        agent_memory_lookup_result input_result = agent_memory_lookup_long(action_result.state, "pending_change_input_" + idx)
        agent_memory_lookup_result path_result = agent_memory_lookup_long(input_result.state, "pending_change_path_" + idx)
        string applied = agent_runtime_apply_staged_change(action_result.value, input_result.value)
        agent_observation_state parsed = agent_observation_parse(applied)
        if !parsed.ok && !parsed.terminal {
            all_ok = false
        } else {
            if trim(path_result.value) != "" {
                out = out + "\nchanged_path=" + path_result.value
            }
            changed_count = changed_count + 1
        }
        out = out + "\napplied[" + idx + "]=" + applied
        i = i + 1
    }
    out = out + "\nchanged_path_count=" + string(changed_count)
    agent_workspace_result {
        ok: all_ok,
        observation: out,
        resolved_path: "",
    }
}

func agent_runtime_with_interrupt(agent_runtime_state state, agent_interrupt_state interrupt_state) agent_runtime_state {
    agent_runtime_state {
        plan: state.plan,
        memory: state.memory,
        tools: state.tools,
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        reflection: state.reflection,
        context: state.context,
        reasoning: state.reasoning,
        subagents: state.subagents,
        answer: state.answer,
        interrupt: interrupt_state,
        session: state.session,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}

func agent_runtime_make_interrupt_pending(agent_runtime_state state, string input) agent_runtime_state {
    string action = state.plan.current_task
    string observation = agent_runtime_interrupt_observation("approval_required", action)
    agent_interrupt_state next_interrupt = agent_interrupt_request(state.interrupt, action, observation)
    agent_memory_state next_memory = agent_memory_write_short(state.memory, "interrupt_resume_input", input)
    next_memory = agent_memory_write_short(next_memory, "interrupt_resume_task", state.plan.current_task)
    agent_trace_state next_trace = agent_trace_append(
        state.trace,
        state.steps + 1,
        state.plan.current_task,
        input,
        "interrupt_request",
        observation,
        state.skill_execution.active_skill,
        "",
        0,
        0,
        false
    )
    agent_session_state next_session = agent_session_assistant(agent_session_user(state.session, input), observation)
    agent_context_state next_context = agent_context_append(
        agent_context_smart_compress(agent_context_append(state.context, input), state.model_path),
        observation
    )
    agent_runtime_state {
        plan: state.plan,
        memory: next_memory,
        tools: state.tools,
        trace: next_trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        reflection: state.reflection,
        context: next_context,
        reasoning: state.reasoning,
        subagents: state.subagents,
        answer: state.answer,
        interrupt: next_interrupt,
        session: next_session,
        steps: state.steps + 1,
        finished: false,
        last_action: "interrupt_request",
        last_observation: observation,
        model_path: state.model_path,
    }
}

func agent_runtime_handle_interrupt_response(agent_runtime_state state, string input) agent_runtime_state {
    agent_interrupt_state resolved = agent_interrupt_resolve(state.interrupt, input)
    if agent_interrupt_approved(resolved) {
        agent_memory_lookup_result resume_input_result = agent_memory_lookup_short(state.memory, "interrupt_resume_input")
        string resume_input = input
        agent_memory_state next_memory = state.memory
        if resume_input_result.found && trim(resume_input_result.value) != "" {
            resume_input = resume_input_result.value
            next_memory = resume_input_result.state
        }
        next_memory = agent_runtime_stage_pending_change(next_memory, resolved.kind, resume_input)
        string observation = agent_runtime_observation("pending_change", "ok", "action=" + resolved.kind + ";pending_change_count=" + string(agent_runtime_pending_count(next_memory)))
        agent_trace_state next_trace = agent_trace_append(
            state.trace,
            state.steps + 1,
            state.plan.current_task,
            input,
            "interrupt_approved",
            observation,
            state.skill_execution.active_skill,
            "",
            0,
            0,
            true
        )
        agent_plan_state next_plan = agent_plan_set_task(state.plan, "analyze")
        agent_session_state next_session = agent_session_assistant(agent_session_user(state.session, input), observation)
        agent_context_state next_context = agent_context_append(
            agent_context_smart_compress(agent_context_append(state.context, input), state.model_path),
            observation
        )
        return agent_runtime_state {
            plan: next_plan,
            memory: next_memory,
            tools: state.tools,
            trace: next_trace,
            skills: state.skills,
            skill_execution: state.skill_execution,
            reflection: state.reflection,
            context: next_context,
            reasoning: state.reasoning,
            subagents: state.subagents,
            answer: state.answer,
            interrupt: resolved,
            session: next_session,
            steps: state.steps + 1,
            finished: false,
            last_action: "interrupt_approved",
            last_observation: observation,
            model_path: state.model_path,
        }
    }
    string action = state.interrupt.kind
    string observation = agent_runtime_interrupt_observation("approval_denied", action)
    agent_trace_state next_trace = agent_trace_append(
        state.trace,
        state.steps + 1,
        state.plan.current_task,
        input,
        "interrupt_denied",
        observation,
        state.skill_execution.active_skill,
        "",
        0,
        0,
        false
    )
    agent_memory_state next_memory = agent_memory_write_short(state.memory, "replan_reason", observation)
    agent_plan_state next_plan = agent_plan_set_task(state.plan, "analyze")
    agent_session_state next_session = agent_session_assistant(agent_session_user(state.session, input), observation)
    agent_context_state next_context = agent_context_append(
        agent_context_smart_compress(agent_context_append(state.context, input), state.model_path),
        observation
    )
    agent_answer_state next_answer = state.answer
    if next_plan.finished {
        next_memory = agent_runtime_finalize_memory(next_memory, next_trace)
        next_answer = agent_answer_synthesize(state.answer, next_trace, next_memory, state.steps + 1)
    }
    agent_runtime_state {
        plan: next_plan,
        memory: next_memory,
        tools: state.tools,
        trace: next_trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        reflection: state.reflection,
        context: next_context,
        reasoning: state.reasoning,
        subagents: state.subagents,
        answer: next_answer,
        interrupt: resolved,
        session: next_session,
        steps: state.steps + 1,
        finished: next_plan.finished,
        last_action: "interrupt_denied",
        last_observation: observation,
        model_path: state.model_path,
    }
}

func s_char_is_digit(string s, int i) bool {
    string ch = string(s[i])
    ch == "0" || ch == "1" || ch == "2" || ch == "3" || ch == "4" || ch == "5" || ch == "6" || ch == "7" || ch == "8" || ch == "9"
}

func s_char_digit_val(string s, int i) int {
    string ch = string(s[i])
    if ch == "1" { return 1 }
    if ch == "2" { return 2 }
    if ch == "3" { return 3 }
    if ch == "4" { return 4 }
    if ch == "5" { return 5 }
    if ch == "6" { return 6 }
    if ch == "7" { return 7 }
    if ch == "8" { return 8 }
    if ch == "9" { return 9 }
    0
}

func resolve_agent_model_path(string model_path) string {
    string direct = trim_or_empty(model_path)
    if direct != "" {
        return direct
    }
    string env_path = trim_or_empty(runtime_env_get("NEURX_AGENT_MODEL_PATH", ""))
    if env_path != "" {
        return env_path
    }
    string endpoint_url = trim_or_empty(runtime_env_get("NEURX_CODE_AGENT_BASE_URL", runtime_env_get("NEURX_LLM_BASE_URL", runtime_env_get("NEURX_REMOTE_BASE_URL", ""))))
    string endpoint_model = trim_or_empty(runtime_env_get("NEURX_CODE_AGENT_MODEL", runtime_env_get("NEURX_LLM_MODEL", runtime_env_get("NEURX_REMOTE_MODEL", ""))))
    string endpoint_path = trim_or_empty(runtime_env_get("NEURX_CODE_AGENT_CHAT_PATH", runtime_env_get("NEURX_LLM_CHAT_PATH", runtime_env_get("NEURX_REMOTE_CHAT_PATH", "/v1/chat/completions"))))
    string endpoint_backend = trim_or_empty(runtime_env_get("NEURX_CODE_AGENT_BACKEND", runtime_env_get("NEURX_LLM_BACKEND", "remote")))
    if endpoint_url != "" && endpoint_model != "" && endpoint_backend != "" {
        return "backend=remote url=" + endpoint_url + " model=" + endpoint_model + " path=" + endpoint_path
    }
    string env_file = trim_or_empty(runtime_env_get("NEURX_AGENT_CHECKPOINT_FILE", ""))
    if env_file != "" {
        return env_file
    }
    string env_root = trim_or_empty(runtime_env_get("NEURX_AGENT_CHECKPOINT_ROOT", ""))
    if env_root != "" {
        return env_root
    }
    string backend_file = trim_or_empty(runtime_env_get("NEURX_BACKEND_CHECKPOINT_FILE", ""))
    if backend_file != "" {
        return backend_file
    }
    string backend_root = trim_or_empty(runtime_env_get("NEURX_BACKEND_CHECKPOINT_ROOT", ""))
    if backend_root != "" {
        return backend_root
    }
    ""
}

func new_agent_runtime_state(string goal, string initial_task, int step_budget) agent_runtime_state {
    new_agent_runtime_state_with_model(goal, initial_task, step_budget, "")
}

func agent_runtime_append_task([]string queue, string task) []string {
    if trim(task) == "" {
        return queue
    }
    queue.push(task)
    queue
}

func agent_runtime_code_agent_task_queue(agent_tool_registry_state tools) []string {
    []string queue = []string{cap: 12}
    if agent_tool_registry_has_enabled(tools, "git_status") {
        queue = agent_runtime_append_task(queue, "git_status")
    }
    if agent_tool_registry_has_enabled(tools, "repo") {
        queue = agent_runtime_append_task(queue, "repo")
    }
    if agent_tool_registry_has_enabled(tools, "retrieve") {
        queue = agent_runtime_append_task(queue, "retrieve")
    }
    if agent_tool_registry_has_enabled(tools, "code") {
        queue = agent_runtime_append_task(queue, "code")
        if agent_tool_registry_has_enabled(tools, "build") {
            queue = agent_runtime_append_task(queue, "build")
        }
        if agent_tool_registry_has_enabled(tools, "test") {
            queue = agent_runtime_append_task(queue, "test")
        }
        if agent_tool_registry_has_enabled(tools, "git_diff") {
            queue = agent_runtime_append_task(queue, "git_diff")
        }
        if agent_tool_registry_has_enabled(tools, "review") {
            queue = agent_runtime_append_task(queue, "review")
        }
    }
    queue = agent_runtime_append_task(queue, "verify")
    queue = agent_runtime_append_task(queue, "finalize")
    queue
}

func agent_runtime_plan_with_task_queue(agent_plan_state plan, []string tasks) agent_plan_state {
    agent_plan_state next = plan
    int i = 0
    while i < len(tasks) {
        next = agent_plan_enqueue_task(next, tasks[i])
        i = i + 1
    }
    next
}

func new_agent_runtime_state_with_model(string goal, string initial_task, int step_budget, string model_path) agent_runtime_state {
    string resolved_model_path = resolve_agent_model_path(model_path)
    agent_tool_registry_state tools = new_agent_tool_registry_state()
    tools = agent_tool_registry_add(tools, "search", true, 5000, 1)
    tools = agent_tool_registry_add(tools, "retrieve", true, 5000, 1)
    tools = agent_tool_registry_add(tools, "write", true, 10000, 1)
    tools = agent_tool_registry_add(tools, "mkdir", true, 5000, 1)
    tools = agent_tool_registry_add(tools, "delete", true, 10000, 1)
    tools = agent_tool_registry_add(tools, "apply_patch", true, 10000, 1)
    tools = agent_tool_registry_add(tools, "build", true, 20000, 0)
    tools = agent_tool_registry_add(tools, "test", true, 20000, 0)
    if resolved_model_path != "" {
        tools = agent_tool_registry_add(tools, "infer", true, 32000, 1)
        tools = agent_tool_registry_add(tools, "code", true, 60000, 1)
        tools = agent_tool_registry_add(tools, "review", true, 32000, 1)
    }
    tools = agent_tool_registry_add(tools, "repo", true, 5000, 1)
    tools = agent_tool_registry_add(tools, "s", true, 30000, 0)
    tools = agent_tool_registry_add(tools, "git_status", true, 5000, 1)
    tools = agent_tool_registry_add(tools, "git_diff", true, 5000, 1)
    tools = agent_tool_registry_add(tools, "git_log", true, 5000, 1)
    tools = agent_tool_registry_add(tools, "git_commit", true, 10000, 1)
    tools = agent_tool_registry_add(tools, "grep", true, 10000, 1)
    tools = agent_tool_registry_add(tools, "find_symbol", true, 10000, 1)
    tools = agent_tool_registry_add(tools, "list_dir", true, 5000, 1)
    string session_id = "session_" + string(0)
    agent_runtime_state {
        plan: new_agent_plan_state(goal, initial_task, step_budget),
        memory: new_agent_memory_state(),
        tools: tools,
        trace: new_agent_trace_state(),
        skills: new_agent_skill_registry_state(),
        skill_execution: new_agent_skill_execution_state(),
        reflection: new_agent_reflection_state(),
        context: new_agent_context_state(agent_context_default_max_tokens()),
        reasoning: new_agent_reasoning_state(),
        subagents: new_agent_subagent_registry_state(),
        answer: new_agent_answer_state(goal),
        interrupt: new_agent_interrupt_state(),
        session: new_agent_session_state(session_id, goal),
        steps: 0,
        finished: false,
        last_action: "",
        last_observation: "",
        model_path: resolved_model_path,
    }
}

func new_code_agent_runtime_state(string goal, int step_budget) agent_runtime_state {
    new_code_agent_runtime_state_with_model(goal, step_budget, "", "", "")
}

func new_code_agent_runtime_state_with_model(string goal, int step_budget, string model_path, string build_command, string test_command) agent_runtime_state {
    agent_runtime_state base = new_agent_runtime_state_with_model(goal, "analyze", step_budget, model_path)
    agent_memory_state memory_state = agent_memory_write_short(base.memory, "route", "code")
    memory_state = agent_memory_write_short(memory_state, "code_agent_profile", "neurx_style")
    memory_state = agent_memory_write_long(memory_state, "code_agent_goal", goal)
    if trim(build_command) != "" {
        memory_state = agent_memory_write_long(memory_state, "preferred_build_command", trim(build_command))
    }
    if trim(test_command) != "" {
        memory_state = agent_memory_write_long(memory_state, "preferred_test_command", trim(test_command))
    }
    agent_plan_state plan_state = agent_runtime_plan_with_task_queue(base.plan, agent_runtime_code_agent_task_queue(base.tools))
    agent_runtime_with_memory(agent_runtime_with_plan(base, plan_state), memory_state)
}

func agent_runtime_should_synthesize_skill(agent_skill_feedback_state feedback) bool {
    if !feedback.success {
        return false
    }
        feedback.task == "verify" || feedback.task == "infer" || feedback.task == "finalize" || feedback.task == "s"
}

func agent_runtime_retire_failure_threshold() int {
    2
}

func agent_runtime_failed_skill_name(agent_runtime_state state, agent_skill_feedback_state feedback) string {
    string active = trim_or_empty(state.skill_execution.active_skill)
    if active != "" && active != "none" {
        return active
    }
    agent_skill_name_from_feedback(feedback)
}

func agent_runtime_update_skills(agent_runtime_state state, agent_trace_state trace_state, agent_memory_state memory_state) agent_skill_registry_state {
    agent_skill_feedback_state feedback = agent_skill_feedback_from_trace(trace_state, memory_state)
    if feedback.task == "" {
        return state.skills
    }
    string skill_name = agent_skill_name_from_feedback(feedback)
    agent_skill_registry_state next = state.skills
    if agent_runtime_should_synthesize_skill(feedback) {
        agent_skill_record record = agent_skill_synthesize(feedback)
        next = agent_skill_registry_upsert(next, record)
        next = agent_skill_registry_record_success(next, skill_name, feedback.step, state.skill_execution.step_count)
        agent_skill_eval_result eval = agent_skill_evaluate(agent_skill_registry_get(next, skill_name), 60.0, -20.0)
        next = agent_skill_registry_set_score(next, skill_name, eval.score)
        if eval.should_promote {
            next = agent_skill_registry_promote(next, skill_name)
            next = agent_skill_registry_activate_best(next)
        } else if eval.should_retire {
            next = agent_skill_registry_retire(next, skill_name)
        }
        return next
    }
    if !feedback.success {
        string failed_skill = agent_runtime_failed_skill_name(state, feedback)
        if agent_skill_registry_has(next, failed_skill) {
            agent_skill_record failed_record = agent_skill_registry_get(next, failed_skill)
            bool signal_matched = agent_skill_registry_observation_matches_failure(failed_record, feedback.signal)
            if signal_matched {
                agent_skill_registry_state after_failure = agent_skill_registry_record_failure(next, failed_skill, feedback.step, agent_runtime_retire_failure_threshold())
                return agent_skill_registry_activate_best(after_failure)
            }
        }
    }
    next
}

func agent_runtime_skill_snapshot(agent_runtime_state state) string {
    string out = "steps=" + string(state.steps)
    out = out + "\nfinished=" + state.plan.status
    out = out + "\nlast_action=" + state.last_action
    out = out + "\nlast_observation=" + state.last_observation
    out = out + "\nactive_skill=" + state.skill_execution.active_skill
    out = out + "\nskill_execution_status=" + state.skill_execution.status
    out = out + "\n" + agent_reflection_summary(state.reflection)
    out = out + "\n" + agent_context_summary(state.context)
    out = out + "\n" + agent_answer_summary(state.answer)
    out = out + "\n" + agent_interrupt_summary(state.interrupt)
    out = out + "\n" + agent_subagent_summary(state.subagents)
    out = out + "\n" + agent_session_summary(state.session)
    out = out + "\n" + agent_skill_registry_snapshot(state.skills)
    out
}

func agent_runtime_trajectory_export(agent_runtime_state state) string {
    string out = "goal=" + state.plan.goal
    out = out + "\ncurrent_task=" + state.plan.current_task
    out = out + "\nstatus=" + state.plan.status
    out = out + "\nsteps=" + string(state.steps)
    out = out + "\nmodel_path=" + state.model_path
    out = out + "\n" + agent_trace_export(state.trace)
    out = out + "\n" + agent_runtime_skill_snapshot(state)
    out
}

func agent_runtime_persist_skill_snapshot(agent_runtime_state state, string path) string {
    runtime_write_text_file(path, agent_runtime_skill_snapshot(state))
    path
}

func agent_runtime_export_trajectory(agent_runtime_state state, string path) string {
    runtime_write_text_file(path, agent_runtime_trajectory_export(state))
    path
}

func agent_runtime_make_blocked(agent_runtime_state state, string reason) agent_runtime_state {
    string blocked_observation = agent_runtime_observation("safety", "blocked", "reason=" + reason)
    agent_trace_state next_trace = agent_trace_append(
        state.trace,
        state.steps + 1,
        state.plan.current_task,
        "",
        "blocked",
        blocked_observation,
        state.skill_execution.active_skill,
        "",
        0,
        0,
        false
    )
    agent_memory_state next_memory = state.memory
    agent_answer_state next_answer = state.answer
    next_answer = agent_answer_synthesize(next_answer, next_trace, next_memory, state.steps + 1)
    agent_runtime_state {
        plan: state.plan,
        memory: next_memory,
        tools: state.tools,
        trace: next_trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        reflection: state.reflection,
        context: state.context,
        reasoning: state.reasoning,
        subagents: state.subagents,
        answer: next_answer,
        interrupt: state.interrupt,
        session: state.session,
        steps: state.steps + 1,
        finished: true,
        last_action: "blocked",
        last_observation: blocked_observation,
        model_path: state.model_path,
    }
}

func agent_runtime_step(agent_runtime_state state, string input) agent_runtime_state {
    if state.finished {
        return state
    }
    if state.interrupt.pending {
        return agent_runtime_handle_interrupt_response(state, input)
    }
    agent_safety_result safety = agent_safety_check(state.plan.current_task, input, state.plan.goal)
    if !safety.allowed {
        return agent_runtime_make_blocked(state, safety.reason)
    }
    if state.plan.current_task == "show_pending_changes" {
        string observation = agent_runtime_pending_summary(state.memory)
        agent_trace_state next_trace = agent_trace_append(state.trace, state.steps + 1, state.plan.current_task, input, "show_pending_changes", observation, state.skill_execution.active_skill, "", 0, 0, agent_observation_is_progress(observation))
        return agent_runtime_state {
            plan: agent_plan_set_task(state.plan, "analyze"),
            memory: state.memory,
            tools: state.tools,
            trace: next_trace,
            skills: state.skills,
            skill_execution: state.skill_execution,
            reflection: state.reflection,
            context: agent_context_append(agent_context_smart_compress(agent_context_append(state.context, input), state.model_path), observation),
            reasoning: state.reasoning,
            subagents: state.subagents,
            answer: state.answer,
            interrupt: state.interrupt,
            session: agent_session_assistant(agent_session_user(state.session, input), observation),
            steps: state.steps + 1,
            finished: false,
            last_action: "show_pending_changes",
            last_observation: observation,
            model_path: state.model_path,
        }
    }
    if state.plan.current_task == "apply_pending_changes" {
        agent_workspace_result apply_result = agent_runtime_apply_pending_changes(state.memory)
        agent_memory_state next_memory = state.memory
        if apply_result.ok {
            next_memory = agent_runtime_clear_pending_changes(next_memory)
        }
        agent_trace_state next_trace = agent_trace_append(state.trace, state.steps + 1, state.plan.current_task, input, "apply_pending_changes", apply_result.observation, state.skill_execution.active_skill, "", 0, 0, apply_result.ok)
        return agent_runtime_state {
            plan: agent_plan_set_task(state.plan, "analyze"),
            memory: next_memory,
            tools: state.tools,
            trace: next_trace,
            skills: state.skills,
            skill_execution: state.skill_execution,
            reflection: state.reflection,
            context: agent_context_append(agent_context_smart_compress(agent_context_append(state.context, input), state.model_path), apply_result.observation),
            reasoning: state.reasoning,
            subagents: state.subagents,
            answer: state.answer,
            interrupt: state.interrupt,
            session: agent_session_assistant(agent_session_user(state.session, input), apply_result.observation),
            steps: state.steps + 1,
            finished: false,
            last_action: "apply_pending_changes",
            last_observation: apply_result.observation,
            model_path: state.model_path,
        }
    }
    agent_memory_state approval_memory = state.memory
    bool approval_granted = false
    string auto_approve_env = trim(runtime_env_get("NEURX_AUTO_APPROVE_TOOLS", ""))
    if auto_approve_env == "1" || auto_approve_env == "true" || auto_approve_env == "yes" {
        approval_granted = true
    }
    if !approval_granted {
        agent_memory_lookup_result approval_result = agent_memory_lookup_short(approval_memory, "interrupt_approval_granted_for")
        if approval_result.found && agent_runtime_approval_matches(approval_result.value, state.plan.current_task) {
            approval_granted = true
            approval_memory = approval_result.state
        }
    }
    if agent_runtime_requires_approval(state.plan.current_task) && !approval_granted {
        return agent_runtime_make_interrupt_pending(state, input)
    }
    agent_session_state next_session = agent_session_user(state.session, input)
    agent_context_state next_context = agent_context_smart_compress(
        agent_context_append(state.context, input),
        state.model_path
    )
    agent_reasoning_state next_reasoning = agent_reasoning_for_goal(
        state.reasoning, state.plan.goal, state.last_observation
    )
    approval_memory = call_trace_append(approval_memory, state.steps + 1, "safety.check", CALL_TRACE_SAFETY, "agent_safety_check", true)
    approval_memory = call_trace_append(approval_memory, state.steps + 1, "reasoning", CALL_TRACE_REASONING, "agent_reasoning_for_goal", true)
    approval_memory = call_trace_append(approval_memory, state.steps + 1, "context.compress", CALL_TRACE_CONTEXT, "agent_context_smart_compress", true)
    agent_execute_result result = agent_execute_step(state.tools, approval_memory, state.plan.goal, state.plan.current_task, input, state.model_path)
    agent_memory_state execution_memory = result.memory
    execution_memory = call_trace_append(execution_memory, state.steps + 1, "executor.step", CALL_TRACE_EXECUTOR, "agent_execute_step", result.ok)
    execution_memory = call_trace_append(execution_memory, state.steps + 1, "tool.dispatch", CALL_TRACE_TOOLS, result.tool_name, result.ok)
    execution_memory = call_trace_append(execution_memory, state.steps + 1, "infer.model", CALL_TRACE_INFER, "agent_model_infer", result.ok)
    execution_memory = call_trace_append(execution_memory, state.steps + 1, "model.select", CALL_TRACE_MODEL_SEL, "agent_model_tool_call", result.ok)
    agent_subagent_registry_state current_subagents = state.subagents
    agent_memory_lookup_result spawn_goal = agent_memory_lookup_long(execution_memory, "subagent_goal")
    if spawn_goal.found && spawn_goal.value != "" {
        agent_memory_lookup_result spawn_input = agent_memory_lookup_long(execution_memory, "subagent_input")
        agent_memory_lookup_result spawn_steps_raw = agent_memory_lookup_short(execution_memory, "subagent_max_steps")
        int spawn_max_steps = 16
        if spawn_steps_raw.found && spawn_steps_raw.value != "" {
            string smsr = spawn_steps_raw.value
            int smsv = 0
            int si = 0
            while si < len(smsr) {
                if s_char_is_digit(smsr, si) {
                    smsv = smsv * 10 + s_char_digit_val(smsr, si)
                }
                si = si + 1
            }
            if smsv > 0 {
                spawn_max_steps = smsv
            }
        }
        string spawn_inp = ""
        if spawn_input.found {
            spawn_inp = spawn_input.value
            execution_memory = spawn_input.state
        }
        current_subagents = agent_subagent_spawn(current_subagents, spawn_goal.value, spawn_inp, spawn_max_steps)
        execution_memory = spawn_goal.state
    }
    agent_observation_state execution_observation = agent_observation_parse(result.observation)
    execution_memory = call_trace_append(execution_memory, state.steps + 1, "observation.parse", CALL_TRACE_OBSERVE, "agent_observation_parse", !execution_observation.failed)
    bool repair_task = state.plan.current_task == "build" || state.plan.current_task == "test"
    if repair_task {
        if execution_observation.failed {
            execution_memory = agent_runtime_record_repair_failure(execution_memory, state.plan.current_task, result.observation)
        } else if execution_observation.ok || execution_observation.terminal {
            execution_memory = agent_runtime_clear_repair_state(execution_memory)
        }
    }
    result.memory = execution_memory
    if repair_task && execution_observation.failed {
        int repair_attempts = agent_runtime_repair_attempt_count(execution_memory)
        int repair_limit = agent_runtime_max_repair_attempts()
        bool has_code = agent_tool_registry_has_enabled(state.tools, "code")
        string stop_reason = ""
        if !has_code {
            stop_reason = "repair_tool_unavailable"
        } else if repair_attempts >= repair_limit {
            stop_reason = "repair_limit_reached"
        }
        if stop_reason != "" {
            string preferred_failure = agent_runtime_preferred_failure_summary(execution_memory, state.plan.current_task, result.observation)
            string failure_summary = agent_runtime_repair_failure_summary(
                state.plan.current_task, preferred_failure, repair_attempts, repair_limit, stop_reason
            )
            agent_plan_state stop_plan = agent_plan_state {
                goal: state.plan.goal,
                current_task: "complete",
                step_budget: state.plan.step_budget,
                step_count: state.plan.step_count + 1,
                needs_replan: false,
                finished: true,
                status: "repair_failed",
                replan_reason: failure_summary,
                task_queue: [],
                replan_count: state.plan.replan_count,
                code_attempts: state.plan.code_attempts,
            }
            return agent_runtime_finish_after_repair_failure(state, stop_plan, execution_memory, result, input, failure_summary)
        }
    }
    agent_reflection_state next_reflection = agent_reflect(
        state.reflection, state.plan.goal, result.action, result.observation, state.steps + 1
    )
    agent_perception_result perception = agent_perceive(result.observation, "tool")
    agent_plan_state next_plan = agent_plan_next(state.plan, result.tools, result.memory, result.observation)
    if next_reflection.needs_correction && !next_plan.needs_replan {
        next_plan = agent_plan_set_task(next_plan, "analyze")
    }
    agent_memory_state final_memory = result.memory
    final_memory = call_trace_append(final_memory, state.steps + 1, "reflection", CALL_TRACE_REFLECT, "agent_reflect", !next_reflection.needs_correction)
    final_memory = call_trace_append(final_memory, state.steps + 1, "perception", CALL_TRACE_PERCEIVE, "agent_perceive", true)
    final_memory = call_trace_append(final_memory, state.steps + 1, "planner.next", CALL_TRACE_PLANNER, "agent_plan_next", !next_plan.needs_replan)
    if next_plan.needs_replan && next_plan.replan_reason != "" {
        final_memory = agent_memory_write_short(final_memory, "replan_reason", next_plan.replan_reason)
        if next_plan.replan_reason == "tool_unavailable" && result.tool_name != "" {
            next_plan = agent_plan_set_task(next_plan, "analyze")
        }
    }
    if state.plan.current_task == "plan" && result.ok {
        agent_memory_lookup_result pq_result = agent_memory_lookup_long(final_memory, "plan_queue")
        if pq_result.found && pq_result.value != "" {
            final_memory = pq_result.state
            string pq = pq_result.value
            int pq_start = 0
            int pi = 0
            while pi < len(pq) {
                if string(pq[pi]) == "[" {
                    pq_start = pi + 1
                    break
                }
                pi = pi + 1
            }
            int pq_end = len(pq)
            pi = pq_end - 1
            while pi >= 0 {
                if string(pq[pi]) == "]" {
                    pq_end = pi
                    break
                }
                pi = pi - 1
            }
            string token = ""
            pi = pq_start
            while pi <= pq_end {
                bool at_sep = pi == pq_end || string(pq[pi]) == ","
                if at_sep {
                    string t = trim(token)
                    if len(t) > 0 {
                        next_plan = agent_plan_enqueue_task(next_plan, t)
                    }
                    token = ""
                } else {
                    token = token + string(pq[pi])
                }
                pi = pi + 1
            }
            if len(next_plan.task_queue) > 0 {
                next_plan = agent_plan_dequeue_to_current(next_plan)
            }
        }
    }
    agent_trace_state next_trace = agent_trace_append(
        state.trace,
        state.steps + 1,
        state.plan.current_task,
        input,
        result.action,
        result.observation,
        state.skill_execution.active_skill,
        result.tool_name,
        result.tool_timeout_ms,
        result.tool_retries,
        result.ok
    )
    agent_tool_registry_state final_tools = result.tools
    if next_plan.needs_replan && agent_observation_requires_replan(next_plan.replan_reason) && result.tool_name != "" {
        final_tools = agent_tool_registry_disable(final_tools, result.tool_name)
    }
    agent_skill_registry_state next_skills = agent_runtime_update_skills(state, next_trace, result.memory)
    agent_skill_execution_state next_skill_execution = agent_skill_execute(next_skills, next_plan.current_task)
    final_memory = call_trace_append(final_memory, state.steps + 1, "trace.append", CALL_TRACE_TRACE, "agent_trace_append", true)
    final_memory = call_trace_append(final_memory, state.steps + 1, "skills.update", CALL_TRACE_SKILLS, "agent_runtime_update_skills", true)
    final_memory = call_trace_append(final_memory, state.steps + 1, "skill.execute", CALL_TRACE_SKILL_EX, "agent_skill_execute", true)
    final_memory = call_trace_append(final_memory, state.steps + 1, "session.update", CALL_TRACE_SESSION, "agent_session_assistant", true)
    final_memory = call_trace_append(final_memory, state.steps + 1, "context.build", CALL_TRACE_CTX_BUILD, "agent_context_build_from_memory", true)
    final_memory = call_trace_append(final_memory, state.steps + 1, "memory.persist", CALL_TRACE_MEMORY, "agent_memory_write_long", true)
    agent_answer_state next_answer = state.answer
    if next_plan.finished {
        final_memory = agent_runtime_finalize_memory(final_memory, next_trace)
        next_answer = agent_answer_synthesize(state.answer, next_trace, final_memory, state.steps + 1)
        agent_runtime_persist_skill_snapshot(
            agent_runtime_state {
                plan: next_plan,
                memory: final_memory,
                tools: final_tools,
                trace: next_trace,
                skills: next_skills,
                skill_execution: next_skill_execution,
                reflection: next_reflection,
                context: next_context,
                reasoning: next_reasoning,
                subagents: current_subagents,
                answer: next_answer,
                interrupt: state.interrupt,
                session: next_session,
                steps: state.steps + 1,
                finished: true,
                last_action: result.action,
                last_observation: result.observation,
                model_path: state.model_path,
            },
            ".neurx_skills.snapshot"
        )
    }
    next_session = agent_session_assistant(next_session, result.observation)
    next_context = agent_context_append(next_context, result.observation)
    next_context = agent_context_build_from_memory(next_context, final_memory)
    agent_runtime_state {
        plan: next_plan,
        memory: final_memory,
        tools: final_tools,
        trace: next_trace,
        skills: next_skills,
        skill_execution: next_skill_execution,
        reflection: next_reflection,
        context: next_context,
        reasoning: next_reasoning,
        subagents: current_subagents,
        answer: next_answer,
        interrupt: state.interrupt,
        session: next_session,
        steps: state.steps + 1,
        finished: next_plan.finished,
        last_action: result.action,
        last_observation: result.observation,
        model_path: state.model_path,
    }
}

func agent_runtime_run_pending_subagents(agent_runtime_state state) agent_runtime_state {
    agent_subagent_registry_state registry = state.subagents
    int n = registry.count
    if n == 0 {
        return state
    }
    agent_memory_state merged_memory = state.memory
    int i = 0
    while i < n {
        agent_subagent_task t = registry.tasks[i]
        if t.status == "pending" {
            agent_runtime_state sub_state = new_agent_runtime_state_with_model(t.goal, "analyze", t.max_steps, state.model_path)
            agent_runtime_state sub_done = run_agent_steps(sub_state, t.input, t.max_steps)
            agent_memory_lookup_result ans = agent_memory_lookup_long(sub_done.memory, "final_answer")
            string sub_result = ""
            bool sub_ok = sub_done.finished
            if ans.found && ans.value != "" {
                sub_result = ans.value
            } else {
                sub_result = sub_done.last_observation
            }
            registry = agent_subagent_complete(registry, t.id, sub_result, sub_ok)
            if sub_result != "" {
                merged_memory = agent_memory_write_long(merged_memory, "subagent_result_" + t.id, sub_result)
            }
        }
        i = i + 1
    }
    agent_runtime_state {
        plan: state.plan,
        memory: merged_memory,
        tools: state.tools,
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        reflection: state.reflection,
        context: state.context,
        reasoning: state.reasoning,
        subagents: registry,
        answer: state.answer,
        interrupt: state.interrupt,
        session: state.session,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}

func run_agent_steps(agent_runtime_state state, string input, int max_steps) agent_runtime_state {
    int total = max_steps
    if total < 0 {
        total = 0
    }
    agent_runtime_state current = state
    int i = 0
    while i < total {
        current = agent_runtime_step(current, input)
        if !agent_subagent_all_done(current.subagents) {
            current = agent_runtime_run_pending_subagents(current)
        }
        if current.finished {
            call_trace_maybe_write(current.memory)
            return current
        }
        if agent_runtime_is_stalled(current) {
            call_trace_maybe_write(current.memory)
            return current
        }
        i = i + 1
    }
    call_trace_maybe_write(current.memory)
    current
}

func run_agent_steps_batch(agent_runtime_state state, []string inputs, int max_steps_per_input) agent_runtime_state {
    agent_runtime_state current = state
    int ni = 0
    while ni < len(inputs) {
        current = run_agent_steps(current, inputs[ni], max_steps_per_input)
        if current.finished {
            return current
        }
        ni = ni + 1
    }
    current
}

func agent_runtime_replay_line_value(string line) string {
    int eq = 0
    int li = 0
    while li < len(line) {
        if string(line[li]) == "=" {
            eq = li + 1
            break
        }
        li = li + 1
    }
    if eq <= 0 {
        return ""
    }
    int val_len = len(line) - eq
    string val = ""
    int vi = 0
    while vi < val_len {
        val = val + string(line[eq + vi])
        vi = vi + 1
    }
    val
}

func agent_runtime_replay_trajectory(agent_runtime_state state, string path) agent_skill_registry_state {
    if !runtime_file_exists(path) {
        return state.skills
    }
    string content = runtime_read_text_file(path)
    int content_len = len(content)
    agent_skill_registry_state next = state.skills
    string cur_task = ""
    string cur_action = ""
    string cur_obs = ""
    bool cur_ok = false
    string cur_skill = ""
    int cur_step = 0
    string cur_line = ""
    int ci = 0
    while ci <= content_len {
        bool at_end = ci == content_len
        bool at_newline = !at_end && string(content[ci]) == "\n"
        if at_newline || at_end {
            string ln = cur_line
            cur_line = ""
            if len(ln) > 0 {
                string val = agent_runtime_replay_line_value(ln)
                if agent_text_contains(ln, "task[") {
                    cur_task = val
                } else if agent_text_contains(ln, "action[") {
                    cur_action = val
                } else if agent_text_contains(ln, "observation[") {
                    cur_obs = val
                    agent_observation_state parsed_obs = agent_observation_parse(cur_obs)
                    cur_ok = parsed_obs.ok || parsed_obs.terminal
                } else if agent_text_contains(ln, "active_skill[") {
                    cur_skill = val
                } else if agent_text_contains(ln, "step[") {
                    int step_val = 0
                    int si = 0
                    while si < len(val) {
                        if s_char_is_digit(val, si) {
                            step_val = step_val * 10 + s_char_digit_val(val, si)
                        }
                        si = si + 1
                    }
                    cur_step = step_val
                } else if agent_text_contains(ln, "ok[") {
                    if cur_obs == "" {
                        cur_ok = val == "true"
                    }
                    if cur_task != "" && cur_obs != "" {
                        agent_skill_feedback_state fb = agent_skill_feedback_state {
                            skill_name: cur_skill,
                            task: cur_task,
                            signal: cur_action,
                            summary: cur_obs,
                            step: cur_step,
                            success: cur_ok,
                        }
                        bool should_syn = cur_ok && (cur_task == "verify" || cur_task == "infer" || cur_task == "finalize")
                        if should_syn {
                            string sname = agent_skill_name_from_feedback(fb)
                            agent_skill_record rec = agent_skill_synthesize(fb)
                            next = agent_skill_registry_upsert(next, rec)
                            next = agent_skill_registry_record_success(next, sname, cur_step, 1)
                            agent_skill_eval_result ev = agent_skill_evaluate(agent_skill_registry_get(next, sname), 60.0, -20.0)
                            if ev.should_promote {
                                next = agent_skill_registry_promote(next, sname)
                            }
                        }
                        cur_task = ""
                        cur_action = ""
                        cur_obs = ""
                        cur_skill = ""
                        cur_ok = false
                    }
                }
            }
        } else {
            cur_line = cur_line + string(content[ci])
        }
        ci = ci + 1
    }
    agent_skill_registry_activate_best(next)
}

func agent_runtime_import_skill_snapshot(agent_runtime_state state, string path) agent_skill_registry_state {
    if !runtime_file_exists(path) {
        return state.skills
    }
    string content = runtime_read_text_file(path)
    int content_len = len(content)
    agent_skill_registry_state next = state.skills
    string cur_name = ""
    string cur_version = ""
    string cur_intent = ""
    string cur_status = ""
    float cur_success_rate = 0.0
    float cur_stability = 0.0
    float cur_avg_steps = 0.0
    int cur_step = 0
    string cur_line = ""
    int ci = 0
    while ci <= content_len {
        bool at_end = ci == content_len
        bool at_newline = !at_end && string(content[ci]) == "\n"
        if at_newline || at_end {
            string ln = cur_line
            cur_line = ""
            if len(ln) > 0 {
                string val = agent_runtime_replay_line_value(ln)
                if agent_text_contains(ln, ".name=") {
                    cur_name = val
                } else if agent_text_contains(ln, ".version=") {
                    cur_version = val
                } else if agent_text_contains(ln, ".intent=") {
                    cur_intent = val
                } else if agent_text_contains(ln, ".status=") {
                    cur_status = val
                } else if agent_text_contains(ln, ".created_step=") {
                    int sv = 0
                    int si = 0
                    while si < len(val) {
                        if s_char_is_digit(val, si) {
                            sv = sv * 10 + s_char_digit_val(val, si)
                        }
                        si = si + 1
                    }
                    cur_step = sv
                } else if agent_text_contains(ln, ".success_rate=") {
                    float fv = 0.0
                    int si = 0
                    int int_part = 0
                    bool past_dot = false
                    float frac = 0.1
                    while si < len(val) {
                        if s_char_is_digit(val, si) {
                            if past_dot {
                                fv = fv + float(s_char_digit_val(val, si)) * frac
                                frac = frac * 0.1
                            } else {
                                int_part = int_part * 10 + s_char_digit_val(val, si)
                            }
                        } else if string(val[si]) == "." {
                            past_dot = true
                            fv = float(int_part)
                        }
                        si = si + 1
                    }
                    if !past_dot {
                        fv = float(int_part)
                    }
                    cur_success_rate = fv
                } else if agent_text_contains(ln, ".stability=") {
                    float fv = 0.0
                    int si = 0
                    int int_part = 0
                    bool past_dot = false
                    float frac = 0.1
                    while si < len(val) {
                        if s_char_is_digit(val, si) {
                            if past_dot {
                                fv = fv + float(s_char_digit_val(val, si)) * frac
                                frac = frac * 0.1
                            } else {
                                int_part = int_part * 10 + s_char_digit_val(val, si)
                            }
                        } else if string(val[si]) == "." {
                            past_dot = true
                            fv = float(int_part)
                        }
                        si = si + 1
                    }
                    if !past_dot {
                        fv = float(int_part)
                    }
                    cur_stability = fv
                } else if agent_text_contains(ln, ".avg_steps=") {
                    float fv = 0.0
                    int si = 0
                    int int_part = 0
                    bool past_dot = false
                    float frac = 0.1
                    while si < len(val) {
                        if s_char_is_digit(val, si) {
                            if past_dot {
                                fv = fv + float(s_char_digit_val(val, si)) * frac
                                frac = frac * 0.1
                            } else {
                                int_part = int_part * 10 + s_char_digit_val(val, si)
                            }
                        } else if string(val[si]) == "." {
                            past_dot = true
                            fv = float(int_part)
                        }
                        si = si + 1
                    }
                    if !past_dot {
                        fv = float(int_part)
                    }
                    cur_avg_steps = fv
                    if cur_name != "" && cur_status != "" {
                        agent_skill_spec spec = new_agent_skill_spec(cur_name, cur_version, cur_intent, cur_status)
                        agent_skill_metrics metrics = new_agent_skill_metrics()
                        metrics.success_rate = cur_success_rate
                        metrics.stability = cur_stability
                        metrics.avg_steps = cur_avg_steps
                        agent_skill_record record = new_agent_skill_record(spec, metrics, cur_step)
                        next = agent_skill_registry_upsert(next, record)
                        if cur_status == "promoted" || cur_status == "validated" {
                            next = agent_skill_registry_promote(next, cur_name)
                        }
                        cur_name = ""
                        cur_version = ""
                        cur_intent = ""
                        cur_status = ""
                        cur_success_rate = 0.0
                        cur_stability = 0.0
                        cur_avg_steps = 0.0
                        cur_step = 0
                    }
                }
            }
        } else {
            cur_line = cur_line + string(content[ci])
        }
        ci = ci + 1
    }
    agent_skill_registry_activate_best(next)
}

func agent_runtime_state_dict(agent_runtime_state state) agent_runtime_state {
    state
}

func agent_runtime_load_state_dict(agent_runtime_state state, agent_runtime_state other) agent_runtime_state {
    other
}

func agent_runtime_set_route(agent_runtime_state state, string route) agent_runtime_state {
    agent_memory_state next_memory = agent_memory_write_short(state.memory, "route", route)
    agent_plan_state next_plan = agent_plan_set_task(state.plan, "plan")
    agent_runtime_state {
        plan: next_plan,
        memory: next_memory,
        tools: state.tools,
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        steps: state.steps,
        finished: false,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}

func agent_runtime_extend_budget(agent_runtime_state state, int extra) agent_runtime_state {
    int add = extra
    if add < 0 {
        add = 0
    }
    agent_plan_state next_plan = agent_plan_state {
        goal: state.plan.goal,
        current_task: state.plan.current_task,
        step_budget: state.plan.step_budget + add,
        step_count: state.plan.step_count,
        needs_replan: state.plan.needs_replan,
        finished: false,
        status: "running",
        replan_reason: state.plan.replan_reason,
        task_queue: state.plan.task_queue,
        replan_count: state.plan.replan_count,
    }
    if state.plan.status != "budget_exhausted" {
        next_plan = agent_plan_state {
            goal: state.plan.goal,
            current_task: state.plan.current_task,
            step_budget: state.plan.step_budget + add,
            step_count: state.plan.step_count,
            needs_replan: state.plan.needs_replan,
            finished: false,
            status: state.plan.status,
            replan_reason: state.plan.replan_reason,
            task_queue: state.plan.task_queue,
            replan_count: state.plan.replan_count,
        }
    }
    agent_runtime_state {
        plan: next_plan,
        memory: state.memory,
        tools: state.tools,
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        reflection: state.reflection,
        context: state.context,
        reasoning: state.reasoning,
        subagents: state.subagents,
        answer: state.answer,
        interrupt: state.interrupt,
        session: state.session,
        steps: state.steps,
        finished: false,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}

func agent_runtime_with_plan(agent_runtime_state state, agent_plan_state plan) agent_runtime_state {
    agent_runtime_state {
        plan: plan,
        memory: state.memory,
        tools: state.tools,
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        reflection: state.reflection,
        context: state.context,
        reasoning: state.reasoning,
        subagents: state.subagents,
        answer: state.answer,
        interrupt: state.interrupt,
        session: state.session,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}

func agent_runtime_with_memory(agent_runtime_state state, agent_memory_state memory) agent_runtime_state {
    agent_runtime_state {
        plan: state.plan,
        memory: memory,
        tools: state.tools,
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        reflection: state.reflection,
        context: state.context,
        reasoning: state.reasoning,
        subagents: state.subagents,
        answer: state.answer,
        interrupt: state.interrupt,
        session: state.session,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}

func agent_runtime_with_skills(agent_runtime_state state, agent_skill_registry_state skills) agent_runtime_state {
    agent_runtime_state {
        plan: state.plan,
        memory: state.memory,
        tools: state.tools,
        trace: state.trace,
        skills: skills,
        skill_execution: state.skill_execution,
        reflection: state.reflection,
        context: state.context,
        reasoning: state.reasoning,
        subagents: state.subagents,
        answer: state.answer,
        interrupt: state.interrupt,
        session: state.session,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}

func agent_runtime_step_with_task(agent_runtime_state state, string task, string input) agent_runtime_state {
    agent_plan_state forced_plan = agent_plan_set_task(state.plan, task)
    agent_runtime_step(agent_runtime_with_plan(state, forced_plan), input)
}

func agent_runtime_warm_start(string goal, string memory_path, string skill_path, string model_path) agent_runtime_state {
    agent_runtime_state base = new_agent_runtime_state_with_model(goal, "analyze", 32, model_path)
    agent_memory_state loaded_memory = base.memory
    if memory_path != "" {
        if runtime_file_exists(memory_path) {
            loaded_memory = agent_memory_restore(memory_path)
        }
    }
    agent_runtime_state mid = agent_runtime_with_memory(base, loaded_memory)
    agent_skill_registry_state loaded_skills = mid.skills
    if skill_path != "" {
        if runtime_file_exists(skill_path) {
            loaded_skills = agent_runtime_import_skill_snapshot(mid, skill_path)
        }
    }
    agent_runtime_with_skills(mid, loaded_skills)
}

func agent_runtime_summary(agent_runtime_state state) string {
    string finished_str = "false"
    if state.finished {
        finished_str = "true"
    }
    string out = "goal=" + state.plan.goal
    out = out + "\nstatus=" + state.plan.status
    out = out + "\ntask=" + state.plan.current_task
    out = out + "\nsteps=" + string(state.plan.step_count) + "/" + string(state.plan.step_budget)
    out = out + "\nfinished=" + finished_str
    out = out + "\nskills=" + string(len(state.skills.records))
    out = out + "\ntools=" + string(len(state.tools.tool_names))
    out = out + "\nobs=" + state.last_observation
    out
}

func agent_runtime_is_stalled(agent_runtime_state state) bool {
    int size = len(state.trace.tasks)
    if size < 3 {
        return false
    }
    int start = size - 3
    string ref_task = state.trace.tasks[start]
    int i = start + 1
    while i < size {
        if state.trace.tasks[i] != ref_task {
            return false
        }
        i = i + 1
    }
    i = start
    while i < size {
        if state.trace.ok_flags[i] {
            return false
        }
        i = i + 1
    }
    true
}

func agent_runtime_checkpoint(agent_runtime_state state, string dir) string {
    string mem_path  = dir + "/memory.txt"
    string snap_path = dir + "/snapshot.txt"
    agent_memory_persist(state.memory, mem_path)
    agent_skill_registry_persist(state.skills, snap_path)
    dir
}

func agent_runtime_restore_checkpoint(string goal, string dir) agent_runtime_state {
    agent_runtime_warm_start(goal, dir + "/memory.txt", dir + "/snapshot.txt", "")
}

func agent_runtime_run_until_stalled(agent_runtime_state state, string input, int max_steps) agent_runtime_state {
    agent_runtime_state current = state
    int i = 0
    while i < max_steps {
        if current.finished {
            return current
        }
        if agent_runtime_is_stalled(current) {
            return current
        }
        current = agent_runtime_step(current, input)
        i = i + 1
    }
    current
}

func agent_runtime_merge_memory(agent_runtime_state state, agent_runtime_state other) agent_runtime_state {
    agent_memory_state merged = state.memory
    int si = 0
    while si < len(other.memory.short_keys) {
        merged = agent_memory_write_short(merged, other.memory.short_keys[si], other.memory.short_values[si])
        si = si + 1
    }
    int li = 0
    while li < len(other.memory.long_keys) {
        merged = agent_memory_write_long(merged, other.memory.long_keys[li], other.memory.long_values[li])
        li = li + 1
    }
    agent_runtime_state {
        plan: state.plan,
        memory: merged,
        tools: state.tools,
        trace: state.trace,
        skills: state.skills,
        skill_execution: state.skill_execution,
        steps: state.steps,
        finished: state.finished,
        last_action: state.last_action,
        last_observation: state.last_observation,
        model_path: state.model_path,
    }
}
