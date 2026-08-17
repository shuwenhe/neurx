package neurx.serving.router.cache_aware_router

func cache_route_none() int { 0 }

func cache_route_affinity() int { 1 }

func cache_route_load() int { 2 }

struct cache_aware_router_config {
    int cache_threshold_per_mille
    int balance_absolute_threshold
    int balance_relative_percent
    int max_affinity_entries
}

struct cache_aware_router_state {
    cache_aware_router_config config
    []int worker_ids
    []int worker_pool_ids
    []int worker_model_ids
    []int worker_loads
    []int worker_healthy
    int worker_count
    []int affinity_pool_ids
    []int affinity_model_ids
    []int affinity_prefix_hashes
    []int affinity_prefix_tokens
    []int affinity_worker_ids
    []int affinity_last_access
    int affinity_count
    int logical_clock
    int affinity_routes
    int load_routes
    int cold_routes
}

struct cache_route_result {
    cache_aware_router_state state
    int worker_id
    int matched_prefix_tokens
    int strategy
    bool routed
}

func cache_router_int_array(int capacity) []int {
    []int values = []int{cap: capacity}
    int i = 0
    while i < capacity { values[i] = 0; i = i + 1 }
    values
}

func new_cache_aware_router(cache_aware_router_config config) cache_aware_router_state {
    if config.cache_threshold_per_mille < 0 { config.cache_threshold_per_mille = 0 }
    if config.cache_threshold_per_mille > 1000 { config.cache_threshold_per_mille = 1000 }
    if config.balance_absolute_threshold < 0 { config.balance_absolute_threshold = 0 }
    if config.balance_relative_percent < 100 { config.balance_relative_percent = 100 }
    if config.max_affinity_entries <= 0 { config.max_affinity_entries = 1 }
    if config.max_affinity_entries > 1024 { config.max_affinity_entries = 1024 }
    cache_aware_router_state {
        config: config,
        worker_ids: cache_router_int_array(64), worker_pool_ids: cache_router_int_array(64), worker_model_ids: cache_router_int_array(64), worker_loads: cache_router_int_array(64), worker_healthy: cache_router_int_array(64), worker_count: 0,
        affinity_pool_ids: cache_router_int_array(1024), affinity_model_ids: cache_router_int_array(1024), affinity_prefix_hashes: cache_router_int_array(1024), affinity_prefix_tokens: cache_router_int_array(1024), affinity_worker_ids: cache_router_int_array(1024), affinity_last_access: cache_router_int_array(1024), affinity_count: 0,
        logical_clock: 1, affinity_routes: 0, load_routes: 0, cold_routes: 0,
    }
}

func cache_router_find_worker(cache_aware_router_state state, int worker_id) int {
    int i = 0
    while i < state.worker_count {
        if state.worker_ids[i] == worker_id { return i }
        i = i + 1
    }
    0 - 1
}

func cache_router_register_worker(cache_aware_router_state state, int worker_id, int pool_id, int model_id, int load) cache_aware_router_state {
    if worker_id <= 0 || pool_id <= 0 || model_id <= 0 || state.worker_count >= 64 || cache_router_find_worker(state, worker_id) >= 0 { return state }
    int normalized = load
    if normalized < 0 { normalized = 0 }
    int index = state.worker_count
    state.worker_ids[index] = worker_id
    state.worker_pool_ids[index] = pool_id
    state.worker_model_ids[index] = model_id
    state.worker_loads[index] = normalized
    state.worker_healthy[index] = 1
    state.worker_count = state.worker_count + 1
    state
}

func cache_router_set_worker(cache_aware_router_state state, int worker_id, int load, bool healthy) cache_aware_router_state {
    int index = cache_router_find_worker(state, worker_id)
    if index < 0 { return state }
    int normalized = load
    if normalized < 0 { normalized = 0 }
    state.worker_loads[index] = normalized
    if healthy { state.worker_healthy[index] = 1 } else { state.worker_healthy[index] = 0 }
    state
}

func cache_router_worker_matches(cache_aware_router_state state, int index, int pool_id, int model_id) bool {
    index >= 0 && index < state.worker_count && state.worker_healthy[index] == 1 && state.worker_pool_ids[index] == pool_id && state.worker_model_ids[index] == model_id
}

func cache_router_upsert_affinity(cache_aware_router_state state, int pool_id, int model_id, int prefix_hash, int prefix_tokens, int worker_id) cache_aware_router_state {
    state.logical_clock = state.logical_clock + 1
    int i = 0
    while i < state.affinity_count {
        if state.affinity_pool_ids[i] == pool_id && state.affinity_model_ids[i] == model_id && state.affinity_prefix_hashes[i] == prefix_hash {
            state.affinity_prefix_tokens[i] = prefix_tokens
            state.affinity_worker_ids[i] = worker_id
            state.affinity_last_access[i] = state.logical_clock
            return state
        }
        i = i + 1
    }
    int slot = state.affinity_count
    if slot >= state.config.max_affinity_entries {
        slot = 0
        i = 1
        while i < state.affinity_count {
            if state.affinity_last_access[i] < state.affinity_last_access[slot] { slot = i }
            i = i + 1
        }
    } else { state.affinity_count = state.affinity_count + 1 }
    state.affinity_pool_ids[slot] = pool_id
    state.affinity_model_ids[slot] = model_id
    state.affinity_prefix_hashes[slot] = prefix_hash
    state.affinity_prefix_tokens[slot] = prefix_tokens
    state.affinity_worker_ids[slot] = worker_id
    state.affinity_last_access[slot] = state.logical_clock
    state
}

func cache_router_empty_result(cache_aware_router_state state) cache_route_result { cache_route_result {state: state, worker_id: 0, matched_prefix_tokens: 0, strategy: cache_route_none(), routed: false} }

func cache_router_route(cache_aware_router_state state, int pool_id, int model_id, int prefix_hash, int prefix_tokens, int prompt_tokens) cache_route_result {
    int selected = 0 - 1
    int min_load = 2147483647
    int max_load = 0
    int eligible = 0
    int i = 0
    while i < state.worker_count {
        if cache_router_worker_matches(state, i, pool_id, model_id) {
            eligible = eligible + 1
            if state.worker_loads[i] < min_load { min_load = state.worker_loads[i]; selected = i }
            if state.worker_loads[i] > max_load { max_load = state.worker_loads[i] }
        }
        i = i + 1
    }
    if eligible == 0 { return cache_router_empty_result(state) }
    bool imbalanced = max_load - min_load > state.config.balance_absolute_threshold && max_load * 100 > min_load * state.config.balance_relative_percent
    int matched = 0
    int strategy = cache_route_load()
    if !imbalanced && prefix_hash != 0 && prompt_tokens > 0 {
        i = 0
        while i < state.affinity_count {
            int worker_index = cache_router_find_worker(state, state.affinity_worker_ids[i])
            if state.affinity_pool_ids[i] == pool_id && state.affinity_model_ids[i] == model_id && state.affinity_prefix_hashes[i] == prefix_hash && cache_router_worker_matches(state, worker_index, pool_id, model_id) && state.affinity_prefix_tokens[i] * 1000 > prompt_tokens * state.config.cache_threshold_per_mille {
                selected = worker_index
                matched = state.affinity_prefix_tokens[i]
                strategy = cache_route_affinity()
            }
            i = i + 1
        }
    }
    if strategy == cache_route_affinity() { state.affinity_routes = state.affinity_routes + 1 }
    else { state.load_routes = state.load_routes + 1; if state.affinity_count == 0 { state.cold_routes = state.cold_routes + 1 } }
    if selected < 0 { return cache_router_empty_result(state) }
    int worker_id = state.worker_ids[selected]
    state.worker_loads[selected] = state.worker_loads[selected] + 1
    cache_aware_router_state routed_state = cache_router_upsert_affinity(state, pool_id, model_id, prefix_hash, prefix_tokens, worker_id)
    cache_route_result {state: routed_state, worker_id: worker_id, matched_prefix_tokens: matched, strategy: strategy, routed: true}
}

func cache_router_complete(cache_aware_router_state state, int worker_id) cache_aware_router_state {
    int index = cache_router_find_worker(state, worker_id)
    if index >= 0 && state.worker_loads[index] > 0 { state.worker_loads[index] = state.worker_loads[index] - 1 }
    state
}
