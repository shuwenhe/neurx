package neurx.agent.skill_synthesizer

use neurx.agent.skill_schema
use neurx.agent.skill_feedback

func agent_skill_version_from_step(int step) string {
    "v" + string(step)
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

    []string triggers = []string{cap: 2}
    triggers[0] = feedback.task
    triggers[1] = feedback.signal

    []string required_tools = []string{cap: 1}
    required_tools[0] = feedback.skill_name

    []string preconditions = []string{cap: 1}
    preconditions[0] = "trace_available"

    []string steps = []string{cap: 3}
    if feedback.task == "infer" {
        steps = []string{cap: 4}
        steps[0] = "load_model"
        steps[1] = "tokenize"
        steps[2] = "generate"
        steps[3] = "decode"
    } else if feedback.task == "retrieve" {
        steps[0] = "formulate_query"
        steps[1] = "fetch_documents"
        steps[2] = "rank_results"
    } else if feedback.task == "verify" {
        steps[0] = "load_artifacts"
        steps[1] = "run_checks"
        steps[2] = "report_results"
    } else if feedback.task == "analyze" {
        steps[0] = "extract_signals"
        steps[1] = "classify_intent"
        steps[2] = "summarize"
    } else if feedback.task == "plan" {
        steps[0] = "decompose_goal"
        steps[1] = "order_steps"
        steps[2] = "assign_tools"
    } else if feedback.task == "finalize" {
        steps[0] = "collect_results"
        steps[1] = "format_output"
        steps[2] = "emit_done"
    } else {
        steps[0] = "observe"
        steps[1] = "plan"
        steps[2] = "execute"
    }

    []string success_signals = []string{cap: 1}
    success_signals[0] = "done"

    []string failure_signals = []string{cap: 2}
    failure_signals[0] = "tool_unavailable"
    failure_signals[1] = feedback.task + ":failed"

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
