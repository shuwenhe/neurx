package neurx.cuda
struct layernorm_config {
    int batch_size
    int normalized_size
    float eps
    bool compute_stats_only
}

func launch_layernorm(
    cuda_context ctx,
    uint64 ptr_input,
    uint64 ptr_gamma,
    uint64 ptr_beta,
    uint64 ptr_output,
    layernorm_config cfg
) error {
    if !ctx.is_initialized {
        return error{message: "CUDA context not initialized"}
    }
    log_kernel_launch("LAYER_NORM", cfg.batch_size, cfg.normalized_size, 0,
                      float(cfg.batch_size * cfg.normalized_size * 7),
                      cfg.batch_size * cfg.normalized_size * 6 * 2)
    nil
}
