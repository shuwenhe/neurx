package neurx.agent.tool_registry

struct agent_tool_registry_state {
    []string tool_names
    []bool enabled
    []int timeout_ms
    []int retries
    []string capabilities
}

func new_agent_tool_registry_state() agent_tool_registry_state {
    agent_tool_registry_state {
        tool_names: [],
        enabled: [],
        timeout_ms: [],
        retries: [],
        capabilities: [],
    }
}

func agent_tool_registry_count(agent_tool_registry_state state) int {
    len(state.tool_names)
}

func agent_tool_registry_add(agent_tool_registry_state state, string tool_name, bool is_enabled, int timeout_ms, int retries) agent_tool_registry_state {
    agent_tool_registry_add_with_capability(state, tool_name, is_enabled, timeout_ms, retries, tool_name)
}

func agent_tool_registry_add_with_capability(agent_tool_registry_state state, string tool_name, bool is_enabled, int timeout_ms, int retries, string capability) agent_tool_registry_state {
    int size = len(state.tool_names)
    []string names = []string{cap: size + 1}
    []bool enabled = []bool{cap: size + 1}
    []int timeouts = []int{cap: size + 1}
    []int retry_values = []int{cap: size + 1}
    []string caps = []string{cap: size + 1}
    int i = 0
    for i < size {
        names[i] = state.tool_names[i]
        enabled[i] = state.enabled[i]
        timeouts[i] = state.timeout_ms[i]
        retry_values[i] = state.retries[i]
        caps[i] = state.capabilities[i]
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
    caps[size] = capability
    agent_tool_registry_state {
        tool_names: names,
        enabled: enabled,
        timeout_ms: timeouts,
        retries: retry_values,
        capabilities: caps,
    }
}

func agent_tool_registry_has_enabled(agent_tool_registry_state state, string tool_name) bool {
    int i = 0
    for i < len(state.tool_names) {
        if state.tool_names[i] == tool_name {
            return state.enabled[i]
        }
        i = i + 1
    }
    false
}

func agent_tool_registry_timeout_ms(agent_tool_registry_state state, string tool_name) int {
    int i = 0
    for i < len(state.tool_names) {
        if state.tool_names[i] == tool_name {
            return state.timeout_ms[i]
        }
        i = i + 1
    }
    0
}

func agent_tool_registry_retries(agent_tool_registry_state state, string tool_name) int {
    int i = 0
    for i < len(state.tool_names) {
        if state.tool_names[i] == tool_name {
            return state.retries[i]
        }
        i = i + 1
    }
    0
}

func agent_tool_registry_capability(agent_tool_registry_state state, string tool_name) string {
    int i = 0
    for i < len(state.tool_names) {
        if state.tool_names[i] == tool_name {
            return state.capabilities[i]
        }
        i = i + 1
    }
    ""
}

func agent_tool_registry_find_by_capability(agent_tool_registry_state state, string capability) string {
    int i = 0
    for i < len(state.tool_names) {
        if state.enabled[i] && state.capabilities[i] == capability {
            return state.tool_names[i]
        }
        i = i + 1
    }
    ""
}

func agent_tool_registry_set_enabled(agent_tool_registry_state state, string tool_name, bool is_enabled) agent_tool_registry_state {
    int size = len(state.tool_names)
    int index = -1
    int i = 0
    for i < size {
        if state.tool_names[i] == tool_name {
            index = i
            break
        }
        i = i + 1
    }
    if index < 0 {
        return state
    }
    []bool enabled = []bool{cap: size}
    i = 0
    for i < size {
        enabled[i] = state.enabled[i]
        i = i + 1
    }
    enabled[index] = is_enabled
    agent_tool_registry_state {
        tool_names: state.tool_names,
        enabled: enabled,
        timeout_ms: state.timeout_ms,
        retries: state.retries,
        capabilities: state.capabilities,
    }
}

func agent_tool_registry_disable(agent_tool_registry_state state, string tool_name) agent_tool_registry_state {
    agent_tool_registry_set_enabled(state, tool_name, false)
}

func agent_tool_registry_enable(agent_tool_registry_state state, string tool_name) agent_tool_registry_state {
    agent_tool_registry_set_enabled(state, tool_name, true)
}

func agent_tool_registry_state_dict(agent_tool_registry_state state) agent_tool_registry_state {
    state
}

func agent_tool_registry_load_state_dict(agent_tool_registry_state state, agent_tool_registry_state other) agent_tool_registry_state {
    other
}

func agent_tool_registry_enabled_names(agent_tool_registry_state state) []string {
    int count = 0
    int i = 0
    for i < len(state.tool_names) {
        if state.enabled[i] {
            count = count + 1
        }
        i = i + 1
    }
    []string out = []string{cap: count}
    int wi = 0
    i = 0
    for i < len(state.tool_names) {
        if state.enabled[i] {
            out[wi] = state.tool_names[i]
            wi = wi + 1
        }
        i = i + 1
    }
    out
}

func agent_tool_registry_summary(agent_tool_registry_state state) string {
    string out = "tools=" + string(len(state.tool_names))
    int i = 0
    for i < len(state.tool_names) {
        string flag = "off"
        if state.enabled[i] {
            flag = "on"
        }
        out = out + "\ntool[" + string(i) + "]=" + state.tool_names[i] + " cap=" + state.capabilities[i] + " " + flag
        i = i + 1
    }
    out
}

func agent_tool_registry_set_retries(agent_tool_registry_state state, string tool_name, int retries) agent_tool_registry_state {
    int size = len(state.tool_names)
    int index = -1
    int i = 0
    for i < size {
        if state.tool_names[i] == tool_name {
            index = i
            break
        }
        i = i + 1
    }
    if index < 0 {
        return state
    }
    int val = retries
    if val < 0 {
        val = 0
    }
    []int retry_values = []int{cap: size}
    i = 0
    for i < size {
        retry_values[i] = state.retries[i]
        i = i + 1
    }
    retry_values[index] = val
    agent_tool_registry_state {
        tool_names: state.tool_names,
        enabled: state.enabled,
        timeout_ms: state.timeout_ms,
        retries: retry_values,
        capabilities: state.capabilities,
    }
}

func agent_tool_registry_set_timeout(agent_tool_registry_state state, string tool_name, int ms) agent_tool_registry_state {
    int size = len(state.tool_names)
    int index = -1
    int i = 0
    for i < size {
        if state.tool_names[i] == tool_name {
            index = i
            break
        }
        i = i + 1
    }
    if index < 0 {
        return state
    }
    int val = ms
    if val < 0 {
        val = 0
    }
    []int timeouts = []int{cap: size}
    i = 0
    for i < size {
        timeouts[i] = state.timeout_ms[i]
        i = i + 1
    }
    timeouts[index] = val
    agent_tool_registry_state {
        tool_names: state.tool_names,
        enabled: state.enabled,
        timeout_ms: timeouts,
        retries: state.retries,
        capabilities: state.capabilities,
    }
}
