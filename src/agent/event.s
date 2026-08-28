package neurx.agent.event
struct agent_event_state {
    string[] kinds
    string[] payloads
    int[] steps
    int count
}

func new_agent_event_state() agent_event_state {
    agent_event_state {
        kinds: [],
        payloads: [],
        steps: [],
        count: 0,
    }
}

func agent_event_record(agent_event_state state, string kind, string payload, int step) agent_event_state {
    int n = state.count
    string[] new_kinds = string[]{cap: n + 1}
    string[] new_payloads = string[]{cap: n + 1}
    int[] new_steps = int[]{cap: n + 1}
    int i = 0
    for i < n {
        new_kinds[i] = state.kinds[i]
        new_payloads[i] = state.payloads[i]
        new_steps[i] = state.steps[i]
        i = i + 1
    }
    new_kinds[n] = kind
    new_payloads[n] = payload
    new_steps[n] = step
    agent_event_state {
        kinds: new_kinds,
        payloads: new_payloads,
        steps: new_steps,
        count: n + 1,
    }
}

func agent_event_last_kind(agent_event_state state) string {
    if state.count <= 0 {
        return ""
    }
    state.kinds[state.count - 1]
}

func agent_event_last_payload(agent_event_state state) string {
    if state.count <= 0 {
        return ""
    }
    state.payloads[state.count - 1]
}

func agent_event_count_by_kind(agent_event_state state, string kind) int {
    int total = 0
    int i = 0
    for i < state.count {
        if state.kinds[i] == kind {
            total = total + 1
        }
        i = i + 1
    }
    total
}

func agent_event_has_kind(agent_event_state state, string kind) bool {
    int i = 0
    for i < state.count {
        if state.kinds[i] == kind {
            return true
        }
        i = i + 1
    }
    false
}

func agent_event_record_step_ok(agent_event_state state, int step, string task) agent_event_state {
    agent_event_record(state, "step_ok", "task=" + task, step)
}

func agent_event_record_step_fail(agent_event_state state, int step, string task) agent_event_state {
    agent_event_record(state, "step_fail", "task=" + task, step)
}

func agent_event_record_skill_learned(agent_event_state state, int step, string skill_name) agent_event_state {
    agent_event_record(state, "skill_learned", "skill=" + skill_name, step)
}

func agent_event_record_safety_blocked(agent_event_state state, int step, string reason) agent_event_state {
    agent_event_record(state, "safety_blocked", "reason=" + reason, step)
}

func agent_event_record_replan(agent_event_state state, int step, string new_task) agent_event_state {
    agent_event_record(state, "replan", "task=" + new_task, step)
}

func agent_event_record_interrupt(agent_event_state state, int step, string kind) agent_event_state {
    agent_event_record(state, "interrupt", "kind=" + kind, step)
}

func agent_event_record_answer_ready(agent_event_state state, int step) agent_event_state {
    agent_event_record(state, "answer_ready", "", step)
}

func agent_event_export(agent_event_state state) string {
    string out = "events;count=" + string(state.count) + "\n"
    int i = 0
    for i < state.count {
        out = out + "event[" + string(i) + "]=" + state.kinds[i] + ";payload=" + state.payloads[i] + ";step=" + string(state.steps[i]) + "\n"
        i = i + 1
    }
    out
}

func agent_event_summary(agent_event_state state) string {
    "events=" + string(state.count) + ";last=" + agent_event_last_kind(state)
}
