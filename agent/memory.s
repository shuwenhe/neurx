package neurx.agent.memory

struct agent_memory_state {
    []string short_keys
    []string short_values
    []string long_keys
    []string long_values
    int writes
    int reads
}

struct agent_memory_lookup_result {
    agent_memory_state state
    string value
    bool found
}

func new_agent_memory_state() agent_memory_state {
    agent_memory_state {
        short_keys: [],
        short_values: [],
        long_keys: [],
        long_values: [],
        writes: 0,
        reads: 0,
    }
}

func agent_memory_write_short(agent_memory_state state, string key, string value) agent_memory_state {
    int size = len(state.short_keys)
    []string keys = []string{cap: size + 1}
    []string values = []string{cap: size + 1}

    int i = 0
    while i < size {
        keys[i] = state.short_keys[i]
        values[i] = state.short_values[i]
        i = i + 1
    }

    keys[size] = key
    values[size] = value

    agent_memory_state {
        short_keys: keys,
        short_values: values,
        long_keys: state.long_keys,
        long_values: state.long_values,
        writes: state.writes + 1,
        reads: state.reads,
    }
}

func agent_memory_write_long(agent_memory_state state, string key, string value) agent_memory_state {
    int size = len(state.long_keys)
    []string keys = []string{cap: size + 1}
    []string values = []string{cap: size + 1}

    int i = 0
    while i < size {
        keys[i] = state.long_keys[i]
        values[i] = state.long_values[i]
        i = i + 1
    }

    keys[size] = key
    values[size] = value

    agent_memory_state {
        short_keys: state.short_keys,
        short_values: state.short_values,
        long_keys: keys,
        long_values: values,
        writes: state.writes + 1,
        reads: state.reads,
    }
}

func agent_memory_lookup_short(agent_memory_state state, string key) agent_memory_lookup_result {
    int i = len(state.short_keys) - 1
    while i >= 0 {
        if state.short_keys[i] == key {
            return agent_memory_lookup_result {
                state: agent_memory_state {
                    short_keys: state.short_keys,
                    short_values: state.short_values,
                    long_keys: state.long_keys,
                    long_values: state.long_values,
                    writes: state.writes,
                    reads: state.reads + 1,
                },
                value: state.short_values[i],
                found: true,
            }
        }
        i = i - 1
    }

    agent_memory_lookup_result {
        state: agent_memory_state {
            short_keys: state.short_keys,
            short_values: state.short_values,
            long_keys: state.long_keys,
            long_values: state.long_values,
            writes: state.writes,
            reads: state.reads + 1,
        },
        value: "",
        found: false,
    }
}

func agent_memory_lookup_long(agent_memory_state state, string key) agent_memory_lookup_result {
    int i = len(state.long_keys) - 1
    while i >= 0 {
        if state.long_keys[i] == key {
            return agent_memory_lookup_result {
                state: agent_memory_state {
                    short_keys: state.short_keys,
                    short_values: state.short_values,
                    long_keys: state.long_keys,
                    long_values: state.long_values,
                    writes: state.writes,
                    reads: state.reads + 1,
                },
                value: state.long_values[i],
                found: true,
            }
        }
        i = i - 1
    }

    agent_memory_lookup_result {
        state: agent_memory_state {
            short_keys: state.short_keys,
            short_values: state.short_values,
            long_keys: state.long_keys,
            long_values: state.long_values,
            writes: state.writes,
            reads: state.reads + 1,
        },
        value: "",
        found: false,
    }
}

func agent_memory_state_dict(agent_memory_state state) agent_memory_state {
    state
}

func agent_memory_load_state_dict(agent_memory_state state, agent_memory_state other) agent_memory_state {
    other
}
