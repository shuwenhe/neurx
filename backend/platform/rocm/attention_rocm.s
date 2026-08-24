package neurx.platform.rocm.attention

import (
    "neurx.platform.rocm.runtime" as rocm_rt
)

struct attention_config {
    int batch_size
    int num_heads
    int num_kv_heads
    int head_dim
    int seq_len_q
    int seq_len_k
    bool use_alibi
    bool use_sliding_window
    int sliding_window
    string dtype
}

struct flash_attention_state {
    rocm_rt.rocm_memory_ptr q_ptr
    rocm_rt.rocm_memory_ptr k_ptr
    rocm_rt.rocm_memory_ptr v_ptr
    rocm_rt.rocm_memory_ptr out_ptr
    int block_size
    bool is_causal
    string backend
}

func rocm_attention_forward(attention_config config,
                           rocm_rt.rocm_memory_ptr q,
                           rocm_rt.rocm_memory_ptr k,
                           rocm_rt.rocm_memory_ptr v) rocm_rt.rocm_memory_ptr {
    0
}

func rocm_attention_backward(attention_config config,
                            rocm_rt.rocm_memory_ptr grad_out,
                            rocm_rt.rocm_memory_ptr q,
                            rocm_rt.rocm_memory_ptr k,
                            rocm_rt.rocm_memory_ptr v) [rocm_rt.rocm_memory_ptr, rocm_rt.rocm_memory_ptr, rocm_rt.rocm_memory_ptr] {
    [0, 0, 0]
}

func rocm_paged_attention_forward(attention_config config,
                                 rocm_rt.rocm_memory_ptr q,
                                 rocm_rt.rocm_memory_ptr k_cache,
                                 rocm_rt.rocm_memory_ptr v_cache,
                                 []int64 block_table) rocm_rt.rocm_memory_ptr {
    0
}

func rocm_flash_attention_v2(attention_config config,
                            rocm_rt.rocm_memory_ptr q,
                            rocm_rt.rocm_memory_ptr k,
                            rocm_rt.rocm_memory_ptr v,
                            bool causal) rocm_rt.rocm_memory_ptr {
    0
}

func rocm_mqa_attention_forward(int batch_size,
                               int num_heads,
                               int head_dim,
                               int seq_len,
                               rocm_rt.rocm_memory_ptr q,
                               rocm_rt.rocm_memory_ptr kv) rocm_rt.rocm_memory_ptr {
    0
}

func rocm_gqa_attention_forward(int batch_size,
                               int num_heads,
                               int num_kv_heads,
                               int head_dim,
                               int seq_len,
                               rocm_rt.rocm_memory_ptr q,
                               rocm_rt.rocm_memory_ptr k,
                               rocm_rt.rocm_memory_ptr v) rocm_rt.rocm_memory_ptr {
    0
}

func rocm_attention_reduce_all_tokens(rocm_rt.rocm_memory_ptr attention_out,
                                     int batch_size,
                                     int seq_len,
                                     int hidden_dim) rocm_rt.rocm_memory_ptr {
    0
}

func rocm_attention_with_alibi(attention_config config,
                              rocm_rt.rocm_memory_ptr q,
                              rocm_rt.rocm_memory_ptr k,
                              rocm_rt.rocm_memory_ptr v,
                              []float alibi_slopes) rocm_rt.rocm_memory_ptr {
    0
}

func rocm_attention_with_rope(attention_config config,
                             rocm_rt.rocm_memory_ptr q,
                             rocm_rt.rocm_memory_ptr k,
                             rocm_rt.rocm_memory_ptr v,
                             []float freqs_cos,
                             []float freqs_sin) rocm_rt.rocm_memory_ptr {
    0
}
