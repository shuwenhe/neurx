package neurx.serving.runtime.production_runtime

struct production_queue {
    string[] request_ids
    string[] backends
    string[] dtypes
    int[] prompt_remaining
    int[] max_new_tokens
    int[] generated_tokens
}

func new_production_queue() production_queue {
    production_queue {
        request_ids: [],
        backends: [],
        dtypes: [],
        prompt_remaining: [],
        max_new_tokens: [],
        generated_tokens: [],
    }
}

func production_queue_size(production_queue queue) int {
    len(queue.request_ids)
}

func production_queue_contains(production_queue queue, string request_id) bool {
    int i = 0
    for i < production_queue_size(queue) {
        if queue.request_ids[i] == request_id { return true }
        i = i + 1
    }
    false
}

func production_normalize_backend(string backend) string {
    if backend == "cuda" { return "cuda" }
    if backend == "ascend" { return "ascend" }
    "cpu"
}

func production_normalize_dtype(string backend, string dtype) string {
    if dtype == "fp8" && backend == "cuda" { return "fp8" }
    if dtype == "bf16" && backend != "cpu" { return "bf16" }
    if dtype == "fp16" && backend == "cuda" { return "fp16" }
    "fp32"
}

func production_queue_push(production_queue queue, string request_id, string backend, string dtype, int prompt_remaining, int max_new_tokens, int generated_tokens) production_queue {
    int old_size = production_queue_size(queue)
    string[] ids = string[]{cap: old_size + 1}
    string[] next_backends = string[]{cap: old_size + 1}
    string[] next_dtypes = string[]{cap: old_size + 1}
    int[] prompts = int[]{cap: old_size + 1}
    int[] limits = int[]{cap: old_size + 1}
    int[] generated = int[]{cap: old_size + 1}
    int i = 0
    for i < old_size {
        ids[i] = queue.request_ids[i]
        next_backends[i] = queue.backends[i]
        next_dtypes[i] = queue.dtypes[i]
        prompts[i] = queue.prompt_remaining[i]
        limits[i] = queue.max_new_tokens[i]
        generated[i] = queue.generated_tokens[i]
        i = i + 1
    }
    int normalized_prompt = prompt_remaining
    if normalized_prompt < 0 { normalized_prompt = 0 }
    int normalized_limit = max_new_tokens
    if normalized_limit <= 0 { normalized_limit = 1 }
    string normalized_backend = production_normalize_backend(backend)
    ids[old_size] = request_id
    next_backends[old_size] = normalized_backend
    next_dtypes[old_size] = production_normalize_dtype(normalized_backend, dtype)
    prompts[old_size] = normalized_prompt
    limits[old_size] = normalized_limit
    generated[old_size] = generated_tokens
    production_queue {
        request_ids: ids,
        backends: next_backends,
        dtypes: next_dtypes,
        prompt_remaining: prompts,
        max_new_tokens: limits,
        generated_tokens: generated,
    }
}

struct production_runtime_config {
    int max_active_requests
    int max_queue_tokens
    int max_kv_tokens
    int max_prefill_batch_tokens
    int max_prefill_requests
    int max_decode_batch_size
}

func new_production_runtime_config(int max_active_requests, int max_queue_tokens, int max_kv_tokens, int max_prefill_batch_tokens, int max_prefill_requests, int max_decode_batch_size) production_runtime_config {
    if max_active_requests <= 0 { max_active_requests = 1 }
    if max_queue_tokens <= 0 { max_queue_tokens = 1 }
    if max_kv_tokens <= 0 { max_kv_tokens = 1 }
    if max_prefill_batch_tokens <= 0 { max_prefill_batch_tokens = 1 }
    if max_prefill_requests <= 0 { max_prefill_requests = 1 }
    if max_decode_batch_size <= 0 { max_decode_batch_size = 1 }
    production_runtime_config {
        max_active_requests: max_active_requests,
        max_queue_tokens: max_queue_tokens,
        max_kv_tokens: max_kv_tokens,
        max_prefill_batch_tokens: max_prefill_batch_tokens,
        max_prefill_requests: max_prefill_requests,
        max_decode_batch_size: max_decode_batch_size,
    }
}

struct production_runtime_state {
    production_runtime_config config
    production_queue prefill_queue
    production_queue decode_queue
    int queued_tokens
    int kv_tokens
    int in_flight_requests
    string[] in_flight_ids
    int admitted_requests
    int rejected_requests
    int completed_requests
    int failed_batches
    int prefill_tokens
    int decode_tokens
    int prefix_cache_hits
    int prefix_cache_misses
    int kv_handoffs
}

func new_production_runtime_state(production_runtime_config config) production_runtime_state {
    production_runtime_state {
        config: config,
        prefill_queue: new_production_queue(),
        decode_queue: new_production_queue(),
        queued_tokens: 0,
        kv_tokens: 0,
        in_flight_requests: 0,
        in_flight_ids: [],
        admitted_requests: 0,
        rejected_requests: 0,
        completed_requests: 0,
        failed_batches: 0,
        prefill_tokens: 0,
        decode_tokens: 0,
        prefix_cache_hits: 0,
        prefix_cache_misses: 0,
        kv_handoffs: 0,
    }
}

func production_string_contains(string[] values, string value) bool {
    int i = 0
    for i < len(values) {
        if values[i] == value { return true }
        i = i + 1
    }
    false
}

func production_string_push(string[] values, string value) string[] {
    string[] result = string[]{cap: len(values) + 1}
    int i = 0
    for i < len(values) {
        result[i] = values[i]
        i = i + 1
    }
    result[len(values)] = value
    result
}

func production_remove_in_flight(string[] values, string[] completed) string[] {
    int keep = 0
    int i = 0
    for i < len(values) {
        if !production_string_contains(completed, values[i]) { keep = keep + 1 }
        i = i + 1
    }
    string[] result = string[]{cap: keep}
    i = 0
    int j = 0
    for i < len(values) {
        if !production_string_contains(completed, values[i]) {
            result[j] = values[i]
            j = j + 1
        }
        i = i + 1
    }
    result
}

func production_active_requests(production_runtime_state state) int {
    production_queue_size(state.prefill_queue) + production_queue_size(state.decode_queue) + state.in_flight_requests
}

func production_submit(production_runtime_state state, string request_id, string backend, string dtype, int prompt_tokens, int cached_prefix_tokens, int max_new_tokens) production_runtime_state {
    int prompt = prompt_tokens
    if prompt < 0 { prompt = 0 }
    int cached = cached_prefix_tokens
    if cached < 0 { cached = 0 }
    if cached > prompt { cached = prompt }
    int remaining = prompt - cached
    bool accepted = request_id != "" && max_new_tokens > 0
    if production_queue_contains(state.prefill_queue, request_id) || production_queue_contains(state.decode_queue, request_id) || production_string_contains(state.in_flight_ids, request_id) { accepted = false }
    if production_active_requests(state) >= state.config.max_active_requests { accepted = false }
    int future_tokens = remaining + max_new_tokens
    if state.queued_tokens + future_tokens > state.config.max_queue_tokens { accepted = false }
    if state.kv_tokens + state.queued_tokens + cached + future_tokens > state.config.max_kv_tokens { accepted = false }
    if !accepted {
        state.rejected_requests = state.rejected_requests + 1
        return state
    }
    if remaining > 0 {
        state.prefill_queue = production_queue_push(state.prefill_queue, request_id, backend, dtype, remaining, max_new_tokens, 0)
        state.prefix_cache_misses = state.prefix_cache_misses + 1
    } else {
        state.decode_queue = production_queue_push(state.decode_queue, request_id, backend, dtype, 0, max_new_tokens, 0)
        state.prefix_cache_hits = state.prefix_cache_hits + 1
        state.kv_handoffs = state.kv_handoffs + 1
    }
    state.queued_tokens = state.queued_tokens + future_tokens
    state.kv_tokens = state.kv_tokens + cached
    state.admitted_requests = state.admitted_requests + 1
    state
}

struct production_batch {
    string phase
    string backend
    string dtype
    string[] request_ids
    int[] token_counts
    int[] prompt_remaining
    int[] max_new_tokens
    int[] generated_tokens
    int total_tokens
    bool ok
}

struct production_schedule_result {
    production_runtime_state state
    production_batch batch
}

func empty_production_batch() production_batch {
    production_batch {
        phase: "none",
        backend: "cpu",
        dtype: "fp32",
        request_ids: [],
        token_counts: [],
        prompt_remaining: [],
        max_new_tokens: [],
        generated_tokens: [],
        total_tokens: 0,
        ok: false,
    }
}

func production_queue_without_selected(production_queue queue, bool[] selected) production_queue {
    int i = 0
    production_queue result = new_production_queue()
    for i < production_queue_size(queue) {
        if !selected[i] {
            result = production_queue_push(result, queue.request_ids[i], queue.backends[i], queue.dtypes[i], queue.prompt_remaining[i], queue.max_new_tokens[i], queue.generated_tokens[i])
        }
        i = i + 1
    }
    result
}

func production_schedule_decode(production_runtime_state state) production_schedule_result {
    production_queue queue = state.decode_queue
    int size = production_queue_size(queue)
    if size <= 0 { return production_schedule_result { state: state, batch: empty_production_batch() } }
    string backend = queue.backends[0]
    string dtype = queue.dtypes[0]
    bool[] selected = bool[]{cap: size}
    string[] ids = string[]{cap: state.config.max_decode_batch_size}
    int[] counts = int[]{cap: state.config.max_decode_batch_size}
    int[] prompts = int[]{cap: state.config.max_decode_batch_size}
    int[] limits = int[]{cap: state.config.max_decode_batch_size}
    int[] generated = int[]{cap: state.config.max_decode_batch_size}
    int chosen = 0
    int i = 0
    for i < size && chosen < state.config.max_decode_batch_size {
        selected[i] = false
        if queue.backends[i] == backend && queue.dtypes[i] == dtype {
            selected[i] = true
            ids[chosen] = queue.request_ids[i]
            counts[chosen] = 1
            prompts[chosen] = 0
            limits[chosen] = queue.max_new_tokens[i]
            generated[chosen] = queue.generated_tokens[i]
            chosen = chosen + 1
        }
        i = i + 1
    }
    state.decode_queue = production_queue_without_selected(queue, selected)
    state.in_flight_requests = state.in_flight_requests + chosen
    string[] compact_ids = string[]{cap: chosen}
    int[] compact_counts = int[]{cap: chosen}
    int[] compact_prompts = int[]{cap: chosen}
    int[] compact_limits = int[]{cap: chosen}
    int[] compact_generated = int[]{cap: chosen}
    i = 0
    for i < chosen {
        compact_ids[i] = ids[i]
        compact_counts[i] = counts[i]
        compact_prompts[i] = prompts[i]
        compact_limits[i] = limits[i]
        compact_generated[i] = generated[i]
        state.in_flight_ids = production_string_push(state.in_flight_ids, compact_ids[i])
        i = i + 1
    }
    production_schedule_result {
        state: state,
        batch: production_batch {
            phase: "decode",
            backend: backend,
            dtype: dtype,
            request_ids: compact_ids,
            token_counts: compact_counts,
            prompt_remaining: compact_prompts,
            max_new_tokens: compact_limits,
            generated_tokens: compact_generated,
            total_tokens: chosen,
            ok: chosen > 0,
        },
    }
}

func production_schedule_prefill(production_runtime_state state) production_schedule_result {
    production_queue queue = state.prefill_queue
    int size = production_queue_size(queue)
    if size <= 0 { return production_schedule_result { state: state, batch: empty_production_batch() } }
    string backend = queue.backends[0]
    string dtype = queue.dtypes[0]
    bool[] selected = bool[]{cap: size}
    string[] ids = string[]{cap: state.config.max_prefill_requests}
    int[] counts = int[]{cap: state.config.max_prefill_requests}
    int[] prompts = int[]{cap: state.config.max_prefill_requests}
    int[] limits = int[]{cap: state.config.max_prefill_requests}
    int[] generated = int[]{cap: state.config.max_prefill_requests}
    int chosen = 0
    int total = 0
    int i = 0
    for i < size && chosen < state.config.max_prefill_requests && total < state.config.max_prefill_batch_tokens {
        selected[i] = false
        if queue.backends[i] == backend && queue.dtypes[i] == dtype {
            int budget = state.config.max_prefill_batch_tokens - total
            int chunk = queue.prompt_remaining[i]
            if chunk > budget { chunk = budget }
            if chunk > 0 {
                selected[i] = true
                ids[chosen] = queue.request_ids[i]
                counts[chosen] = chunk
                prompts[chosen] = queue.prompt_remaining[i]
                limits[chosen] = queue.max_new_tokens[i]
                generated[chosen] = queue.generated_tokens[i]
                total = total + chunk
                chosen = chosen + 1
            }
        }
        i = i + 1
    }
    state.prefill_queue = production_queue_without_selected(queue, selected)
    state.in_flight_requests = state.in_flight_requests + chosen
    string[] compact_ids = string[]{cap: chosen}
    int[] compact_counts = int[]{cap: chosen}
    int[] compact_prompts = int[]{cap: chosen}
    int[] compact_limits = int[]{cap: chosen}
    int[] compact_generated = int[]{cap: chosen}
    i = 0
    for i < chosen {
        compact_ids[i] = ids[i]
        compact_counts[i] = counts[i]
        compact_prompts[i] = prompts[i]
        compact_limits[i] = limits[i]
        compact_generated[i] = generated[i]
        state.in_flight_ids = production_string_push(state.in_flight_ids, compact_ids[i])
        i = i + 1
    }
    production_schedule_result {
        state: state,
        batch: production_batch {
            phase: "prefill",
            backend: backend,
            dtype: dtype,
            request_ids: compact_ids,
            token_counts: compact_counts,
            prompt_remaining: compact_prompts,
            max_new_tokens: compact_limits,
            generated_tokens: compact_generated,
            total_tokens: total,
            ok: chosen > 0,
        },
    }
}

func production_schedule(production_runtime_state state) production_schedule_result {
    if production_queue_size(state.decode_queue) > 0 {
        return production_schedule_decode(state)
    }
    return production_schedule_prefill(state)
}

func production_complete_prefill(production_runtime_state state, production_batch batch, bool succeeded) production_runtime_state {
    int batch_tokens = 0
    int k = 0
    for k < len(batch.token_counts) {
        batch_tokens = batch_tokens + batch.token_counts[k]
        k = k + 1
    }
    bool commit = succeeded && state.kv_tokens + batch_tokens <= state.config.max_kv_tokens
    int i = 0
    for i < len(batch.request_ids) {
        int original = batch.prompt_remaining[i]
        int processed = batch.token_counts[i]
        int remaining = original
        if commit { remaining = original - processed }
        if remaining < 0 { remaining = 0 }
        if commit {
            state.queued_tokens = state.queued_tokens - processed
            if state.queued_tokens < 0 { state.queued_tokens = 0 }
            state.kv_tokens = state.kv_tokens + processed
            state.prefill_tokens = state.prefill_tokens + processed
        }
        if commit && remaining == 0 {
            state.decode_queue = production_queue_push(state.decode_queue, batch.request_ids[i], batch.backend, batch.dtype, 0, batch.max_new_tokens[i], batch.generated_tokens[i])
            state.kv_handoffs = state.kv_handoffs + 1
        } else {
            state.prefill_queue = production_queue_push(state.prefill_queue, batch.request_ids[i], batch.backend, batch.dtype, remaining, batch.max_new_tokens[i], batch.generated_tokens[i])
        }
        i = i + 1
    }
    state.in_flight_requests = state.in_flight_requests - len(batch.request_ids)
    if state.in_flight_requests < 0 { state.in_flight_requests = 0 }
    state.in_flight_ids = production_remove_in_flight(state.in_flight_ids, batch.request_ids)
    if !commit { state.failed_batches = state.failed_batches + 1 }
    state
}

func production_complete_decode(production_runtime_state state, production_batch batch, bool[] eos, bool succeeded) production_runtime_state {
    bool commit = succeeded && state.kv_tokens + len(batch.request_ids) <= state.config.max_kv_tokens
    int i = 0
    for i < len(batch.request_ids) {
        int generated = batch.generated_tokens[i]
        bool finished = false
        if commit {
            generated = generated + 1
            state.decode_tokens = state.decode_tokens + 1
            state.queued_tokens = state.queued_tokens - 1
            if state.queued_tokens < 0 { state.queued_tokens = 0 }
            state.kv_tokens = state.kv_tokens + 1
            if i < len(eos) && eos[i] { finished = true }
            if generated >= batch.max_new_tokens[i] { finished = true }
        }
        if commit && finished {
            int unused_generation = batch.max_new_tokens[i] - generated
            if unused_generation > 0 {
                state.queued_tokens = state.queued_tokens - unused_generation
                if state.queued_tokens < 0 { state.queued_tokens = 0 }
            }
            state.completed_requests = state.completed_requests + 1
        } else {
            state.decode_queue = production_queue_push(state.decode_queue, batch.request_ids[i], batch.backend, batch.dtype, 0, batch.max_new_tokens[i], generated)
        }
        i = i + 1
    }
    state.in_flight_requests = state.in_flight_requests - len(batch.request_ids)
    if state.in_flight_requests < 0 { state.in_flight_requests = 0 }
    state.in_flight_ids = production_remove_in_flight(state.in_flight_ids, batch.request_ids)
    if !commit { state.failed_batches = state.failed_batches + 1 }
    state
}

func production_release_kv(production_runtime_state state, int tokens) production_runtime_state {
    int release = tokens
    if release < 0 { release = 0 }
    state.kv_tokens = state.kv_tokens - release
    if state.kv_tokens < 0 { state.kv_tokens = 0 }
    state
}
