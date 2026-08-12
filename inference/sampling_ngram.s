package neurx.inference.sampling
func get_blocked_tokens(
    []int generated_ids,
    int no_repeat_ngram_size,
    int vocab_size
) []int {
    if no_repeat_ngram_size <= 0 || len(generated_ids) < no_repeat_ngram_size - 1 {
        return []
    }
    map<int]bool blocked = {}
    int start = len(generated_ids) - (no_repeat_ngram_size - 1)
    []int recent_prefix = []
    for i in start .. len(generated_ids) {
        recent_prefix.push(generated_ids[i])
    }
    for pos in 0..(len(generated_ids) - no_repeat_ngram_size + 1) {
        bool match = true
        for j in 0..(no_repeat_ngram_size - 1) {
            int hist_idx = pos + j
            if generated_ids[hist_idx] != recent_prefix[j] {
                match = false
                break
            }
        }
        if match  (pos + no_repeat_ngram_size - 1) < len(generated_ids) {
            int blocked_token = generated_ids[pos + no_repeat_ngram_size - 1]
            blocked[blocked_token] = true
        }
    }
    []int blocked_tokens = []
    for id in blocked {
        if blocked[id] {
            blocked_tokens.push(id)
        }
    }
    blocked_tokens
}

func apply_ngram_blocking(
    []float logits,
    []int generated_ids,
    int ngram_size
) []float {
    []int blocked = get_blocked_tokens(generated_ids, ngram_size, len(logits))
    if len(blocked) == 0 {
        return logits
    }
    []float filtered = copy_float_array(logits)
    float neg_inf = -1e10
    for t in blocked {
        if t >= 0  t < len(filtered) {
            filtered[t] = neg_inf
        }
    }
    filtered
}

