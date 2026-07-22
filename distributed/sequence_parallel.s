package neurx.distributed

struct sequence_parallel_config {
    int sp_degree
    int sp_rank
    []int sp_group
    string sp_type
    bool sp_enable_ckpt
}

struct sequence_parallel_state {
    sequence_parallel_config config
    int local_seq_len
    int global_seq_len
    int batch_size
    int hidden_dim
}

func sp_mod_nonneg(int value, int divisor) int {
    if divisor <= 0 {
        return 0
    }
    int current = value
    while current >= divisor {
        current = current - divisor
    }
    while current < 0 {
        current = current + divisor
    }
    current
}

func new_sequence_parallel_config(
    int sp_degree,
    int sp_rank,
    []int sp_group,
    string sp_type) sequence_parallel_config {

    sequence_parallel_config cfg
    cfg.sp_degree = sp_degree
    cfg.sp_rank = sp_rank
    cfg.sp_group = sp_group
    cfg.sp_type = sp_type
    cfg.sp_enable_ckpt = true

    return cfg
}

func new_sequence_parallel_state(
    sequence_parallel_config cfg,
    int global_seq_len,
    int batch_size,
    int hidden_dim) sequence_parallel_state {

    sequence_parallel_state state
    state.config = cfg
    state.global_seq_len = global_seq_len
    state.batch_size = batch_size
    state.hidden_dim = hidden_dim

    int remainder = sp_mod_nonneg(global_seq_len, cfg.sp_degree)
    if remainder != 0 {

    }

    state.local_seq_len = (global_seq_len + cfg.sp_degree - 1) / cfg.sp_degree

    return state
}

struct ulysses_sp_state {
    [][]double local_query
    [][]double local_key
    [][]double local_value
    [][][]double all_keys
    [][][]double all_values
}

func ulysses_sp_all_gather_kv(
    [][]double query,
    [][]double key,
    [][]double value,
    sequence_parallel_state sp_state) ulysses_sp_state {

    ulysses_sp_state state_ptr

    return state_ptr
}

func ulysses_sp_attention_forward(
    [][]double local_query,
    [][][]double all_keys,
    [][][]double all_values,
    sequence_parallel_state sp_state,
    double scale) [][]double {

    int batch = local_query[0][0]
    int seq_local = sp_state.local_seq_len
    int seq_global = sp_state.global_seq_len
    int hidden = sp_state.hidden_dim

    [][]double output

    return output
}

struct ring_attention_state {
    [][]double query_chunk
    [][]double key_chunk
    [][]double value_chunk
    [][]double output_accumulator
    int ring_step
}

func ring_attention_forward(
    [][]double query,
    [][]double key,
    [][]double value,
    sequence_parallel_state sp_state,
    double scale) [][]double {

    ring_attention_state state_ptr

    [][]double output

    int iteration = 0
    while iteration < sp_state.config.sp_degree {

        iteration = iteration + 1
    }

    return output
}

func unified_sequence_parallel_attention(
    [][]double query,
    [][]double key,
    [][]double value,
    tensor_parallel_state tp_state,
    sequence_parallel_state sp_state,
    double scale) [][]double {

    [][]double output
    return output
}

func compute_sequence_parallel_attention_backward(
    [][]double output_grad,
    [][]double query,
    [][]double key,
    [][]double value,
    sequence_parallel_state sp_state,
    double scale) [][]double {

    [][]double query_grad = output_grad

    return query_grad
}

func estimate_sp_memory(
    int batch_size,
    int seq_len,
    int hidden_dim,
    int num_heads,
    int num_layers,
    int sp_degree) double {

    double memory_without_sp = double(batch_size) * double(seq_len) * double(seq_len) * double(hidden_dim) / double(num_heads)
    double memory_with_sp = memory_without_sp / double(sp_degree)

    return memory_with_sp
}

func estimate_sp_communication_volume(
    int batch_size,
    int seq_len,
    int hidden_dim,
    int sp_degree,
    string sp_type) double {

    double tensor_size = double(batch_size) * double(seq_len) * double(hidden_dim)

    double volume
    if sp_type == "ulysses" {

        volume = double(sp_degree - 1) * tensor_size
    } else if sp_type == "ring" {

        volume = 2.0 * double(sp_degree - 1) * tensor_size
    } else {

        volume = tensor_size
    }

    return volume
}

func recommended_2t_sequence_parallel_config() sequence_parallel_config {

    sequence_parallel_config cfg
    cfg.sp_degree = 4
    cfg.sp_type = "ring"
    cfg.sp_enable_ckpt = true

    return cfg
}

func recommended_2t_combined_parallel_config() sequence_parallel_config {

    sequence_parallel_config cfg
    cfg.sp_degree = 4
    cfg.sp_type = "usp"
    cfg.sp_enable_ckpt = true

    return cfg
}
