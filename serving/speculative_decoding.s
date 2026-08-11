package neurx.serving.speculative_decoding
struct spec_decode_config {
    int gamma
    float acceptance_threshold
    int vocab_size
    bool use_top_p
    float top_p
    float temperature
    int max_seq_len
    string draft_type
    int medusa_heads
    int self_skip_layers
}

func default_spec_decode_config(int vocab_size) spec_decode_config {
    spec_decode_config {
        gamma: 5,
        acceptance_threshold: 0.0,
        vocab_size: vocab_size,
        use_top_p: true,
        top_p: 0.95,
        temperature: 0.8,
        max_seq_len: 4096,
        draft_type: "separate",
        medusa_heads: 4,
        self_skip_layers: 16,
    }
}

func spec_softmax([]float logits, int V) []float {
    float m = logits[0]
    int i = 0
    for i < V {
        if logits[i] > m { m = logits[i] }
        i = i + 1
    }
    []float probs = []
    float sum = 0.0
    int j = 0
    for j < V {
        float e = spec_exp(logits[j] - m)
        probs = append(probs, e)
        sum = sum + e
        j = j + 1
    }
    if sum < 1e-10 { sum = 1.0 }
    int k = 0
    for k < V {
        probs[k] = probs[k] / sum
        k = k + 1
    }
    probs
}

func spec_softmax_temp([]float logits, int V, float temp) []float {
    []float scaled = []
    int i = 0
    for i < V {
        scaled = append(scaled, logits[i] / temp)
        i = i + 1
    }
    spec_softmax(scaled, V)
}

func spec_top_p_sample([]float probs, int V, float top_p, int seed) int {
    int best = 0
    float best_p = probs[0]
    int i = 1
    for i < V {
        if probs[i] > best_p {
            best_p = probs[i]
            best = i
        }
        i = i + 1
    }
    best
}

func spec_residual_sample([]float q, []float p, int V, int seed) int {
    []float diff = []
    float sum = 0.0
    int i = 0
    for i < V {
        float d = q[i] - p[i]
        if d < 0.0 { d = 0.0 }
        diff = append(diff, d)
        sum = sum + d
        i = i + 1
    }
    if sum < 1e-10 {
        return spec_top_p_sample(q, V, 1.0, seed)
    }
    float threshold = sum * 0.5
    float cumsum = 0.0
    int j = 0
    for j < V {
        cumsum = cumsum + diff[j]
        if cumsum >= threshold {
            return j
        }
        j = j + 1
    }
    V - 1
}

struct spec_draft_output {
    []int   token_ids
    []float log_probs
    [][]float all_probs
}

struct spec_verify_result {
    []int accepted_tokens
    int   num_accepted
    float acceptance_rate
    bool  all_accepted
}

func spec_accept_reject(
    float q_prob,
    float p_prob,
    int   token_id,
    float alpha_threshold,
    int   seed
) bool {
    if p_prob < 1e-10 {
        return true
    }
    float ratio = q_prob / p_prob
    if ratio >= 1.0 {
        return true
    }
    float rand_val = pseudo_rand(seed)
    rand_val < ratio
}

func spec_verify(
    spec_draft_output draft,
    [][]float target_probs,
    int V,
    spec_decode_config cfg
) spec_verify_result {
    int gamma = cfg.gamma
    []int accepted = []
    int num_acc = 0
    bool all_ok = true
    int i = 0
    for i < gamma {
        int tok = draft.token_ids[i]
        float p_tok = draft.all_probs[i][tok]
        float q_tok = target_probs[i][tok]
        bool ok = spec_accept_reject(q_tok, p_tok, tok, cfg.acceptance_threshold, i * 12345)
        if ok {
            accepted = append(accepted, tok)
            num_acc = num_acc + 1
        } else {
            int fix_tok = spec_residual_sample(target_probs[i], draft.all_probs[i], V, i)
            accepted = append(accepted, fix_tok)
            all_ok = false
            i = gamma
        }
        i = i + 1
    }
    if all_ok && len(target_probs) > gamma {
        int bonus_tok = spec_top_p_sample(target_probs[gamma], V, cfg.top_p, 99999)
        accepted = append(accepted, bonus_tok)
    }
    float acc_rate = 0.0
    if gamma > 0 {
        acc_rate = float_spec(num_acc) / float_spec(gamma)
    }
    spec_verify_result {
        accepted_tokens: accepted,
        num_accepted: num_acc,
        acceptance_rate: acc_rate,
        all_accepted: all_ok,
    }
}

struct spec_decode_state {
    spec_decode_config cfg
    []int  token_buffer
    int    seq_len
    int    total_tokens_gen
    int    total_draft_calls
    int    total_verify_calls
    float  avg_acceptance
    int    step
    int    seed_state
}

func new_spec_decode_state([]int prompt_ids, spec_decode_config cfg) spec_decode_state {
    spec_decode_state {
        cfg: cfg,
        token_buffer: prompt_ids,
        seq_len: len(prompt_ids),
        total_tokens_gen: 0,
        total_draft_calls: 0,
        total_verify_calls: 0,
        avg_acceptance: 0.0,
        step: 0,
        seed_state: 42,
    }
}

struct spec_decode_step_result {
    spec_decode_state state
    []int new_tokens
    int   tokens_added
    float step_acceptance_rate
    bool  done
}

func spec_decode_step(
    spec_decode_state state,
    spec_draft_output draft,
    [][]float target_probs,
    int eos_token_id
) spec_decode_step_result {
    spec_verify_result vr = spec_verify(draft, target_probs, state.cfg.vocab_size, state.cfg)
    spec_decode_state updated = state
    updated.step = state.step + 1
    updated.total_draft_calls  = state.total_draft_calls + 1
    updated.total_verify_calls = state.total_verify_calls + 1
    updated.total_tokens_gen   = state.total_tokens_gen + len(vr.accepted_tokens)
    float old_avg = state.avg_acceptance
    float new_acc = vr.acceptance_rate
    updated.avg_acceptance = (old_avg * float_spec(state.step) + new_acc) / float_spec(state.step + 1)
    bool done = false
    []int new_toks = []
    int i = 0
    for i < len(vr.accepted_tokens) {
        int tok = vr.accepted_tokens[i]
        if tok == eos_token_id {
            done = true
            i = len(vr.accepted_tokens)
            continue
        }
        updated.token_buffer = append(updated.token_buffer, tok)
        updated.seq_len = updated.seq_len + 1
        new_toks = append(new_toks, tok)
        i = i + 1
    }
    spec_decode_step_result {
        state: updated,
        new_tokens: new_toks,
        tokens_added: len(new_toks),
        step_acceptance_rate: new_acc,
        done: done,
    }
}

struct medusa_config {
    int num_heads
    int hidden_dim
    int vocab_size
    float temperature
    float posterior_threshold
    float posterior_alpha
}

struct medusa_head {
    []float weight
    []float bias
    int head_idx
}

func new_medusa_head(int hidden_dim, int vocab_size, int head_idx) medusa_head {
    medusa_head {
        weight: zeros_spec(vocab_size * hidden_dim),
        bias: zeros_spec(vocab_size),
        head_idx: head_idx,
    }
}

func medusa_head_forward(medusa_head head, []float hidden, int H, int V) []float {
    []float logits = zeros_spec(V)
    int j = 0
    for j < V {
        float s = head.bias[j]
        int k = 0
        for k < H {
            s = s + head.weight[j*H+k] * hidden[k]
            k = k + 1
        }
        logits[j] = s
        j = j + 1
    }
    logits
}

struct medusa_output {
    [][]float head_logits
    []int     candidates
    int       tree_depth
}

func medusa_forward([]medusa_head heads, []float last_hidden, int H, int V) medusa_output {
    [][]float all_logits = []
    []int candidates = []
    int h = 0
    for h < len(heads) {
        []float logits = medusa_head_forward(heads[h], last_hidden, H, V)
        all_logits = append(all_logits, logits)
        int best = argmax_spec(logits, V)
        candidates = append(candidates, best)
        h = h + 1
    }
    medusa_output {
        head_logits: all_logits,
        candidates: candidates,
        tree_depth: len(heads),
    }
}

struct spec_perf_stats {
    float speedup_ratio
    float avg_acceptance_rate
    int total_tokens
    int total_target_calls
    float tokens_per_call
}

func compute_spec_perf(spec_decode_state state) spec_perf_stats {
    int calls = state.total_verify_calls
    if calls == 0 { calls = 1 }
    float tpc = float_spec(state.total_tokens_gen) / float_spec(calls)
    float alpha = state.avg_acceptance
    int gamma = state.cfg.gamma
    float gamma_f = float_spec(gamma)
    float num = (gamma_f + 1.0) * alpha
    float den = 1.0 + alpha * (gamma_f - 1.0)
    float speedup = num
    if den > 0.01 { speedup = num / den }
    spec_perf_stats {
        speedup_ratio: speedup,
        avg_acceptance_rate: state.avg_acceptance,
        total_tokens: state.total_tokens_gen,
        total_target_calls: calls,
        tokens_per_call: tpc,
    }
}

func zeros_spec(int n) []float {
    []float out = []
    int i = 0
    for i < n {
        out = append(out, 0.0)
        i = i + 1
    }
    out
}

func float_spec(int n) float {
    float v = 0.0
    int i = 0
    for i < n {
        v = v + 1.0
        i = i + 1
    }
    v
}

func spec_exp(float x) float {
    if x > 20.0  { return 485165195.4 }
    if x < -20.0 { return 0.0 }
    float x2 = x * x
    float x3 = x2 * x
    float x4 = x3 * x
    1.0 + x + x2/2.0 + x3/6.0 + x4/24.0
}

func pseudo_rand(int seed) float {
    int s = (seed * 1664525 + 1013904223) % 2147483647
    if s < 0 { s = 0 - s }
    float_spec(s % 10000) / 10000.0
}

func argmax_spec([]float arr, int n) int {
    int best = 0
    float best_v = arr[0]
    int i = 1
    for i < n {
        if arr[i] > best_v {
            best_v = arr[i]
            best = i
        }
        i = i + 1
    }
    best
}
