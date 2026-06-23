package neurx.compile.cache

struct compile_cache_state {
    []string keys
    []string entries
    int hit_count
    int miss_count
}

func copy_strings([]string values) []string {
    []string out = []string{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func new_compile_cache_state() compile_cache_state {
    compile_cache_state {
        keys: [],
        entries: [],
        hit_count: 0,
        miss_count: 0,
    }
}

func make_cache_key(string module_name, string backend, string mode, bool dynamic, bool fullgraph, bool debug) string {
    string dyn = "0"
    if dynamic {
        dyn = "1"
    }
    string full = "0"
    if fullgraph {
        full = "1"
    }
    string dbg = "0"
    if debug {
        dbg = "1"
    }
    module_name + "|" + backend + "|" + mode + "|" + dyn + "|" + full + "|" + dbg
}

// Getter functions to work around compiler type inference bug with struct field indexing
func get_key(compile_cache_state cache, int index) string {
    cache.keys[index]
}

func get_entry(compile_cache_state cache, int index) string {
    cache.entries[index]
}

func cache_find_index(compile_cache_state cache, string key) int {
    int i = 0
    while i < len(cache.keys) {
        if get_key(cache, i) == key {
            return i
        }
        i = i + 1
    }
    -1
}

func cache_has_key(compile_cache_state cache, string key) bool {
    cache_find_index(cache, key) >= 0
}

func cache_put(compile_cache_state cache, string key, string entry) compile_cache_state {
    int idx = cache_find_index(cache, key)
    []string keys = copy_strings(cache.keys)
    []string entries = copy_strings(cache.entries)
    if idx >= 0 {
        entries[idx] = entry
        return compile_cache_state {
            keys: keys,
            entries: entries,
            hit_count: cache.hit_count,
            miss_count: cache.miss_count,
        }
    }
    keys.push(key)
    entries.push(entry)
    compile_cache_state {
        keys: keys,
        entries: entries,
        hit_count: cache.hit_count,
        miss_count: cache.miss_count + 1,
    }
}

func cache_hit(compile_cache_state cache) compile_cache_state {
    compile_cache_state {
        keys: copy_strings(cache.keys),
        entries: copy_strings(cache.entries),
        hit_count: cache.hit_count + 1,
        miss_count: cache.miss_count,
    }
}

func cache_entry(compile_cache_state cache, string key) string {
    int idx = cache_find_index(cache, key)
    if idx < 0 {
        return ""
    }
    get_entry(cache, idx)
}

func compile_cache_state_dict(compile_cache_state cache) compile_cache_state {
    cache
}

func compile_cache_load_state_dict(compile_cache_state cache, compile_cache_state other) compile_cache_state {
    other
}
