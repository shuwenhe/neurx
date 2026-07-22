package neurx.cuda






struct softmax_config {
    int rows
    int cols

    bool is_log_softmax


    int block_size
}










func launch_softmax(
    cuda_context ctx,
    uint64 ptr_input,
    uint64 ptr_output,
    softmax_config cfg
) error {
    if !ctx.is_initialized {
        return error{message: "CUDA context not initialized"}
    }



















    log_kernel_launch("SOFTMAX", cfg.rows, cfg.cols, 0,
                      float(cfg.rows * cfg.cols * 3),
                      cfg.rows * cfg.cols * 4 * 2)

    nil
}
