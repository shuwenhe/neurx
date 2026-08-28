package neurx.agent.interrupt
struct agent_interrupt_state {
    bool pending
    string reason
    string kind
    string response
    bool resolved
    int interrupt_count
}

func new_agent_interrupt_state() agent_interrupt_state {
    agent_interrupt_state {
        pending: false,
        reason: "",
        kind: "",
        response: "",
        resolved: true,
        interrupt_count: 0,
    }
}

func agent_interrupt_request(agent_interrupt_state state, string kind, string reason) agent_interrupt_state {
    agent_interrupt_state {
        pending: true,
        reason: reason,
        kind: kind,
        response: "",
        resolved: false,
        interrupt_count: state.interrupt_count + 1,
    }
}

func agent_interrupt_resolve(agent_interrupt_state state, string response) agent_interrupt_state {
    agent_interrupt_state {
        pending: false,
        reason: state.reason,
        kind: state.kind,
        response: response,
        resolved: true,
        interrupt_count: state.interrupt_count,
    }
}

func agent_interrupt_approved(agent_interrupt_state state) bool {
    if !state.resolved {
        return false
    }
    string r = lower(trim(state.response))
    r == "yes" || r == "y" || r == "ok" || r == "approve" || r == "confirmed"
}

func agent_interrupt_should_request(string action, string observation) bool {
    string a = lower(trim(action))
    string o = lower(trim(observation))
    if a == "delete" || a == "delete_path" || a == "write" || a == "write_file" || a == "create_file" || a == "mkdir" || a == "create_directory" || a == "apply_patch" || a == "patch" || a == "code" {
        return true
    }
    if o == "confirm_required" || o == "needs_approval" {
        return true
    }
    false
}

func agent_interrupt_summary(agent_interrupt_state state) string {
    "pending=" + string(state.pending) + " kind=" + state.kind + " count=" + string(state.interrupt_count) + " resolved=" + string(state.resolved)
}
