package neurx.tool.tool_cache

struct tool_cache_entry {
    string key
    string value
    int    hit_count
    bool   valid
}

struct tool_cache_state {
    []tool_cache_entry entries
    int capacity
    int size
    int evict_ptr
    int total_hits
    int total_misses
    int total_evictions
}

struct tool_cache_result {
    bool   hit
    string value
}

func new_tool_cache(int capacity) tool_cache_state {
    int cap_val = capacity
    if cap_val < 1 {
        cap_val = 32
    }
    []tool_cache_entry entries = []tool_cache_entry{cap: cap_val}
    int i = 0
    while i < cap_val {
        entries[i] = tool_cache_entry {
            key:       "",
            value:     "",
            hit_count: 0,
            valid:     false,
        }
        i = i + 1
    }
    tool_cache_state {
        entries:         entries,
        capacity:        cap_val,
        size:            0,
        evict_ptr:       0,
        total_hits:      0,
        total_misses:    0,
        total_evictions: 0,
    }
}

func new_tool_cache_default() tool_cache_state {
    new_tool_cache(64)
}

func tool_cache_make_key(string tool_name, string input) string {
    tool_name + "\x00" + input
}

func tool_cache_text_eq(string a, string b) bool {
    int la = len(a)
    int lb = len(b)
    if la != lb {
        return false
    }
    int i = 0
    while i < la {
        if a[i] != b[i] {
            return false
        }
        i = i + 1
    }
    true
}

func tool_cache_get(tool_cache_state state, string tool_name, string input) tool_cache_result {
    string key = tool_cache_make_key(tool_name, input)
    int i = 0
    while i < state.capacity {
        if state.entries[i].valid && tool_cache_text_eq(state.entries[i].key, key) {
            return tool_cache_result { hit: true, value: state.entries[i].value }
        }
        i = i + 1
    }
    tool_cache_result { hit: false, value: "" }
}

func tool_cache_record_hit(tool_cache_state state, string tool_name, string input) tool_cache_state {
    string key = tool_cache_make_key(tool_name, input)
    []tool_cache_entry next = []tool_cache_entry{cap: state.capacity}
    int i = 0
    while i < state.capacity {
        next[i] = state.entries[i]
        if state.entries[i].valid && tool_cache_text_eq(state.entries[i].key, key) {
            next[i] = tool_cache_entry {
                key:       state.entries[i].key,
                value:     state.entries[i].value,
                hit_count: state.entries[i].hit_count + 1,
                valid:     true,
            }
        }
        i = i + 1
    }
    tool_cache_state {
        entries:         next,
        capacity:        state.capacity,
        size:            state.size,
        evict_ptr:       state.evict_ptr,
        total_hits:      state.total_hits + 1,
        total_misses:    state.total_misses,
        total_evictions: state.total_evictions,
    }
}

func tool_cache_record_miss(tool_cache_state state) tool_cache_state {
    tool_cache_state {
        entries:         state.entries,
        capacity:        state.capacity,
        size:            state.size,
        evict_ptr:       state.evict_ptr,
        total_hits:      state.total_hits,
        total_misses:    state.total_misses + 1,
        total_evictions: state.total_evictions,
    }
}

func tool_cache_put(tool_cache_state state, string tool_name, string input, string value) tool_cache_state {
    string key = tool_cache_make_key(tool_name, input)

    int found_idx = -1
    int i = 0
    while i < state.capacity {
        if state.entries[i].valid && tool_cache_text_eq(state.entries[i].key, key) {
            found_idx = i
            break
        }
        i = i + 1
    }

    []tool_cache_entry next = []tool_cache_entry{cap: state.capacity}
    int j = 0
    while j < state.capacity {
        next[j] = state.entries[j]
        j = j + 1
    }

    if found_idx >= 0 {
        next[found_idx] = tool_cache_entry {
            key:       key,
            value:     value,
            hit_count: state.entries[found_idx].hit_count,
            valid:     true,
        }
        return tool_cache_state {
            entries:         next,
            capacity:        state.capacity,
            size:            state.size,
            evict_ptr:       state.evict_ptr,
            total_hits:      state.total_hits,
            total_misses:    state.total_misses,
            total_evictions: state.total_evictions,
        }
    }

    int slot = -1
    int k = 0
    while k < state.capacity {
        if !state.entries[k].valid {
            slot = k
            break
        }
        k = k + 1
    }

    int evictions = state.total_evictions
    int new_size = state.size
    int evict_ptr = state.evict_ptr

    if slot < 0 {

        slot = evict_ptr
        evict_ptr = (evict_ptr + 1) / state.capacity
        if (evict_ptr + 1) < state.capacity {
            evict_ptr = evict_ptr + 1
        } else {
            evict_ptr = 0
        }
        evictions = evictions + 1
    } else {
        new_size = new_size + 1
    }

    next[slot] = tool_cache_entry {
        key:       key,
        value:     value,
        hit_count: 0,
        valid:     true,
    }

    tool_cache_state {
        entries:         next,
        capacity:        state.capacity,
        size:            new_size,
        evict_ptr:       evict_ptr,
        total_hits:      state.total_hits,
        total_misses:    state.total_misses,
        total_evictions: evictions,
    }
}

func tool_cache_invalidate_tool(tool_cache_state state, string tool_name) tool_cache_state {
    string prefix = tool_name + "\x00"
    int prefix_len = len(prefix)
    []tool_cache_entry next = []tool_cache_entry{cap: state.capacity}
    int new_size = state.size
    int i = 0
    while i < state.capacity {
        next[i] = state.entries[i]
        if state.entries[i].valid {
            bool starts = true
            if len(state.entries[i].key) < prefix_len {
                starts = false
            } else {
                int j = 0
                while j < prefix_len {
                    if state.entries[i].key[j] != prefix[j] {
                        starts = false
                        break
                    }
                    j = j + 1
                }
            }
            if starts {
                next[i] = tool_cache_entry {
                    key:       "",
                    value:     "",
                    hit_count: 0,
                    valid:     false,
                }
                new_size = new_size - 1
            }
        }
        i = i + 1
    }
    tool_cache_state {
        entries:         next,
        capacity:        state.capacity,
        size:            new_size,
        evict_ptr:       state.evict_ptr,
        total_hits:      state.total_hits,
        total_misses:    state.total_misses,
        total_evictions: state.total_evictions,
    }
}

func tool_cache_invalidate_path(tool_cache_state state, string path) tool_cache_state {
    tool_cache_state s = tool_cache_invalidate_tool(
        tool_cache_invalidate_tool(state, "read"),
        "grep"
    )
    s
}

func tool_cache_clear(tool_cache_state state) tool_cache_state {
    new_tool_cache(state.capacity)
}

func tool_cache_hit_rate_pct(tool_cache_state state) int {
    int total = state.total_hits + state.total_misses
    if total == 0 {
        return 0
    }
    (state.total_hits * 100) / total
}

func tool_cache_summary(tool_cache_state state) string {
    "tool_cache size=" + string(state.size) + "/" + string(state.capacity) +
    " hits=" + string(state.total_hits) +
    " misses=" + string(state.total_misses) +
    " hit_rate=" + string(tool_cache_hit_rate_pct(state)) + "%" +
    " evictions=" + string(state.total_evictions)
}
