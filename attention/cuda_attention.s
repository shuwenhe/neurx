package neurx.attention.cuda
struct attention_config {
    int batch_size
    int num_heads
    int seq_len_q
    int seq_len_kv
    int head_dim
    float scale
    bool is_causal
    bool use_dropout
    float dropout_probability
    bool use_flash_attention
    bool use_memory_efficient
}


func default_attention_config(
    int batch_size,
    int num_heads,
    int seq_len,
    int head_dim,
    bool is_causal
) attention_config {
    attention_config {
        batch_size: batch_size,
        num_heads: num_heads,
        seq_len_q: seq_len,
        seq_len_kv: seq_len,
        head_dim: head_dim,
        scale: 1.0 / sqrt(float(head_dim)),
        is_causal: is_causal,
        use_dropout: false,
        dropout_probability: 0.0,
        use_flash_attention: true,
        use_memory_efficient: false,
    }
}

