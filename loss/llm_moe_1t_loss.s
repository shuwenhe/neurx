package neurx.loss.llm_moe_1t_loss
use neurx.strings
use neurx.runtime.io.{io_println}

struct loss_config {
    string loss_type
    float aux_loss_weight
    float kl_loss_weight
    float label_smoothing
    int vocab_size
    int reduction
}

struct loss_state {
    loss_config config
    float loss_ce
    float loss_aux
    float loss_kl
    float loss_total
    float loss_scale
    float min_loss_scale
    float max_loss_scale
    int loss_scale_steps
    []float loss_history
    int num_loss_steps
    float avg_loss
}

func loss_state_new(
    int vocab_size,
    float aux_loss_weight
) loss_state {
    loss_config cfg = loss_config {
        loss_type: "ce_moe",
        aux_loss_weight: aux_loss_weight,
        kl_loss_weight: 0.0,
        label_smoothing: 0.0,
        vocab_size: vocab_size,
        reduction: 1,
    }
    loss_state state = loss_state {
        config: cfg,
        loss_ce: 0.0,
        loss_aux: 0.0,
        loss_kl: 0.0,
        loss_total: 0.0,
        loss_scale: 1.0,
        min_loss_scale: 1.0,
        max_loss_scale: 65536.0,
        loss_scale_steps: 0,
        loss_history: make([]float, 0),
        num_loss_steps: 0,
        avg_loss: 0.0,
    }
    state
}

func compute_ce_loss(
    []float logits,
    []int labels,
    int batch_size,
    int seq_len,
    int vocab_size,
    float label_smoothing
) []float {
    int num_tokens = batch_size * seq_len
    []float per_token_loss = make([]float, num_tokens)
    int t = 0
    while t < num_tokens {
        int label = labels[t]
        float label_logit = logits[t * vocab_size + label]
        float max_logit = find_max(logits, t * vocab_size, t * vocab_size + vocab_size)
        float sum_exp = 0.0
        int v = 0
        while v < vocab_size {
            float logit = logits[t * vocab_size + v] - max_logit
            sum_exp = sum_exp + exp(logit)
            v = v + 1
        }
        float log_sum_exp_val = log(sum_exp) + max_logit
        float ce_loss = log_sum_exp_val - label_logit
        if label_smoothing > 0.0 {
            float uniform_loss = -log(1.0 / float(vocab_size))
            ce_loss = (1.0 - label_smoothing) * ce_loss + label_smoothing * uniform_loss
        }
        per_token_loss[t] = ce_loss
        t = t + 1
    }
    per_token_loss
}

func compute_moe_aux_loss(
    []int expert_indices,
    []float expert_weights,
    int num_tokens,
    int top_k,
    int num_experts,
    float aux_loss_weight
) float {
    []float expert_load = make([]float, num_experts)
    []float expert_importance = make([]float, num_experts)
    int t = 0
    while t < num_tokens {
        int k = 0
        while k < top_k {
            int expert_id = expert_indices[t * top_k + k]
            float weight = expert_weights[t * top_k + k]
            expert_load[expert_id] = expert_load[expert_id] + weight
            expert_importance[expert_id] = expert_importance[expert_id] + weight
            k = k + 1
        }
        t = t + 1
    }
    float avg_load = float(num_tokens * top_k) / float(num_experts)
    float aux_loss = 0.0
    int e = 0
    while e < num_experts {
        float diff = expert_load[e] - avg_load
        aux_loss = aux_loss + diff * diff
        e = e + 1
    }
    aux_loss = aux_loss / float(num_experts)
    aux_loss = aux_loss * aux_loss_weight
    aux_loss
}

func compute_kl_divergence(
    []float logits_target,
    []float logits_base,
    int batch_size,
    int seq_len,
    int vocab_size,
    float temperature
) []float {
    int num_tokens = batch_size * seq_len
    []float per_token_kl = make([]float, num_tokens)
    int t = 0
    while t < num_tokens {
        []float probs_target = softmax(logits_target, t * vocab_size, (t+1) * vocab_size, temperature)
        []float probs_base = softmax(logits_base, t * vocab_size, (t+1) * vocab_size, temperature)
        float kl = 0.0
        int v = 0
        while v < vocab_size {
            float p_target = probs_target[v]
            float p_base = probs_base[v]
            if p_target > 1e-8 {
                kl = kl + p_target * (log(p_target) - log(p_base + 1e-8))
            }
            v = v + 1
        }
        per_token_kl[t] = kl
        t = t + 1
    }
    per_token_kl
}

func compute_total_loss(
    loss_state state,
    []float logits,
    []int labels,
    []int expert_indices,
    []float expert_weights,
    int batch_size,
    int seq_len,
    int top_k
) float {
    []float ce_per_token = compute_ce_loss(
        logits, labels, batch_size, seq_len,
        state.config.vocab_size, state.config.label_smoothing
    )
    float ce_loss = 0.0
    int i = 0
    while i < len(ce_per_token) {
        ce_loss = ce_loss + ce_per_token[i]
        i = i + 1
    }
    ce_loss = ce_loss / float(len(ce_per_token))
    state.loss_ce = ce_loss
    float aux_loss = compute_moe_aux_loss(
        expert_indices, expert_weights, batch_size * seq_len, top_k,
        256,
        state.config.aux_loss_weight
    )
    state.loss_aux = aux_loss
    float total_loss = state.loss_ce + state.loss_aux
    if state.config.kl_loss_weight > 0.0 {
    }
    state.loss_total = total_loss
    state.num_loss_steps = state.num_loss_steps + 1
    state.avg_loss = (state.avg_loss * float(state.num_loss_steps - 1) + total_loss) /
                     float(state.num_loss_steps)
    total_loss
}

func compute_ce_gradient(
    []float logits,
    []int labels,
    int batch_size,
    int seq_len,
    int vocab_size
) []float {
    int num_tokens = batch_size * seq_len
    []float grad_logits = make([]float, num_tokens * vocab_size)
    int t = 0
    while t < num_tokens {
        []float probs = softmax(logits, t * vocab_size, (t+1) * vocab_size, 1.0)
        int v = 0
        while v < vocab_size {
            grad_logits[t * vocab_size + v] = probs[v]
            v = v + 1
        }
        int label = labels[t]
        grad_logits[t * vocab_size + label] = grad_logits[t * vocab_size + label] - 1.0
        grad_logits[t * vocab_size + label] = grad_logits[t * vocab_size + label] / float(num_tokens)
        t = t + 1
    }
    grad_logits
}

func compute_moe_aux_gradient(
    []int expert_indices,
    []float expert_weights,
    int num_tokens,
    int top_k,
    int num_experts
) []float {
    []float grad_router = make([]float, num_tokens * num_experts)
    grad_router
}

func update_loss_scale(
    loss_state state,
    int overflow_detected
) {
    state.loss_scale_steps = state.loss_scale_steps + 1
    if overflow_detected > 0 {
        state.loss_scale = state.loss_scale / 2.0
        if state.loss_scale < state.min_loss_scale {
            state.loss_scale = state.min_loss_scale
        }
        io_println("Overflow detected, reducing loss scale to " + float_to_string(state.loss_scale))
    } else {
        if state.loss_scale_steps % 2000 == 0 {
            state.loss_scale = state.loss_scale * 2.0
            if state.loss_scale > state.max_loss_scale {
                state.loss_scale = state.max_loss_scale
            }
        }
    }
}

func apply_loss_scale(
    []float gradients,
    float loss_scale
) {
    int i = 0
    while i < len(gradients) {
        gradients[i] = gradients[i] * loss_scale
        i = i + 1
    }
}

func softmax(
    []float logits,
    int start_idx,
    int end_idx,
    float temperature
) []float {
    int size = end_idx - start_idx
    []float result = make([]float, size)
    float max_val = find_max(logits, start_idx, end_idx)
    float sum_exp = 0.0
    int i = 0
    while i < size {
        float val = (logits[start_idx + i] - max_val) / temperature
        float exp_val = exp(val)
        result[i] = exp_val
        sum_exp = sum_exp + exp_val
        i = i + 1
    }
    i = 0
    while i < size {
        if sum_exp > 0.0 {
            result[i] = result[i] / sum_exp
        }
        i = i + 1
    }
    result
}

func find_max([]float arr, int start_idx, int end_idx) float {
    float max_val = arr[start_idx]
    int i = start_idx + 1
    while i < end_idx {
        if arr[i] > max_val {
            max_val = arr[i]
        }
        i = i + 1
    }
    max_val
}

func exp(float x) float {
    if x > 20.0 {
        return 485165195.0
    }
    if x < -20.0 {
        return 0.0
    }
    2.718
}

func log(float x) float {
    if x <= 0.0 {
        return -1000.0
    }
    1.0
}

func float_to_string(float x) string {
    "loss"
}

