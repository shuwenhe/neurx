package neurx.agent.tool_registry

struct agent_tool_registry_state {
    []string tool_names
    []bool enabled
    []int timeout_ms
    []int retries
}

func new_agent_tool_registry_state() agent_tool_registry_state {
    agent_tool_registry_state {
        tool_names: [],
        enabled: [],
        timeout_ms: [],
        retries: [],
    }
}

func agent_tool_registry_count(agent_tool_registry_state state) int {
    len(state.tool_names)
}

func agent_tool_registry_add(agent_tool_registry_state state, string tool_name, bool is_enabled, int timeout_ms, int retries) agent_tool_registry_state {
    int size = len(state.tool_names)
    []string names = []string{cap: size + 1}
    []bool enabled = []bool{cap: size + 1}
    []int timeouts = []int{cap: size + 1}
    []int retry_values = []int{cap: size + 1}

    int i = 0
    while i < size {
        names[i] = state.tool_names[i]
        enabled[i] = state.enabled[i]
        timeouts[i] = state.timeout_ms[i]
        retry_values[i] = state.retries[i]
        i = i + 1
    }

    int next_timeout = timeout_ms
    if next_timeout < 0 {
        next_timeout = 0
    }
    int next_retries = retries
    if next_retries < 0 {
        next_retries = 0
    }

    names[size] = tool_name
    enabled[size] = is_enabled
    timeouts[size] = next_timeout
    retry_values[size] = next_retries

    agent_tool_registry_state {
        tool_names: names,
        enabled: enabled,
        timeout_ms: timeouts,
        retries: retry_values,
    }
}

func agent_tool_registry_has_enabled(agent_tool_registry_state state, string tool_name) bool {
    int i = 0
    while i < len(state.tool_names) {
        if state.tool_names[i] == tool_name {
            return state.enabled[i]
        }
        i = i + 1
    }
    false
}

func agent_tool_registry_timeout_ms(agent_tool_registry_state state, string tool_name) int {
    int i = 0
    while i < len(state.tool_names) {
        if state.tool_names[i] == tool_name {
            return state.timeout_ms[i]
        }
        i = i + 1
    }
    0
}

func agent_tool_registry_retries(agent_tool_registry_state state, string tool_name) int {
    int i = 0
    while i < len(state.tool_names) {
        if state.tool_names[i] == tool_name {
            return state.retries[i]
        }
        i = i + 1
    }
    0
}

func agent_tool_registry_state_dict(agent_tool_registry_state state) agent_tool_registry_state {
    state
}

func agent_tool_registry_load_state_dict(agent_tool_registry_state state, agent_tool_registry_state other) agent_tool_registry_state {
    other
}
