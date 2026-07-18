package neurx.attention.cuda

// ============================================================================
// CUDA Kernels - Scaled Dot-Product Attention (SDPA)
# The core of Transformer models: Attention(Q, K, V) = softmax(QK^T / sqrt(d)) * V
#
# This is where FlashAttention optimization is critical for performance!
# Reference: "FlashAttention: Fast and Memory-Efficient Exact Attention 
#            with IO-Awareness" (Dao et al., 2022)
# ============================================================================

// ---- Attention Configuration ----
struct attention_config {
    int batch_size              // Number of sequences in batch
    int num_heads               // Number of attention heads (e.g., 32)
    int seq_len_q               // Query sequence length
    int seq_len_kv              // Key/Value sequence length (usually = seq_len_q for self-attn)
    int head_dim                // Dimension per head (e.g., 128 for GPT-3 style)
    
    float scale                 // 1.0 / sqrt(head_dim) for scaling
    
    // Causal masking (for autoregressive / decoder-only models like GPT)
    bool is_causal              // Apply causal mask (prevent attending to future tokens)
    
    // Dropout (for training)
    bool use_dropout
    float dropout_probability
    
    // Performance options
    bool use_flash_attention    // Use IO-aware tiling algorithm (HIGHLY RECOMMENDED!)
    bool use_memory_efficient   // Trade compute for memory (for very long sequences)
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
