package neurx.serving.speculative_decoding

// ============================================================================
// Speculative Decoding — English text
//
// English text: "Fast Inference from Transformers via Speculative Decoding"
//        (Leviathan et al., 2023)
//        "SpecInfer: Accelerating LLM Serving..." (Miao et al., 2023)
//
// English text:
//   English textmodel (draft model, ~7B) quickgenerate γ English text token English text,
//   English textmodel (target model, ~70B) English text, English text token.
//   English textgenerateEnglish text, English text 2-3×, English textoutputEnglish textmodelEnglish text.
//
// English text (English text):
//   1. English textmodelEnglish textgenerate γ English text token: x_{t+1},...,x_{t+γ}
//   2. English textmodelEnglish textcompute q(x|prefix+drafts)
//   3. English text token xᵢ:
//      English text α_i = min(1, q(xᵢ|ctx) / p(xᵢ|ctx))
//      English text αᵢ English text, English text (q - p)₊ English text token English text
//   4. English text, English textmodelEnglish text γ+1 English text token
//
// English text:
//   • English text (Self-speculative): English textmodel
//   • Medusa: English text
//   • EAGLE: English text
// ============================================================================

// ============================================================================
// 1. configuration
// ============================================================================

struct spec_decode_config {
    int gamma              // English textstepEnglish text (English text 3-8)
    float acceptance_threshold  // English text (0.0 = English text, >0 = English text)
    int vocab_size         // English text
    bool use_top_p         // English text nucleus English text
    float top_p            // nucleus English textparameter
    float temperature      // English text
    int max_seq_len        // English text
    string draft_type      // "separate" | "self" | "medusa"
    int medusa_heads       // Medusa English text (draft_type="medusa")
    int self_skip_layers   // English text
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

// ============================================================================
// 2. English text
// ============================================================================

// softmax (English text)
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

// English text softmax
func spec_softmax_temp([]float logits, int V, float temp) []float {
    []float scaled = []
    int i = 0
    for i < V {
        scaled = append(scaled, logits[i] / temp)
        i = i + 1
    }
    spec_softmax(scaled, V)
}

// nucleus (top-p) English text
func spec_top_p_sample([]float probs, int V, float top_p, int seed) int {
    // English text top-p English text
    // English text: English text token (seed English text)
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

// English text: English text max(0, q - p) / Z English text
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

    // English text diff / sum English text
    if sum < 1e-10 {
        // English text argmax(q)
        return spec_top_p_sample(q, V, 1.0, seed)
    }

    // English text (English text: English text sum/2 English text)
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

// ============================================================================
// 3. English text
// ============================================================================

struct spec_draft_output {
    []int   token_ids      // [gamma] English text token
    []float log_probs      // [gamma] English text log p(xᵢ|ctx)
    [][]float all_probs    // [gamma][vocab] English textcompleteEnglish text
}

struct spec_verify_result {
    []int accepted_tokens  // English text token English text (English text target token)
    int   num_accepted      // English text token
    float acceptance_rate  // English text num_accepted / gamma
    bool  all_accepted      // English text
}

// English text/English textstep
func spec_accept_reject(
    float q_prob,   // English textmodel q(xᵢ|ctx)
    float p_prob,   // English textmodel p(xᵢ|ctx)
    int   token_id,
    float alpha_threshold,
    int   seed
) bool {
    if p_prob < 1e-10 {
        // English text, English text (q/p English text)
        return true
    }
    float ratio = q_prob / p_prob
    if ratio >= 1.0 {
        return true
    }
    // English text ratio English text
    // English text seed English text: English text
    float rand_val = pseudo_rand(seed)
    rand_val < ratio
}

// English textstep (English text)
func spec_verify(
    spec_draft_output draft,     // English textmodeloutput
    [][]float target_probs,      // English textmodelEnglish text gamma English text [gamma][V]
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
            // English text token
            int fix_tok = spec_residual_sample(target_probs[i], draft.all_probs[i], V, i)
            accepted = append(accepted, fix_tok)
            all_ok = false
            // English text
            i = gamma  // break
        }
        i = i + 1
    }

    // English text, English textmodelEnglish text gamma+1 English text token
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

// ============================================================================
// 4. English textstate
// ============================================================================

struct spec_decode_state {
    spec_decode_config cfg
    []int  token_buffer      // English textgenerateEnglish text
    int    seq_len           // English text
    int    total_tokens_gen  // English textgenerate token English text
    int    total_draft_calls // English textmodelEnglish text
    int    total_verify_calls// English textmodelEnglish text
    float  avg_acceptance    // English text
    int    step              // English textstepEnglish text
    int    seed_state        // English textstate
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
    []int new_tokens          // English textstepEnglish text token
    int   tokens_added        // English text token English text
    float step_acceptance_rate
    bool  done                // English text EOS
}

// English textstepEnglish text
// (English textactualsystemEnglish text, draft_fn English text target_fn English texttruthfulmodel)
func spec_decode_step(
    spec_decode_state state,
    spec_draft_output draft,     // English text: English textmodeloutput
    [][]float target_probs,      // English text: English textmodelEnglish text gamma+1 English text
    int eos_token_id
) spec_decode_step_result {
    spec_verify_result vr = spec_verify(draft, target_probs, state.cfg.vocab_size, state.cfg)

    spec_decode_state updated = state
    updated.step = state.step + 1
    updated.total_draft_calls  = state.total_draft_calls + 1
    updated.total_verify_calls = state.total_verify_calls + 1
    updated.total_tokens_gen   = state.total_tokens_gen + len(vr.accepted_tokens)

    // English text
    float old_avg = state.avg_acceptance
    float new_acc = vr.acceptance_rate
    updated.avg_acceptance = (old_avg * float_spec(state.step) + new_acc) / float_spec(state.step + 1)

    // English text token English text
    bool done = false
    []int new_toks = []
    int i = 0
    for i < len(vr.accepted_tokens) {
        int tok = vr.accepted_tokens[i]
        if tok == eos_token_id {
            done = true
            i = len(vr.accepted_tokens)  // break
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

// ============================================================================
// 5. Medusa — English text
// ============================================================================

struct medusa_config {
    int num_heads       // English text (English text t+1, t+2, ...t+k)
    int hidden_dim      // backbone hidden dim
    int vocab_size
    float temperature
    float posterior_threshold  // English text (English text 0.09)
    float posterior_alpha      // English text α (English text 0.3)
}

// Medusa head (English text)
struct medusa_head {
    []float weight      // [vocab_size, hidden_dim]
    []float bias        // [vocab_size]
    int head_idx        // English text t+head_idx+1
}

func new_medusa_head(int hidden_dim, int vocab_size, int head_idx) medusa_head {
    medusa_head {
        weight: zeros_spec(vocab_size * hidden_dim),
        bias: zeros_spec(vocab_size),
        head_idx: head_idx,
    }
}

// Medusa English text: hidden [hidden_dim] → logits [vocab_size]
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
    [][]float head_logits    // [num_heads][vocab_size] English text logit
    []int     candidates     // English textsearchEnglish text token English text
    int       tree_depth     // actualEnglish text
}

func medusa_forward([]medusa_head heads, []float last_hidden, int H, int V) medusa_output {
    [][]float all_logits = []
    []int candidates = []

    int h = 0
    for h < len(heads) {
        []float logits = medusa_head_forward(heads[h], last_hidden, H, V)
        all_logits = append(all_logits, logits)
        // Greedy candidate for this head
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

// ============================================================================
// 6. English textstatistics
// ============================================================================

struct spec_perf_stats {
    float speedup_ratio        // English text
    float avg_acceptance_rate  // English text token English text
    int total_tokens
    int total_target_calls     // English textmodelEnglish text
    float tokens_per_call      // English textmodelEnglish text token English text
}

func compute_spec_perf(spec_decode_state state) spec_perf_stats {
    int calls = state.total_verify_calls
    if calls == 0 { calls = 1 }
    float tpc = float_spec(state.total_tokens_gen) / float_spec(calls)

    // English text ≈ (gamma+1) * alpha / (1 + alpha*(gamma-1))  English text
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

// ============================================================================
// 7. toolfunction
// ============================================================================

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
