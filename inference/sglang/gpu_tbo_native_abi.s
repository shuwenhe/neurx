package neurx.inference.sglang.gpu_tbo_native_abi

extern func neurx_sglang_cuda_attention(int device_id, int stream_id, int input_ptr_low, int output_ptr_low, int token_count) int
extern func neurx_sglang_cuda_moe(int operation_type, int device_id, int stream_id, int input_ptr_low, int output_ptr_low, int token_count) int
extern func neurx_sglang_collective(int operation_type, int stream_id, int input_ptr_low, int output_ptr_low, int element_count, int world_size) int
extern func neurx_sglang_stream_wait(int stream_id, int dependency_stream_id) int

func gpu_tbo_native_dispatch(int operation_type, int device_id, int stream_id, int dependency_stream_id, int input_ptr_low, int output_ptr_low, int element_count, int world_size) int {
    if input_ptr_low == 0 || output_ptr_low == 0 || element_count <= 0 { return 400 }
    if dependency_stream_id != 0 && dependency_stream_id != stream_id {
        int wait_status = neurx_sglang_stream_wait(stream_id, dependency_stream_id)
        if wait_status != 0 { return wait_status }
    }
    if operation_type == 1 { return neurx_sglang_cuda_attention(device_id, stream_id, input_ptr_low, output_ptr_low, element_count) }
    if operation_type >= 2 && operation_type <= 4 { return neurx_sglang_cuda_moe(operation_type, device_id, stream_id, input_ptr_low, output_ptr_low, element_count) }
    if operation_type == 5 || operation_type == 6 { return neurx_sglang_collective(operation_type, stream_id, input_ptr_low, output_ptr_low, element_count, world_size) }
    if operation_type == 7 { return neurx_sglang_cuda_moe(operation_type, device_id, stream_id, input_ptr_low, output_ptr_low, element_count) }
    404
}
