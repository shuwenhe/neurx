package neurx.inference.cache.block_manager
struct kv_cache_block {
    int block_id
    int ref_count
    string block_hash
    int token_count
    int last_access_tick
    bool cached
    bool pending_free
    int generation
}

struct request_block_table {
    string request_id
    []int block_ids
    int token_count
    int computed_tokens
    int preemptions
}

struct block_manager_state {
    int block_size
    int total_blocks
    int watermark_blocks
    []kv_cache_block blocks
    []int free_block_ids
    []int deferred_free_ids
    []request_block_table tables
    int tick
    int cache_hits
    int cache_misses
    int evictions
    int allocation_failures
}

struct block_allocation_result {
    block_manager_state state
    request_block_table table
    []int new_block_ids
    bool success
    string error_message
}

struct prefix_match_result {
    block_manager_state state
    request_block_table table
    int matched_tokens
    int matched_blocks
    bool success
}

struct block_reset_result {
    block_manager_state state
    bool success
}

func empty_request_block_table() request_block_table {
    request_block_table table
    table.request_id = ""
    table.block_ids = []
    table.token_count = 0
    table.computed_tokens = 0
    table.preemptions = 0
    table
}

func new_block_allocation_result(block_manager_state state, request_block_table table, []int new_block_ids, bool success, string error_message) block_allocation_result {
    block_allocation_result result
    result.state = state
    result.table = table
    result.new_block_ids = new_block_ids
    result.success = success
    result.error_message = error_message
    result
}

func new_prefix_match_result(block_manager_state state, request_block_table table, int matched_tokens, int matched_blocks, bool success) prefix_match_result {
    prefix_match_result result
    result.state = state
    result.table = table
    result.matched_tokens = matched_tokens
    result.matched_blocks = matched_blocks
    result.success = success
    result
}

func new_block_manager(int total_blocks, int block_size, int watermark_blocks) block_manager_state {
    int normalized_total = total_blocks
    if normalized_total <= 0 {
        normalized_total = 1
    }
    int normalized_size = block_size
    if normalized_size <= 0 {
        normalized_size = 16
    }
    int normalized_watermark = watermark_blocks
    if normalized_watermark < 0 {
        normalized_watermark = 0
    }
    if normalized_watermark >= normalized_total {
        normalized_watermark = normalized_total - 1
    }
    block_manager_state state
    state.block_size = normalized_size
    state.total_blocks = normalized_total
    state.watermark_blocks = normalized_watermark
    state.blocks = make([]kv_cache_block, normalized_total)
    state.free_block_ids = make([]int, normalized_total)
    state.deferred_free_ids = []
    state.tables = []
    state.tick = 0
    state.cache_hits = 0
    state.cache_misses = 0
    state.evictions = 0
    state.allocation_failures = 0
    int i = 0
    for i < normalized_total {
        kv_cache_block block
        block.block_id = i
        block.ref_count = 0
        block.block_hash = ""
        block.token_count = 0
        block.last_access_tick = 0
        block.cached = false
        block.pending_free = false
        block.generation = 0
        state.blocks = append(state.blocks, block)
        state.free_block_ids = append(state.free_block_ids, i)
        i = i + 1
    }
    state
}

func block_manager_block_at(block_manager_state state, int index) kv_cache_block {
    state.blocks[index]
}

func block_manager_table_at(block_manager_state state, int index) request_block_table {
    state.tables[index]
}

func block_manager_find_table(block_manager_state state, string request_id) int {
    int i = 0
    for i < len(state.tables) {
        request_block_table table = block_manager_table_at(state, i)
        if table.request_id == request_id {
            return i
        }
        i = i + 1
    }
    -1
}

func block_manager_get_table(block_manager_state state, string request_id) request_block_table {
    int index = block_manager_find_table(state, request_id)
    if index < 0 {
        request_block_table table = empty_request_block_table()
        table.request_id = request_id
        return table
    }
    block_manager_table_at(state, index)
}

func block_manager_get_allocation_table(block_manager_state state, string request_id) request_block_table {
    int index = block_manager_find_table(state, request_id)
    if index < 0 {
        request_block_table new_table = empty_request_block_table()
        new_table.request_id = request_id
        return new_table
    }
    block_manager_table_at(state, index)
}

func block_manager_upsert_table(block_manager_state state, request_block_table table) block_manager_state {
    int index = block_manager_find_table(state, table.request_id)
    if index < 0 {
        state.tables = append(state.tables, table)
    } else {
        state.tables[index] = table
    }
    state
}

func block_manager_remove_int([]int values, int expected) []int {
    []int result = make([]int, len(values))
    int i = 0
    for i < len(values) {
        if values[i] != expected {
            result = append(result, values[i])
        }
        i = i + 1
    }
    result
}

func block_manager_contains_int([]int values, int expected) bool {
    int i = 0
    for i < len(values) {
        if values[i] == expected {
            return true
        }
        i = i + 1
    }
    false
}

func block_manager_prepend_int([]int values, int value) []int {
    []int result = make([]int, len(values) + 1)
    result = append(result, value)
    int i = 0
    for i < len(values) {
        if values[i] != value {
            result = append(result, values[i])
        }
        i = i + 1
    }
    result
}

func block_manager_append_unique([]int values, int value) []int {
    if block_manager_contains_int(values, value) {
        return values
    }
    append(values, value)
}

func block_manager_remove_table(block_manager_state state, int remove_index) block_manager_state {
    []request_block_table tables = make([]request_block_table, len(state.tables))
    int i = 0
    for i < len(state.tables) {
        if i != remove_index {
            tables = append(tables, block_manager_table_at(state, i))
        }
        i = i + 1
    }
    state.tables = tables
    state
}

func block_manager_find_cached(block_manager_state state, string block_hash) int {
    if block_hash == "" {
        return -1
    }
    int i = 0
    for i < len(state.blocks) {
        kv_cache_block block = block_manager_block_at(state, i)
        if block.cached && block.block_hash == block_hash {
            return i
        }
        i = i + 1
    }
    -1
}

func block_manager_touch(block_manager_state state, int block_id) block_manager_state {
    if block_id < 0 || block_id >= len(state.blocks) {
        return state
    }
    kv_cache_block block = block_manager_block_at(state, block_id)
    if block.ref_count == 0 {
        state.free_block_ids = block_manager_remove_int(state.free_block_ids, block_id)
    }
    block.ref_count = block.ref_count + 1
    state.tick = state.tick + 1
    block.last_access_tick = state.tick
    block.pending_free = false
    state.blocks[block_id] = block
    state
}

func block_manager_mod(int value, int divisor) int {
    if divisor <= 0 {
        return 0
    }
    value - (value / divisor) * divisor
}

func block_manager_hash_tokens([]int token_ids, int start, int token_count, string parent_hash, string adapter_key, string multimodal_key) string {
    int hash_value = 216613
    int i = 0
    for i < len(parent_hash) {
        hash_value = block_manager_mod(hash_value * 131 + int(parent_hash[i]), 1000000007)
        i = i + 1
    }
    i = start
    int end = start + token_count
    if end > len(token_ids) {
        end = len(token_ids)
    }
    for i < end {
        int token = token_ids[i]
        if token < 0 {
            token = 0 - token
        }
        hash_value = block_manager_mod(hash_value * 131 + token + 97, 1000000007)
        i = i + 1
    }
    i = 0
    for i < len(adapter_key) {
        hash_value = block_manager_mod(hash_value * 131 + int(adapter_key[i]), 1000000007)
        i = i + 1
    }
    i = 0
    for i < len(multimodal_key) {
        hash_value = block_manager_mod(hash_value * 131 + int(multimodal_key[i]), 1000000007)
        i = i + 1
    }
    int_to_str(hash_value) + ":" + int_to_str(token_count)
}

func block_manager_match_prefix(block_manager_state state, string request_id, []string block_hashes) prefix_match_result {
    request_block_table table = block_manager_get_table(state, request_id)
    if len(table.block_ids) > 0 {
        return new_prefix_match_result(state, table, table.computed_tokens, len(table.block_ids), true)
    }
    int i = 0
    for i < len(block_hashes) {
        string block_hash = block_hashes[i]
        int block_id = block_manager_find_cached(state, block_hash)
        if block_id < 0 {
            state.cache_misses = state.cache_misses + 1
            break
        }
        state = block_manager_touch(state, block_id)
        table.block_ids = append(table.block_ids, block_id)
        table.token_count = table.token_count + state.block_size
        table.computed_tokens = table.computed_tokens + state.block_size
        state.cache_hits = state.cache_hits + 1
        i = i + 1
    }
    state = block_manager_upsert_table(state, table)
    new_prefix_match_result(state, table, table.computed_tokens, i, true)
}

func block_manager_required_blocks(block_manager_state state, request_block_table table, int new_tokens, int lookahead_tokens) int {
    int tokens = new_tokens + lookahead_tokens
    if tokens < 0 {
        tokens = 0
    }
    int target_tokens = table.token_count + tokens
    int target_blocks = (target_tokens + state.block_size - 1) / state.block_size
    int required = target_blocks - len(table.block_ids)
    if required < 0 {
        return 0
    }
    required
}

func block_manager_can_allocate(block_manager_state state, request_block_table table, int new_tokens, int lookahead_tokens, bool apply_watermark) bool {
    int required = block_manager_required_blocks(state, table, new_tokens, lookahead_tokens)
    int reserve = 0
    if apply_watermark {
        reserve = state.watermark_blocks
    }
    len(state.free_block_ids) >= required + reserve
}

func block_manager_pop_free(block_manager_state state) block_allocation_result {
    []int allocated = []
    request_block_table table = empty_request_block_table()
    if len(state.free_block_ids) == 0 {
        state.allocation_failures = state.allocation_failures + 1
        return new_block_allocation_result(state, table, allocated, false, "no free KV blocks")
    }
    int block_id = state.free_block_ids[0]
    state.free_block_ids = block_manager_remove_int(state.free_block_ids, block_id)
    kv_cache_block block = block_manager_block_at(state, block_id)
    if block.cached {
        block.cached = false
        block.block_hash = ""
        block.token_count = 0
        state.evictions = state.evictions + 1
    }
    block.ref_count = 1
    block.pending_free = false
    block.generation = block.generation + 1
    state.tick = state.tick + 1
    block.last_access_tick = state.tick
    state.blocks[block_id] = block
    allocated = append(allocated, block_id)
    new_block_allocation_result(state, table, allocated, true, "")
}

func block_manager_release_block(block_manager_state state, int block_id) block_manager_state {
    if block_id < 0 || block_id >= len(state.blocks) {
        return state
    }
    kv_cache_block block = block_manager_block_at(state, block_id)
    if block.ref_count <= 0 {
        return state
    }
    block.ref_count = block.ref_count - 1
    if block.ref_count == 0 {
        block.pending_free = false
        if block.cached {
            state.free_block_ids = block_manager_append_unique(state.free_block_ids, block_id)
        } else {
            state.free_block_ids = block_manager_prepend_int(state.free_block_ids, block_id)
        }
    }
    state.blocks[block_id] = block
    state
}

func block_manager_allocate(block_manager_state state, string request_id, int new_tokens, int lookahead_tokens, bool apply_watermark) block_allocation_result {
    []int allocation_ids = []
    request_block_table allocation_table = block_manager_get_allocation_table(state, request_id)
    int required = block_manager_required_blocks(state, allocation_table, new_tokens, lookahead_tokens)
    if !block_manager_can_allocate(state, allocation_table, new_tokens, lookahead_tokens, apply_watermark) {
        state.allocation_failures = state.allocation_failures + 1
        return new_block_allocation_result(state, allocation_table, allocation_ids, false, "KV block watermark or capacity limit")
    }
    int i = 0
    for i < required {
        block_allocation_result one = block_manager_pop_free(state)
        state = one.state
        if !one.success {
            int rollback = 0
            for rollback < len(allocation_ids) {
                state = block_manager_release_block(state, allocation_ids[rollback])
                rollback = rollback + 1
            }
            return new_block_allocation_result(state, allocation_table, [], false, one.error_message)
        }
        int block_id = one.new_block_ids[0]
        allocation_ids = append(allocation_ids, block_id)
        allocation_table.block_ids = append(allocation_table.block_ids, block_id)
        i = i + 1
    }
    int add_tokens = new_tokens
    if add_tokens < 0 {
        add_tokens = 0
    }
    allocation_table.token_count = allocation_table.token_count + add_tokens
    state = block_manager_upsert_table(state, allocation_table)
    new_block_allocation_result(state, allocation_table, allocation_ids, true, "")
}

func block_manager_cache_full_blocks(block_manager_state state, string request_id, []string block_hashes) block_manager_state {
    int table_index = block_manager_find_table(state, request_id)
    if table_index < 0 {
        return state
    }
    request_block_table table = block_manager_table_at(state, table_index)
    int full_blocks = table.computed_tokens / state.block_size
    if full_blocks > len(table.block_ids) {
        full_blocks = len(table.block_ids)
    }
    if full_blocks > len(block_hashes) {
        full_blocks = len(block_hashes)
    }
    int i = 0
    for i < full_blocks {
        int block_id = table.block_ids[i]
        string block_hash = block_hashes[i]
        int existing = block_manager_find_cached(state, block_hash)
        if existing < 0 || existing == block_id {
            kv_cache_block block = block_manager_block_at(state, block_id)
            block.block_hash = block_hash
            block.cached = block_hash != ""
            block.token_count = state.block_size
            state.blocks[block_id] = block
        }
        i = i + 1
    }
    state
}

func block_manager_mark_computed(block_manager_state state, string request_id, int computed_tokens) block_manager_state {
    int table_index = block_manager_find_table(state, request_id)
    if table_index < 0 {
        return state
    }
    request_block_table table = block_manager_table_at(state, table_index)
    int add_tokens = computed_tokens
    if add_tokens < 0 {
        add_tokens = 0
    }
    table.computed_tokens = table.computed_tokens + add_tokens
    if table.computed_tokens > table.token_count {
        table.computed_tokens = table.token_count
    }
    state.tables[table_index] = table
    state
}

func block_manager_free_request(block_manager_state state, string request_id, bool defer_free) block_manager_state {
    int table_index = block_manager_find_table(state, request_id)
    if table_index < 0 {
        return state
    }
    request_block_table table = block_manager_table_at(state, table_index)
    int i = len(table.block_ids) - 1
    for i >= 0 {
        int block_id = table.block_ids[i]
        if defer_free {
            kv_cache_block block = block_manager_block_at(state, block_id)
            block.pending_free = true
            state.blocks[block_id] = block
            state.deferred_free_ids = block_manager_append_unique(state.deferred_free_ids, block_id)
        } else {
            state = block_manager_release_block(state, block_id)
        }
        i = i - 1
    }
    block_manager_remove_table(state, table_index)
}

func block_manager_flush_deferred(block_manager_state state) block_manager_state {
    []int pending = state.deferred_free_ids
    state.deferred_free_ids = []
    int i = 0
    for i < len(pending) {
        state = block_manager_release_block(state, pending[i])
        i = i + 1
    }
    state
}

func block_manager_preempt_request(block_manager_state state, string request_id) block_manager_state {
    int table_index = block_manager_find_table(state, request_id)
    if table_index < 0 {
        return state
    }
    request_block_table table = block_manager_table_at(state, table_index)
    table.preemptions = table.preemptions + 1
    int i = len(table.block_ids) - 1
    for i >= 0 {
        state = block_manager_release_block(state, table.block_ids[i])
        i = i - 1
    }
    table.block_ids = []
    table.token_count = 0
    table.computed_tokens = 0
    state.tables[table_index] = table
    state
}

func block_manager_reset_prefix_cache(block_manager_state state) block_reset_result {
    int i = 0
    for i < len(state.blocks) {
        kv_cache_block block = block_manager_block_at(state, i)
        if block.ref_count > 0 {
            block_reset_result blocked
            blocked.state = state
            blocked.success = false
            return blocked
        }
        i = i + 1
    }
    state.free_block_ids = []
    i = 0
    for i < len(state.blocks) {
        kv_cache_block block = block_manager_block_at(state, i)
        block.cached = false
        block.block_hash = ""
        block.token_count = 0
        block.pending_free = false
        state.blocks[i] = block
        state.free_block_ids = append(state.free_block_ids, i)
        i = i + 1
    }
    state.deferred_free_ids = []
    block_reset_result result
    result.state = state
    result.success = true
    result
}

func block_manager_num_free(block_manager_state state) int {
    len(state.free_block_ids)
}

func block_manager_usage(block_manager_state state) float {
    if state.total_blocks <= 0 {
        return 0.0
    }
    float(state.total_blocks - len(state.free_block_ids)) / float(state.total_blocks)
}
