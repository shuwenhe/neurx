package neurx.agent.skill_synthesizer
use neurx.agent.skill_schema
use neurx.agent.skill_feedback
func agent_skill_version_from_step(int step) string {
    "v" + string(step)
}

func agent_skill_signal_action(string signal) string {
    string raw = trim(signal)
    if raw == "" {
        return ""
    }
    string out = ""
    int i = 0
    while i < len(raw) {
        string ch = string(raw[i])
        if ch == ":" || ch == ";" || ch == " " {
            break
        }
        out = out + ch
        i = i + 1
    }
    lower(trim(out))
}

func agent_skill_append_unique([]string items, string value) []string {
    string v = trim(value)
    if v == "" {
        return items
    }
    int size = len(items)
    int i = 0
    while i < size {
        if items[i] == v {
            return items
        }
        i = i + 1
    }
    []string out = []string{cap: size + 1}
    i = 0
    while i < size {
        out[i] = items[i]
        i = i + 1
    }
    out[size] = v
    out
}

func agent_skill_required_tools(agent_skill_feedback_state feedback, string action) []string {
    []string tools = []string{}
    tools = agent_skill_append_unique(tools, action)
    if feedback.skill_name != "" && feedback.skill_name != "general" && feedback.skill_name != action {
        tools = agent_skill_append_unique(tools, feedback.skill_name)
    }
    if feedback.task == "code" {
        tools = agent_skill_append_unique(tools, "write")
    }
    if feedback.task == "review" {
        tools = agent_skill_append_unique(tools, "review")
    }
    if feedback.task == "verify" {
        tools = agent_skill_append_unique(tools, "build")
        tools = agent_skill_append_unique(tools, "test")
    }
    if feedback.task == "retrieve" || feedback.task == "search" {
        tools = agent_skill_append_unique(tools, "retrieve")
        tools = agent_skill_append_unique(tools, "search")
    }
    tools
}

func agent_skill_steps_for_feedback(agent_skill_feedback_state feedback, string action) []string {
    []string steps = []string{}
    if feedback.task == "code" || action == "write" || action == "write_file" || action == "apply_patch" || action == "patch" || action == "code" {
        steps = agent_skill_append_unique(steps, "inspect_workspace")
        if action == "apply_patch" || action == "patch" {
            steps = agent_skill_append_unique(steps, "apply_patch")
        } else {
            steps = agent_skill_append_unique(steps, "write_file")
        }
        steps = agent_skill_append_unique(steps, "show_pending_changes")
        steps = agent_skill_append_unique(steps, "apply_pending_changes")
        return steps
    }
    if feedback.task == "verify" || action == "build" || action == "test" {
        steps = agent_skill_append_unique(steps, "load_artifacts")
        if action == "build" {
            steps = agent_skill_append_unique(steps, "run_build")
        } else if action == "test" {
            steps = agent_skill_append_unique(steps, "run_test")
        } else {
            steps = agent_skill_append_unique(steps, "run_build")
            steps = agent_skill_append_unique(steps, "run_test")
        }
        steps = agent_skill_append_unique(steps, "report_results")
        return steps
    }
    if feedback.task == "retrieve" || action == "retrieve" || action == "read_file" {
        steps = agent_skill_append_unique(steps, "read_file")
        steps = agent_skill_append_unique(steps, "summarize_context")
        return steps
    }
    if feedback.task == "search" || action == "search" || action == "search_files" {
        steps = agent_skill_append_unique(steps, "search_files")
        steps = agent_skill_append_unique(steps, "rank_results")
        return steps
    }
    if feedback.task == "review" || action == "review" {
        steps = agent_skill_append_unique(steps, "read_file")
        steps = agent_skill_append_unique(steps, "review_code")
        steps = agent_skill_append_unique(steps, "report_findings")
        return steps
    }
    if feedback.task == "infer" || action == "infer" {
        steps = agent_skill_append_unique(steps, "load_model")
        steps = agent_skill_append_unique(steps, "generate")
        steps = agent_skill_append_unique(steps, "decode")
        return steps
    }
    if feedback.task == "s" || action == "s" || action == "run_shell" || action == "bash" {
        steps = agent_skill_append_unique(steps, "run_shell")
        steps = agent_skill_append_unique(steps, "capture_output")
        return steps
    }
    if feedback.task == "apply_unified_diff" || action == "apply_unified_diff" || action == "unified_diff" {
        steps = agent_skill_append_unique(steps, "write_diff_file")
        steps = agent_skill_append_unique(steps, "apply_patch")
        steps = agent_skill_append_unique(steps, "verify_patch")
        return steps
    }
    if feedback.task == "analyze" {
        steps = agent_skill_append_unique(steps, "extract_signals")
        steps = agent_skill_append_unique(steps, "classify_intent")
        steps = agent_skill_append_unique(steps, "summarize")
        return steps
    }
    if feedback.task == "plan" {
        steps = agent_skill_append_unique(steps, "decompose_goal")
        steps = agent_skill_append_unique(steps, "order_steps")
        steps = agent_skill_append_unique(steps, "assign_tools")
        return steps
    }
    if feedback.task == "finalize" {
        steps = agent_skill_append_unique(steps, "collect_results")
        steps = agent_skill_append_unique(steps, "format_output")
        steps = agent_skill_append_unique(steps, "emit_done")
        return steps
    }
    steps = agent_skill_append_unique(steps, "observe")
    steps = agent_skill_append_unique(steps, "plan")
    steps = agent_skill_append_unique(steps, "execute")
    steps
}

func agent_skill_name_from_feedback(agent_skill_feedback_state feedback) string {
    string base = trim(feedback.skill_name)
    if base == "" {
        base = "general"
    }
    base + "_" + feedback.task
}

func agent_skill_synthesize(agent_skill_feedback_state feedback) agent_skill_record {
    string name = agent_skill_name_from_feedback(feedback)
    string version = agent_skill_version_from_step(feedback.step)
    string status = "candidate"
    if feedback.success {
        status = "promoted"
    }
    string action = agent_skill_signal_action(feedback.signal)
    []string triggers = []string{}
    triggers = agent_skill_append_unique(triggers, feedback.task)
    triggers = agent_skill_append_unique(triggers, action)
    triggers = agent_skill_append_unique(triggers, feedback.signal)
    []string required_tools = agent_skill_required_tools(feedback, action)
    []string preconditions = []string{cap: 1}
    preconditions[0] = "trace_available"
    []string steps = agent_skill_steps_for_feedback(feedback, action)
    []string success_signals = []string{cap: 1}
    if feedback.task == "finalize" {
        success_signals[0] = "status=done"
    } else {
        success_signals[0] = "status=ok"
    }
    []string failure_signals = []string{cap: 2}
    failure_signals[0] = "status=blocked"
    failure_signals[1] = "status=failed"
    agent_skill_spec spec = agent_skill_spec {
        name: name,
        version: version,
        intent: feedback.task,
        status: status,
        triggers: triggers,
        required_tools: required_tools,
        preconditions: preconditions,
        steps: steps,
        success_signals: success_signals,
        failure_signals: failure_signals,
    }
    agent_skill_metrics metrics = new_agent_skill_metrics()
    if feedback.success {
        metrics.success_rate = 1.0
        metrics.stability = 1.0
        metrics.avg_steps = 1.0
    }
    new_agent_skill_record(spec, metrics, feedback.step)
}

func agent_skill_synthesizer_state_dict(agent_skill_record record) agent_skill_record {
    agent_skill_record_state_dict(record)
}

func agent_skill_synthesizer_load_state_dict(agent_skill_record record, agent_skill_record other) agent_skill_record {
    agent_skill_record_load_state_dict(record, other)
}

