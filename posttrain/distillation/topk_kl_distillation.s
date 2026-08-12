package neurx.posttrain.distillation.topk
use neurx.tensor
struct topk_kl_config {
    int top_k
    int chunk_size
    float temperature
    bool use_fp32_logsumexp
}

struct topk_kl_state {
    topk_kl_config config
    int step_count
}

func default_topk_kl_config() topk_kl_config {
    topk_kl_config {
        top_k: 256,
        chunk_size: 1024,
        temperature: 1.0,
        use_fp32_logsumexp: true,
    }
}

func compute_topk_kl_loss(
    tensor student_logits,
    tensor teacher_logits,
    tensor response_mask,
    topk_kl_config config
) tensor {
    int batch_size = size(student_logits, 0)
    int seq_len = size(student_logits, 1)
    int vocab_size = size(student_logits, 2)
    tensor loss = zeros([]int{batch_size, seq_len})
    int num_chunks = (vocab_size + config.chunk_size - 1) / config.chunk_size
    for int chunk_idx = 0; chunk_idx < num_chunks; chunk_idx = chunk_idx + 1 {
        int start_idx = chunk_idx * config.chunk_size
        int end_idx = min_int(start_idx + config.chunk_size, vocab_size)
        tensor student_chunk = slice_dim(student_logits, 2, start_idx, end_idx)
        tensor teacher_chunk = slice_dim(teacher_logits, 2, start_idx, end_idx)
        tensor topk_values_t, tensor topk_indices = topk_dim(teacher_chunk, 2, config.top_k)
        tensor student_topk = gather_by_indices(student_chunk, topk_indices, 2)
        tensor student_log_probs = log_softmax_topk(student_topk, config)
        tensor teacher_log_probs = log_softmax_topk(topk_values_t, config)
        tensor teacher_probs = exp_tensor(teacher_log_probs)
        tensor kl_chunk = mul(teacher_probs, sub(teacher_log_probs, student_log_probs))
        tensor kl_sum = sum_dim(kl_chunk, 2)
        loss = add(loss, kl_sum)
    }
    tensor masked_loss = mul(loss, response_mask)
    float num_tokens = item(sum_all(response_mask))
    if num_tokens < 1.0 {
        return from_float(0.0)
    }
    return div_scalar(sum_all(masked_loss), num_tokens)
}

func log_softmax_topk(tensor logits, topk_kl_config config) tensor {
    tensor scaled = div_scalar(logits, config.temperature)
    tensor max_vals = max_dim(scaled, 2, true)
    tensor shifted = sub(scaled, max_vals)
    tensor exp_vals = exp_tensor(shifted)
    tensor sum_exp = sum_dim(exp_vals, 2, true)
    tensor log_sum_exp = add(log_tensor(sum_exp), max_vals)
    return sub(scaled, log_sum_exp)
}

func chunked_topk_forward(
    tensor student_logits,
    tensor teacher_logits,
    topk_kl_config config
) (tensor, tensor) {
    int vocab_size = size(teacher_logits, 2)
    int num_chunks = (vocab_size + config.chunk_size - 1) / config.chunk_size
    []tensor student_topk_chunks = make([]tensor, num_chunks)
    []tensor teacher_topk_chunks = make([]tensor, num_chunks)
    for int chunk_idx = 0; chunk_idx < num_chunks; chunk_idx = chunk_idx + 1 {
        int start_idx = chunk_idx * config.chunk_size
        int end_idx = min_int(start_idx + config.chunk_size, vocab_size)
        tensor teacher_chunk = slice_dim(teacher_logits, 2, start_idx, end_idx)
        tensor topk_values, tensor topk_indices = topk_dim(teacher_chunk, 2, config.top_k)
        teacher_topk_chunks[chunk_idx] = topk_values
        tensor student_chunk = slice_dim(student_logits, 2, start_idx, end_idx)
        student_topk_chunks[chunk_idx] = gather_by_indices(student_chunk, topk_indices, 2)
    }
    tensor student_topk = concat_tensors(student_topk_chunks, 2)
    tensor teacher_topk = concat_tensors(teacher_topk_chunks, 2)
    return student_topk, teacher_topk
}

func new_topk_kl_trainer(topk_kl_config config) topk_kl_state {
    topk_kl_state {
        config: config,
        step_count: 0,
    }
}

func min_int(int a, int b) int {
    if a < b {
        return a
    }
    return b
}

