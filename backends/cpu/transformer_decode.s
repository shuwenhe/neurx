package neurx.backends.cpu.transformer_decode
use neurx.models.formats.safetensors_embedding.{safetensors_embedding, embedding_lookup_result, lookup_f32_embedding}

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
