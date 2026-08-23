package neurx.inference.model.adapters.model_kernel_native_abi
extern func neurx_deepseek_v2_attention(int input_ptr_low, int output_ptr_low, int token_count, int stream_id) int
extern func neurx_deepseek_v4_compressed_kv(int input_ptr_low, int output_ptr_low, int token_count, int stream_id) int
extern func neurx_qwen3_moe(int input_ptr_low, int output_ptr_low, int token_count, int expert_count, int stream_id) int
extern func neurx_mimo_v2_moe(int input_ptr_low, int output_ptr_low, int token_count, int expert_count, int stream_id) int
extern func neurx_mamba_state_space(int input_ptr_low, int state_ptr_low, int output_ptr_low, int token_count, int stream_id) int

func model_kernel_native_dispatch(int model_family, int kernel_type, int input_ptr_low, int state_ptr_low, int output_ptr_low, int token_count, int expert_count, int stream_id) int {
    if input_ptr_low == 0 || output_ptr_low == 0 || token_count <= 0 { return 400 }
    if model_family == 2 && kernel_type == 1 { return neurx_deepseek_v2_attention(input_ptr_low, output_ptr_low, token_count, stream_id) }
    if model_family == 3 && kernel_type == 6 { return neurx_deepseek_v4_compressed_kv(input_ptr_low, output_ptr_low, token_count, stream_id) }
    if model_family == 4 && kernel_type == 2 { return neurx_qwen3_moe(input_ptr_low, output_ptr_low, token_count, expert_count, stream_id) }
    if model_family == 5 && kernel_type == 2 { return neurx_mimo_v2_moe(input_ptr_low, output_ptr_low, token_count, expert_count, stream_id) }
    if model_family == 6 && kernel_type == 5 { return neurx_mamba_state_space(input_ptr_low, state_ptr_low, output_ptr_low, token_count, stream_id) }
    404
}
