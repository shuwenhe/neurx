package neurx.inference.scheduler.two_batch_overlap
func tbo_mode_extend() int { 1 }

func tbo_mode_decode() int { 2 }

func tbo_mode_target_verify() int { 3 }

func tbo_mode_idle() int { 4 }

struct tbo_config {
    int token_distribution_threshold_per_mille
    int minimum_tokens
    int decode_delta_stages
}

struct tbo_plan {
    bool enabled
    bool two_chunk_split
    int split_seq_index
    int split_token_index
    int child_a_sequences
    int child_b_sequences
    int child_a_tokens
    int child_b_tokens
    int delta_stages
}

struct tbo_stage_schedule {
    []int child_a_stages
    []int child_b_stages
    int tick_count
    bool valid
}

func tbo_int_array(int capacity, int value) []int {
    []int values = make([]int, capacity)
    int i = 0
    for i < capacity { values[i] = value; i = i + 1 }
    values
}

func tbo_empty_plan() tbo_plan {
    tbo_plan {enabled: false, two_chunk_split: false, split_seq_index: 0, split_token_index: 0, child_a_sequences: 0, child_b_sequences: 0, child_a_tokens: 0, child_b_tokens: 0, delta_stages: 0}
}

func tbo_sum([]int values) int {
    int total = 0
    int i = 0
    for i < len(values) {
        if values[i] > 0 { total = total + values[i] }
        i = i + 1
    }
    total
}

func tbo_balanced_boundary([]int lengths) int {
    int count = len(lengths)
    if count < 2 { return 0 }
    int total = tbo_sum(lengths)
    int left = 0
    int best = 1
    int best_diff = 2147483647
    int i = 1
    for i < count {
        if lengths[i - 1] > 0 { left = left + lengths[i - 1] }
        int diff = total - left - left
        if diff < 0 { diff = 0 - diff }
        if diff < best_diff { best_diff = diff; best = i }
        i = i + 1
    }
    best
}

func tbo_prefix_sum([]int values, int end) int {
    int total = 0
    int i = 0
    for i < end && i < len(values) {
        if values[i] > 0 { total = total + values[i] }
        i = i + 1
    }
    total
}

func tbo_split_extend(tbo_config config, []int extend_lengths) tbo_plan {
    int count = len(extend_lengths)
    int total = tbo_sum(extend_lengths)
    if count < 2 || total < config.minimum_tokens { return tbo_empty_plan() }
    int boundary = tbo_balanced_boundary(extend_lengths)
    int token_boundary = tbo_prefix_sum(extend_lengths, boundary)
    bool imbalanced = token_boundary * 1000 < total * config.token_distribution_threshold_per_mille || token_boundary * 1000 > total * (1000 - config.token_distribution_threshold_per_mille)
    bool two_chunk = false
    int child_a_sequences = boundary
    int child_b_sequences = count - boundary
    if imbalanced {
        int half = total / 2
        int cumulative = 0
        int split_sequence = 0
        for split_sequence < count && cumulative + extend_lengths[split_sequence] < half {
            cumulative = cumulative + extend_lengths[split_sequence]
            split_sequence = split_sequence + 1
        }
        int proposed_a_sequences = split_sequence + 1
        int proposed_b_sequences = count - split_sequence
        if half >= proposed_a_sequences && total - half >= proposed_b_sequences {
            two_chunk = true
            boundary = split_sequence
            token_boundary = half
            child_a_sequences = proposed_a_sequences
            child_b_sequences = proposed_b_sequences
        }
    }
    tbo_plan {enabled: true, two_chunk_split: two_chunk, split_seq_index: boundary, split_token_index: token_boundary, child_a_sequences: child_a_sequences, child_b_sequences: child_b_sequences, child_a_tokens: token_boundary, child_b_tokens: total - token_boundary, delta_stages: 0}
}

func tbo_make_plan(tbo_config config, int mode, []int extend_lengths, int sequence_count, int tokens_per_sequence) tbo_plan {
    if config.token_distribution_threshold_per_mille < 0 { config.token_distribution_threshold_per_mille = 0 }
    if config.token_distribution_threshold_per_mille > 500 { config.token_distribution_threshold_per_mille = 500 }
    if config.minimum_tokens < 0 { config.minimum_tokens = 0 }
    if config.decode_delta_stages < 0 { config.decode_delta_stages = 0 }
    if mode == tbo_mode_extend() { return tbo_split_extend(config, extend_lengths) }
    if mode == tbo_mode_decode() || mode == tbo_mode_target_verify() {
        if sequence_count < 2 || tokens_per_sequence <= 0 { return tbo_empty_plan() }
        int child_a = sequence_count / 2
        int child_b = sequence_count - child_a
        int split_tokens = child_a * tokens_per_sequence
        return tbo_plan {enabled: true, two_chunk_split: false, split_seq_index: child_a, split_token_index: split_tokens, child_a_sequences: child_a, child_b_sequences: child_b, child_a_tokens: split_tokens, child_b_tokens: child_b * tokens_per_sequence, delta_stages: config.decode_delta_stages}
    }
    tbo_empty_plan()
}

func tbo_schedule_stages(int stages_a, int stages_b, int delta_stages) tbo_stage_schedule {
    if stages_a <= 0 || stages_b <= 0 || stages_a + stages_b > 1024 { return tbo_stage_schedule {child_a_stages: tbo_int_array(1, 0 - 1), child_b_stages: tbo_int_array(1, 0 - 1), tick_count: 0, valid: false} }
    int delta = delta_stages
    if delta < 0 { delta = 0 }
    if delta > stages_a { delta = stages_a }
    []int a_trace = tbo_int_array(1024, 0 - 1)
    []int b_trace = tbo_int_array(1024, 0 - 1)
    int tick = 0
    int a = 0
    int b = 0
    for a < delta { a_trace[tick] = a; a = a + 1; tick = tick + 1 }
    for a < stages_a && b < stages_b { a_trace[tick] = a; b_trace[tick] = b; a = a + 1; b = b + 1; tick = tick + 1 }
    for a < stages_a { a_trace[tick] = a; a = a + 1; tick = tick + 1 }
    for b < stages_b { b_trace[tick] = b; b = b + 1; tick = tick + 1 }
    tbo_stage_schedule {child_a_stages: a_trace, child_b_stages: b_trace, tick_count: tick, valid: true}
}
