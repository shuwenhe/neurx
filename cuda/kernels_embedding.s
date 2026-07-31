package neurx.cuda
struct embedding_config {
    int num_embeddings
    int embedding_dim
    int num_tokens
    bool padding_idx_set
    int padding_idx
}
func launch_embedding_forward(
    cuda_context ctx,
    uint64 ptr_weight,
    uint64 ptr_token_ids,
    uint64 ptr_output,
    embedding_config cfg
) error {
    if !ctx.is_initialized {
        return error{message: "CUDA context not initialized"}
    }
    log_kernel_launch("EMBEDDING_FWD", cfg.num_tokens, cfg.embedding_dim, 0,
                      float(cfg.num_tokens * cfg.embedding_dim),
                      cfg.num_tokens * cfg.embedding_dim * 4)
    nil
}

func launch_embedding_backward(
    cuda_context ctx,
    uint64 ptr_grad_output,
    uint64 ptr_token_ids,
    uint64 ptr_grad_weight,
    embedding_config cfg
) error {
    if !ctx.is_initialized {
        return error{message: "CUDA context not initialized"}
    }
    log_kernel_launch("EMBEDDING_BWD", cfg.num_tokens, cfg.embedding_dim, 0,
                      float(cfg.num_tokens * cfg.embedding_dim),
                      cfg.num_tokens * cfg.embedding_dim * 8)
    nil
}
