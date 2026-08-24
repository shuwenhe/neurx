package neurx.platform.cuda

struct gemm_config {
    int M
    int K
    int N
    bool trans_a
    bool trans_b
    float alpha
    float beta
    string compute_dtype
    bool use_tensor_cores
    int tile_size
}

func default_gemm_config(int M, int K, int N) gemm_config {
    gemm_config {
        M: M, K: K, N: N,
        trans_a: false,
        trans_b: false,
        alpha: 1.0,
        beta: 0.0,
        compute_dtype: "fp16",
        use_tensor_cores: true,
        tile_size: 32,
    }
}

func launch_gemm(
    cuda_context ctx,
    uint64 ptr_a,
    uint64 ptr_b,
    uint64 ptr_c,
    gemm_config cfg
) error {
    if !ctx.is_initialized {
        return error{message: "CUDA context not initialized"}
    }
    if cfg.M <= 0 || cfg.K <= 0 || cfg.N <= 0 {
        return error{message: "Invalid matrix dimensions"}
    }
    float flops = 2.0 * float(cfg.M) * float(cfg.K) * float(cfg.N)
    int memory_bytes = (cfg.M * cfg.K + cfg.K * cfg.N + cfg.M * cfg.N) * 2
    log_kernel_launch("GEMM", cfg.M, cfg.K, cfg.N, flops, memory_bytes)
    nil
}
