package neurx.backends.cpu.transformer_decode
use neurx.models.formats.safetensors_embedding.{safetensors_embedding, embedding_lookup_result, lookup_f32_embedding}
use neurx.models.loaders.hf_transformer.{hf_layer_weights, hf_model_weights}

struct hf_cpu_config {
    int hidden_size
    int intermediate_size
    int attention_heads
    int kv_heads
    int head_dim
    float rms_epsilon
    float rope_theta
}

struct hf_kv_cache {
    []float keys
    []float values
    int length
    int capacity
    int kv_width
}

struct hf_layer_result {
    bool ok
    []float hidden
    hf_kv_cache cache
    string error_code
}

struct hf_generation_result {
    bool ok
    []int token_ids
    string error_code
}

struct cpu_transformer_result {
    bool ok
    int next_token
    int generated_tokens
    float last_logit
    string error_code
}

func cpu_abs(float value) float {
    if value < 0.0 { return -value }
    value
}

func cpu_sqrt(float value) float {
    if value <= 0.0 { return 0.0 }
    float estimate = value
    if estimate < 1.0 { estimate = 1.0 }
    int i = 0
    while i < 12 { estimate = 0.5 * (estimate + value / estimate); i = i + 1 }
    estimate
}

func cpu_exp_positive(float value) float {
    float term = 1.0
    float sum = 1.0
    int i = 1
    while i <= 14 { term = term * value / (i * 1.0); sum = sum + term; i = i + 1 }
    sum
}

func cpu_exp(float value) float {
    float bounded = value
    if bounded > 10.0 { bounded = 10.0 }
    if bounded < -10.0 { bounded = -10.0 }
    if bounded < 0.0 { return 1.0 / cpu_exp_positive(-bounded) }
    cpu_exp_positive(bounded)
}

func cpu_rms_norm([]float input) []float {
    []float output = []float{cap: len(input)}
    float squares = 0.0
    int i = 0
    while i < len(input) { squares = squares + input[i] * input[i]; i = i + 1 }
    float scale = 1.0 / cpu_sqrt(squares / (len(input) * 1.0) + 0.00001)
    i = 0
    while i < len(input) { output[i] = input[i] * scale; i = i + 1 }
    output
}

func hf_rms_norm([]float input, []float weight, float epsilon) []float {
    if len(input) != len(weight) { return []float{} }
    []float output = []float{cap: len(input)}
    float squares = 0.0
    int i = 0
    while i < len(input) { squares = squares + input[i] * input[i]; i = i + 1 }
    float scale = 1.0 / cpu_sqrt(squares / (len(input) * 1.0) + epsilon)
    i = 0
    while i < len(input) { output[i] = input[i] * scale * weight[i]; i = i + 1 }
    output
}

func hf_matvec([]float weight, int rows, int columns, []float input) []float {
    if len(weight) != rows * columns || len(input) != columns { return []float{} }
    []float output = []float{cap: rows}
    int row = 0
    while row < rows {
        float value = 0.0
        int column = 0
        while column < columns { value = value + weight[row * columns + column] * input[column]; column = column + 1 }
        output[row] = value
        row = row + 1
    }
    output
}

func hf_rope([]float input, int heads, int head_dim, int position, float theta) []float {
    []float output = []float{cap: len(input)}
    int i = 0
    while i < len(input) { output[i] = input[i]; i = i + 1 }
    int head = 0
    while head < heads {
        int pair = 0
        while pair + 1 < head_dim {
            float frequency = 1.0
            int power = pair
            while power > 0 { frequency = frequency / cpu_sqrt(theta); power = power - 1 }
            float angle = position * 1.0 * frequency
            float angle2 = angle * angle
            float cosine = 1.0 - angle2 / 2.0 + angle2 * angle2 / 24.0
            float sine = angle - angle * angle2 / 6.0 + angle * angle2 * angle2 / 120.0
            int offset = head * head_dim + pair
            float left = output[offset]
            float right = output[offset + 1]
            output[offset] = left * cosine - right * sine
            output[offset + 1] = left * sine + right * cosine
            pair = pair + 2
        }
        head = head + 1
    }
    output
}

func new_hf_kv_cache(int capacity, int kv_width) hf_kv_cache {
    hf_kv_cache { keys: []float{cap: capacity * kv_width}, values: []float{cap: capacity * kv_width}, length: 0, capacity: capacity, kv_width: kv_width }
}

func hf_silu(float value) float {
    value / (1.0 + cpu_exp(-value))
}

func hf_cpu_layer(hf_cpu_config config, hf_layer_weights weights, []float input, hf_kv_cache cache, int position) hf_layer_result {
    if !weights.valid || len(input) != config.hidden_size || cache.length >= cache.capacity {
        return hf_layer_result { ok: false, hidden: [], cache: cache, error_code: "invalid_hf_layer_input" }
    }
    []float normalized = hf_rms_norm(input, weights.input_norm, config.rms_epsilon)
    []float query = hf_matvec(weights.q_proj, config.attention_heads * config.head_dim, config.hidden_size, normalized)
    []float key = hf_matvec(weights.k_proj, config.kv_heads * config.head_dim, config.hidden_size, normalized)
    []float value = hf_matvec(weights.v_proj, config.kv_heads * config.head_dim, config.hidden_size, normalized)
    if len(query) == 0 || len(key) == 0 || len(value) == 0 { return hf_layer_result { ok: false, hidden: [], cache: cache, error_code: "projection_shape_mismatch" } }
    query = hf_rope(query, config.attention_heads, config.head_dim, position, config.rope_theta)
    key = hf_rope(key, config.kv_heads, config.head_dim, position, config.rope_theta)
    int kv_width = config.kv_heads * config.head_dim
    int i = 0
    while i < kv_width { cache.keys[cache.length * kv_width + i] = key[i]; cache.values[cache.length * kv_width + i] = value[i]; i = i + 1 }
    cache.length = cache.length + 1
    []float attended = []float{cap: config.attention_heads * config.head_dim}
    int group_size = config.attention_heads / config.kv_heads
    int head = 0
    while head < config.attention_heads {
        int kv_head = head / group_size
        []float scores = []float{cap: cache.length}
        float maximum = -1000000.0
        int token = 0
        while token < cache.length {
            float score = 0.0
            int dim = 0
            while dim < config.head_dim {
                score = score + query[head * config.head_dim + dim] * cache.keys[token * kv_width + kv_head * config.head_dim + dim]
                dim = dim + 1
            }
            score = score / cpu_sqrt(config.head_dim * 1.0)
            scores[token] = score
            if score > maximum { maximum = score }
            token = token + 1
        }
        float denominator = 0.0
        token = 0
        while token < cache.length { scores[token] = cpu_exp(scores[token] - maximum); denominator = denominator + scores[token]; token = token + 1 }
        int dim = 0
        while dim < config.head_dim {
            float sum = 0.0
            token = 0
            while token < cache.length { sum = sum + scores[token] / denominator * cache.values[token * kv_width + kv_head * config.head_dim + dim]; token = token + 1 }
            attended[head * config.head_dim + dim] = sum
            dim = dim + 1
        }
        head = head + 1
    }
    []float projected = hf_matvec(weights.o_proj, config.hidden_size, config.attention_heads * config.head_dim, attended)
    []float residual = []float{cap: config.hidden_size}
    i = 0
    while i < config.hidden_size { residual[i] = input[i] + projected[i]; i = i + 1 }
    normalized = hf_rms_norm(residual, weights.post_norm, config.rms_epsilon)
    []float gate = hf_matvec(weights.gate_proj, config.intermediate_size, config.hidden_size, normalized)
    []float up = hf_matvec(weights.up_proj, config.intermediate_size, config.hidden_size, normalized)
    i = 0
    while i < config.intermediate_size { gate[i] = hf_silu(gate[i]) * up[i]; i = i + 1 }
    []float down = hf_matvec(weights.down_proj, config.hidden_size, config.intermediate_size, gate)
    i = 0
    while i < config.hidden_size { residual[i] = residual[i] + down[i]; i = i + 1 }
    hf_layer_result { ok: true, hidden: residual, cache: cache, error_code: "" }
}

func hf_model_cpu_config(hf_model_weights model) hf_cpu_config {
    hf_cpu_config {
        hidden_size: model.config.hidden_size,
        intermediate_size: model.config.intermediate_size,
        attention_heads: model.config.attention_heads,
        kv_heads: model.config.kv_heads,
        head_dim: model.config.head_dim,
        rms_epsilon: model.config.rms_epsilon,
        rope_theta: model.config.rope_theta,
    }
}

func hf_argmax_logits(hf_model_weights model, []float hidden) int {
    []float normalized = hf_rms_norm(hidden, model.final_norm, model.config.rms_epsilon)
    if len(normalized) != model.config.hidden_size || len(model.lm_head) != model.config.vocabulary_size * model.config.hidden_size { return -1 }
    int best_token = 0
    float best_logit = -1000000000.0
    int token = 0
    while token < model.config.vocabulary_size {
        float logit = 0.0
        int column = 0
        while column < model.config.hidden_size {
            logit = logit + model.lm_head[token * model.config.hidden_size + column] * normalized[column]
            column = column + 1
        }
        if token == 0 || logit > best_logit { best_logit = logit; best_token = token }
        token = token + 1
    }
    best_token
}

func hf_forward_token(hf_model_weights model, int token_id, []hf_kv_cache caches, int position) hf_layer_result {
    embedding_lookup_result embedding = lookup_f32_embedding(model.embedding, token_id)
    if !embedding.ok { return hf_layer_result { ok: false, hidden: [], cache: hf_kv_cache {}, error_code: embedding.error_code } }
    []float hidden = embedding.values
    hf_cpu_config config = hf_model_cpu_config(model)
    int layer = 0
    while layer < model.config.layers {
        hf_layer_result result = hf_cpu_layer(config, model.layers[layer], hidden, caches[layer], position)
        if !result.ok { return result }
        hidden = result.hidden
        caches[layer] = result.cache
        layer = layer + 1
    }
    hf_layer_result { ok: true, hidden: hidden, cache: hf_kv_cache {}, error_code: "" }
}

func hf_generate(hf_model_weights model, []int prompt_tokens, int maximum_new_tokens) hf_generation_result {
    if !model.valid || len(prompt_tokens) == 0 || maximum_new_tokens <= 0 { return hf_generation_result { ok: false, token_ids: [], error_code: "invalid_generation_input" } }
    int capacity = len(prompt_tokens) + maximum_new_tokens
    []hf_kv_cache caches = []hf_kv_cache{cap: model.config.layers}
    int layer = 0
    while layer < model.config.layers { caches[layer] = new_hf_kv_cache(capacity, model.config.kv_heads * model.config.head_dim); layer = layer + 1 }
    hf_layer_result state = hf_layer_result { ok: false, hidden: [], cache: hf_kv_cache {}, error_code: "empty_prefill" }
    int position = 0
    while position < len(prompt_tokens) {
        state = hf_forward_token(model, prompt_tokens[position], caches, position)
        if !state.ok { return hf_generation_result { ok: false, token_ids: [], error_code: state.error_code } }
        position = position + 1
    }
    []int generated = []int{cap: maximum_new_tokens}
    int step = 0
    while step < maximum_new_tokens {
        int next_token = hf_argmax_logits(model, state.hidden)
        if next_token < 0 { return hf_generation_result { ok: false, token_ids: [], error_code: "invalid_lm_head_shape" } }
        generated[step] = next_token
        step = step + 1
        if step < maximum_new_tokens {
            state = hf_forward_token(model, next_token, caches, position)
            if !state.ok { return hf_generation_result { ok: false, token_ids: [], error_code: state.error_code } }
            position = position + 1
        }
    }
    hf_generation_result { ok: true, token_ids: generated, error_code: "" }
}

func cpu_reference_mlp([]float input) []float {
    int width = len(input)
    []float up = []float{cap: width}
    []float output = []float{cap: width}
    int row = 0
    while row < width {
        float value = 0.0
        int column = 0
        while column < width {
            float weight = 0.125
            if row == column { weight = 1.0 }
            value = value + input[column] * weight
            column = column + 1
        }
        if value < 0.0 { value = 0.0 }
        up[row] = value
        row = row + 1
    }
    row = 0
    while row < width {
        float value = 0.0
        int column = 0
        while column < width {
            float weight = 0.0625
            if row == column { weight = 0.5 }
            value = value + up[column] * weight
            column = column + 1
        }
        output[row] = value
        row = row + 1
    }
    output
}

func cpu_prefill_hidden(safetensors_embedding embedding, []int token_ids, int token_count) []float {
    int width = embedding.columns
    []float queries = []float{cap: token_count * width}
    int token = 0
    while token < token_count {
        embedding_lookup_result row = lookup_f32_embedding(embedding, token_ids[token])
        if !row.ok { return []float{} }
        []float normalized = cpu_rms_norm(row.values)
        int column = 0
        while column < width { queries[token * width + column] = normalized[column]; column = column + 1 }
        token = token + 1
    }

    []float scores = []float{cap: token_count}
    float maximum = -1000000.0
    token = 0
    while token < token_count {
        float score = 0.0
        int column = 0
        while column < width {
            score = score + queries[(token_count - 1) * width + column] * queries[token * width + column]
            column = column + 1
        }
        score = score / cpu_sqrt(width * 1.0)
        scores[token] = score
        if score > maximum { maximum = score }
        token = token + 1
    }

    float denominator = 0.0
    token = 0
    while token < token_count { scores[token] = cpu_exp(scores[token] - maximum); denominator = denominator + scores[token]; token = token + 1 }
    []float attention = []float{cap: width}
    int column = 0
    while column < width {
        float value = 0.0
        token = 0
        while token < token_count { value = value + scores[token] / denominator * queries[token * width + column]; token = token + 1 }
        attention[column] = value
        column = column + 1
    }

    embedding_lookup_result residual_row = lookup_f32_embedding(embedding, token_ids[token_count - 1])
    []float residual = []float{cap: width}
    column = 0
    while column < width { residual[column] = residual_row.values[column] + attention[column]; column = column + 1 }
    []float mlp = cpu_reference_mlp(cpu_rms_norm(residual))
    column = 0
    while column < width { residual[column] = residual[column] + mlp[column]; column = column + 1 }
    cpu_rms_norm(residual)
}

func cpu_sample_logits(safetensors_embedding embedding, []float hidden) cpu_transformer_result {
    int best_token = 0
    float best_logit = -1000000.0
    int token = 0
    while token < embedding.rows {
        embedding_lookup_result row = lookup_f32_embedding(embedding, token)
        if !row.ok { return cpu_transformer_result { ok: false, next_token: -1, generated_tokens: 0, last_logit: 0.0, error_code: row.error_code } }
        float logit = 0.0
        int column = 0
        while column < embedding.columns { logit = logit + hidden[column] * row.values[column]; column = column + 1 }
        if token == 0 || logit > best_logit { best_token = token; best_logit = logit }
        token = token + 1
    }
    cpu_transformer_result { ok: true, next_token: best_token, generated_tokens: 1, last_logit: best_logit, error_code: "" }
}

func cpu_transformer_prefill_decode(safetensors_embedding embedding, []int prompt_tokens, int decode_steps) cpu_transformer_result {
    if !embedding.valid { return cpu_transformer_result { ok: false, next_token: -1, generated_tokens: 0, last_logit: 0.0, error_code: embedding.error_code } }
    if len(prompt_tokens) == 0 { return cpu_transformer_result { ok: false, next_token: -1, generated_tokens: 0, last_logit: 0.0, error_code: "empty_tokens" } }
    int steps = decode_steps
    if steps <= 0 { return cpu_transformer_result { ok: false, next_token: -1, generated_tokens: 0, last_logit: 0.0, error_code: "invalid_decode_steps" } }
    if steps > 8 { steps = 8 }
    []int context = []int{cap: len(prompt_tokens) + steps}
    int i = 0
    while i < len(prompt_tokens) { context[i] = prompt_tokens[i]; i = i + 1 }
    int count = len(prompt_tokens)
    cpu_transformer_result result = cpu_transformer_result { ok: false, next_token: -1, generated_tokens: 0, last_logit: 0.0, error_code: "decode_not_started" }
    int step = 0
    while step < steps {
        []float hidden = cpu_prefill_hidden(embedding, context, count)
        if len(hidden) != embedding.columns { return cpu_transformer_result { ok: false, next_token: -1, generated_tokens: step, last_logit: 0.0, error_code: "prefill_failed" } }
        result = cpu_sample_logits(embedding, hidden)
        if !result.ok { return result }
        context[count] = result.next_token
        count = count + 1
        step = step + 1
    }
    result.generated_tokens = steps
    result
}
