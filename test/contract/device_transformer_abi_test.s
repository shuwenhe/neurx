package main
use neurx.runtime.device.device_tensor.{tensor_dtype_bytes, tensor_numel, tensor_contiguous_strides}
use neurx.inference.runtime.device_transformer.{transformer_device_config, transformer_schedule, transformer_prefill_schedule, transformer_decode_schedule, transformer_vendor_at}
use neurx.runtime.device.device_binding.{embedding_binding, paged_attention_binding}
use neurx.inference.runtime.transformer_executor.{transformer_execution_plan, transformer_plan_binding_valid}

func require(bool condition, string message) {
    if !condition { print("FAIL: " + message + "\n"); return }
}

func main() {
    require(tensor_dtype_bytes("bf16") == 2, "bf16 width")
    require(tensor_numel([2, 3, 4]) == 24, "tensor numel")
    int[] strides = tensor_contiguous_strides([2, 3, 4])
    require(strides[0] == 12 && strides[1] == 4 && strides[2] == 1, "contiguous strides")
    transformer_device_config config = transformer_device_config {layers: 2, hidden: 8, intermediate: 16, query_heads: 2, kv_heads: 1, head_dim: 4, vocabulary: 32, dtype: "bf16", rms_epsilon: "0.000001", rope_theta: "1000000", attention_bias: true}
    transformer_schedule cuda_prefill = transformer_prefill_schedule("cuda", true, config)
    transformer_schedule cann_prefill = transformer_prefill_schedule("cann", true, config)
    transformer_schedule cuda_decode = transformer_decode_schedule("cuda", true, config)
    transformer_schedule cann_decode = transformer_decode_schedule("cann", true, config)
    require(cuda_prefill.valid && cann_prefill.valid && cuda_decode.valid && cann_decode.valid, "all schedules valid")
    require(len(cuda_prefill.operations) == len(cann_prefill.operations), "same control graph size")
    require(cuda_prefill.layer_operations == cann_prefill.layer_operations, "same layer control logic")
    require(transformer_vendor_at(cuda_prefill, 2) == "cublaslt_matmul", "CUDA linear lowering")
    require(transformer_vendor_at(cann_prefill, 2) == "aclnn_matmul", "CANN linear lowering")
    require(transformer_vendor_at(cuda_prefill, 6) == "cuda_paged_attention", "CUDA attention lowering")
    require(transformer_vendor_at(cann_prefill, 6) == "atb_paged_attention", "CANN attention lowering")
    require(embedding_binding(1, 2, 3, 4) == "buffer.ids=1;buffer.weight=2;buffer.output=3;tokens=4", "embedding binding ABI")
    require(paged_attention_binding(1, 2, 3, 4, 5, 6, 7, 8, 16) == "buffer.query=1;buffer.key_cache=2;buffer.value_cache=3;buffer.block_table=4;buffer.workspace=5;buffer.output=6;position=7;max_sequence=8;block_size=16", "paged attention binding ABI")
    transformer_execution_plan invalid_plan = transformer_execution_plan {context_handle: 0, stream_handle: 0, operation_handle: [], operation_count: 0, backend: "cuda", valid: false, error_message: "test"}
    require(!transformer_plan_binding_valid(invalid_plan, []), "invalid execution plan rejected")
    print("PASS: unified S Device ABI and Transformer schedule\n")
}
