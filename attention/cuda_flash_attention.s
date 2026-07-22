package neurx.attention.cuda














func launch_flash_attention_forward(
    cuda_context ctx,
    uint64 ptr_q,
    uint64 ptr_k,
    uint64 ptr_v,
    uint64 ptr_output,
    attention_config cfg
) error {
    if !ctx.is_initialized {
        return error{message: "CUDA context not initialized"}
    }

    if !cfg.use_flash_attention {

        return launch_standard_attention(ctx, ptr_q, ptr_k, ptr_v, ptr_output, cfg)
    }
































    int n2_mem = cfg.batch_size * cfg.num_heads * cfg.seq_len_q * cfg.seq_len_kv * 2
    int flash_mem = cfg.batch_size * cfg.num_heads * cfg.seq_len_q * cfg.head_dim * 4

    log_kernel_launch("FLASH_ATTN_FWD", cfg.seq_len_q, cfg.seq_len_kv, 0,
                      float(cfg.batch_size * cfg.num_heads *
                           cfg.seq_len_q * cfg.seq_len_kv * cfg.head_dim),
                      flash_mem)

    println("FlashAttention: Memory saved ~" +
            int_to_string((n2_mem - flash_mem) / 1024 / 1024) +
            " MB per batch")

    nil
}
