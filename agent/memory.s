package neurx.agent.memory

use neurx.runtime.io.{runtime_write_text_file, runtime_read_text_file, runtime_file_exists}

struct agent_memory_state {
    []string short_keys
    []string short_values
    []string long_keys
    []string long_values
    int writes
    int reads
    int max_short_size
    int max_long_size
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
        max_short_size: 32,
        max_long_size: 256,
    }
}

func agent_memory_write_short(agent_memory_state state, string key, string value) agent_memory_state {
    int old_size = len(state.short_keys)
    int new_size = old_size + 1
    int max = state.max_short_size
    if max <= 0 {
        max = 32
    }
    int start = 0
    int out_size = new_size
    if new_size > max {
        start = new_size - max
        out_size = max
    }
    []string keys = []string{cap: out_size}
    []string values = []string{cap: out_size}

    int i = 0
    while i < old_size - start {
        keys[i] = state.short_keys[i + start]
        values[i] = state.short_values[i + start]
        i = i + 1
    }

    keys[out_size - 1] = key
    values[out_size - 1] = value

    agent_memory_state {
        short_keys: keys,
        short_values: values,
        long_keys: state.long_keys,
        long_values: state.long_values,
        writes: state.writes + 1,
        reads: state.reads,
        max_short_size: state.max_short_size,
    }
}

func agent_memory_write_long(agent_memory_state state, string key, string value) agent_memory_state {
    int old_size = len(state.long_keys)
    int new_size = old_size + 1
    int max = state.max_long_size
    if max <= 0 {
        max = 256
    }
    int start = 0
    int out_size = new_size
    if new_size > max {
        start = new_size - max
        out_size = max
    }
    []string keys = []string{cap: out_size}
    []string values = []string{cap: out_size}

    int i = 0
    while i < old_size - start {
        keys[i] = state.long_keys[i + start]
        values[i] = state.long_values[i + start]
        i = i + 1
    }

    keys[out_size - 1] = key
    values[out_size - 1] = value

    agent_memory_state {
        short_keys: state.short_keys,
        short_values: state.short_values,
        long_keys: keys,
        long_values: values,
        writes: state.writes + 1,
        reads: state.reads,
        max_short_size: state.max_short_size,
        max_long_size: state.max_long_size,
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
                    max_short_size: state.max_short_size,
                    max_long_size: state.max_long_size,
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
            max_short_size: state.max_short_size,
            max_long_size: state.max_long_size,
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
                    max_short_size: state.max_short_size,
                    max_long_size: state.max_long_size,
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
            max_short_size: state.max_short_size,
            max_long_size: state.max_long_size,
        },
        value: "",
        found: false,
    }
}

func agent_memory_lookup(agent_memory_state state, string key) agent_memory_lookup_result {
    agent_memory_lookup_result short_result = agent_memory_lookup_short(state, key)
    if short_result.found {
        return short_result
    }
    agent_memory_lookup_long(short_result.state, key)
}

func agent_memory_state_dict(agent_memory_state state) agent_memory_state {
    state
}

func agent_memory_clear_short(agent_memory_state state) agent_memory_state {
    agent_memory_state {
        short_keys: [],
        short_values: [],
        long_keys: state.long_keys,
        long_values: state.long_values,
        writes: state.writes,
        reads: state.reads,
        max_short_size: state.max_short_size,
        max_long_size: state.max_long_size,
    }
}

func agent_memory_clear_long(agent_memory_state state) agent_memory_state {
    agent_memory_state {
        short_keys: state.short_keys,
        short_values: state.short_values,
        long_keys: [],
        long_values: [],
        writes: state.writes,
        reads: state.reads,
        max_short_size: state.max_short_size,
        max_long_size: state.max_long_size,
    }
}

func agent_memory_load_state_dict(agent_memory_state state, agent_memory_state other) agent_memory_state {
    other
}

func agent_memory_short_keys(agent_memory_state state) []string {
    int size = len(state.short_keys)
    []string out = []string{cap: size}
    int i = 0
    while i < size {
        out[i] = state.short_keys[i]
        i = i + 1
    }
    out
}

func agent_memory_long_keys(agent_memory_state state) []string {
    int size = len(state.long_keys)
    []string out = []string{cap: size}
    int i = 0
    while i < size {
        out[i] = state.long_keys[i]
        i = i + 1
    }
    out
}

func agent_memory_has_key(agent_memory_state state, string key) bool {
    agent_memory_lookup_result r = agent_memory_lookup(state, key)
    r.found
}

func agent_memory_delete(agent_memory_state state, string key) agent_memory_state {
    int s_size = len(state.short_keys)
    int l_size = len(state.long_keys)
    int s_keep = 0
    int i = 0
    while i < s_size {
        if state.short_keys[i] != key {
            s_keep = s_keep + 1
        }
        i = i + 1
    }
    []string short_k = []string{cap: s_keep}
    []string short_v = []string{cap: s_keep}
    int wi = 0
    i = 0
    while i < s_size {
        if state.short_keys[i] != key {
            short_k[wi] = state.short_keys[i]
            short_v[wi] = state.short_values[i]
            wi = wi + 1
        }
        i = i + 1
    }
    int l_keep = 0
    i = 0
    while i < l_size {
        if state.long_keys[i] != key {
            l_keep = l_keep + 1
        }
        i = i + 1
    }
    []string long_k = []string{cap: l_keep}
    []string long_v = []string{cap: l_keep}
    wi = 0
    i = 0
    while i < l_size {
        if state.long_keys[i] != key {
            long_k[wi] = state.long_keys[i]
            long_v[wi] = state.long_values[i]
            wi = wi + 1
        }
        i = i + 1
    }
    agent_memory_state {
        short_keys: short_k,
        short_values: short_v,
        long_keys: long_k,
        long_values: long_v,
        writes: state.writes,
        reads: state.reads,
        max_short_size: state.max_short_size,
        max_long_size: state.max_long_size,
    }
}

func agent_memory_export(agent_memory_state state) string {
    string out = ""
    int i = 0
    while i < len(state.short_keys) {
        out = out + "short:" + state.short_keys[i] + "=" + state.short_values[i] + "\n"
        i = i + 1
    }
    i = 0
    while i < len(state.long_keys) {
        out = out + "long:" + state.long_keys[i] + "=" + state.long_values[i] + "\n"
        i = i + 1
    }
    out
}

func agent_memory_persist(agent_memory_state state, string path) string {
    runtime_write_text_file(path, agent_memory_export(state))
    path
}

func agent_memory_restore(string path) agent_memory_state {
    agent_memory_state next = new_agent_memory_state()
    if !runtime_file_exists(path) {
        return next
    }
    string content = runtime_read_text_file(path)
    int content_len = len(content)
    string cur_line = ""
    int ci = 0
    while ci <= content_len {
        bool at_end = ci == content_len
        bool at_newline = !at_end && content[ci] == '\n'
        if at_newline || at_end {
            string ln = cur_line
            cur_line = ""
            if len(ln) > 5 {
                bool is_short = len(ln) > 6 && ln[0] == 's' && ln[1] == 'h' && ln[2] == 'o' && ln[3] == 'r' && ln[4] == 't' && ln[5] == ':'
                bool is_long = len(ln) > 5 && ln[0] == 'l' && ln[1] == 'o' && ln[2] == 'n' && ln[3] == 'g' && ln[4] == ':'
                int prefix_len = 0
                if is_short {
                    prefix_len = 6
                } else if is_long {
                    prefix_len = 5
                }
                if prefix_len > 0 {
                    string rest = ""
                    int ri = prefix_len
                    while ri < len(ln) {
                        rest = rest + string(ln[ri])
                        ri = ri + 1
                    }
                    string kv_key = ""
                    string kv_val = ""
                    bool past_eq = false
                    int ki = 0
                    while ki < len(rest) {
                        if !past_eq && rest[ki] == '=' {
                            past_eq = true
                        } else if past_eq {
                            kv_val = kv_val + string(rest[ki])
                        } else {
                            kv_key = kv_key + string(rest[ki])
                        }
                        ki = ki + 1
                    }
                    if kv_key != "" {
                        if is_short {
                            next = agent_memory_write_short(next, kv_key, kv_val)
                        } else {
                            next = agent_memory_write_long(next, kv_key, kv_val)
                        }
                    }
                }
            }
        } else {
            cur_line = cur_line + string(content[ci])
        }
        ci = ci + 1
    }
    next
}
