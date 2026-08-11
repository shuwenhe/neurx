package neurx.agent.skill_schema
use neurx.strings
struct agent_skill_spec {
    string name
    string version
    string intent
    string status
    []string triggers
    []string required_tools
    []string preconditions
    []string steps
    []string success_signals
    []string failure_signals
}

struct agent_skill_metrics {
    float success_rate
    float avg_steps
    float avg_latency
    float tool_cost
    float stability
}

struct agent_skill_record {
    agent_skill_spec spec
    agent_skill_metrics metrics
    int created_step
    int last_updated_step
    int promote_count
    int fail_count
    int success_count
    int total_steps
    bool promoted
    bool retired
    float score
}

func new_agent_skill_spec(string name, string version, string intent, string status) agent_skill_spec {
    agent_skill_spec {
        name: name,
        version: version,
        intent: intent,
        status: status,
        triggers: [],
        required_tools: [],
        preconditions: [],
        steps: [],
        success_signals: [],
        failure_signals: [],
    }
}

func new_agent_skill_metrics() agent_skill_metrics {
    agent_skill_metrics {
        success_rate: 0.0,
        avg_steps: 0.0,
        avg_latency: 0.0,
        tool_cost: 0.0,
        stability: 0.0,
    }
}

func new_agent_skill_record(agent_skill_spec spec, agent_skill_metrics metrics, int created_step) agent_skill_record {
    agent_skill_record {
        spec: spec,
        metrics: metrics,
        created_step: created_step,
        last_updated_step: created_step,
        promote_count: 0,
        fail_count: 0,
        success_count: 0,
        total_steps: 0,
        promoted: false,
        retired: false,
        score: 0.0,
    }
}

func agent_skill_spec_state_dict(agent_skill_spec spec) agent_skill_spec {
    agent_skill_spec {
        name: spec.name,
        version: spec.version,
        intent: spec.intent,
        status: spec.status,
        triggers: copy_strings(spec.triggers),
        required_tools: copy_strings(spec.required_tools),
        preconditions: copy_strings(spec.preconditions),
        steps: copy_strings(spec.steps),
        success_signals: copy_strings(spec.success_signals),
        failure_signals: copy_strings(spec.failure_signals),
    }
}

func agent_skill_spec_load_state_dict(agent_skill_spec spec, agent_skill_spec other) agent_skill_spec {
    agent_skill_spec_state_dict(other)
}

func agent_skill_metrics_state_dict(agent_skill_metrics metrics) agent_skill_metrics {
    metrics
}

func agent_skill_metrics_load_state_dict(agent_skill_metrics metrics, agent_skill_metrics other) agent_skill_metrics {
    other
}

func agent_skill_record_state_dict(agent_skill_record record) agent_skill_record {
    agent_skill_record {
        spec: agent_skill_spec_state_dict(record.spec),
        metrics: agent_skill_metrics_state_dict(record.metrics),
        created_step: record.created_step,
        last_updated_step: record.last_updated_step,
        promote_count: record.promote_count,
        fail_count: record.fail_count,
        success_count: record.success_count,
        total_steps: record.total_steps,
        promoted: record.promoted,
        retired: record.retired,
        score: record.score,
    }
}

func agent_skill_record_load_state_dict(agent_skill_record record, agent_skill_record other) agent_skill_record {
    agent_skill_record {
        spec: agent_skill_spec_load_state_dict(record.spec, other.spec),
        metrics: agent_skill_metrics_load_state_dict(record.metrics, other.metrics),
        created_step: other.created_step,
        last_updated_step: other.last_updated_step,
        promote_count: other.promote_count,
        fail_count: other.fail_count,
        success_count: other.success_count,
        total_steps: other.total_steps,
        promoted: other.promoted,
        retired: other.retired,
        score: other.score,
    }
}
