package neurx.distributed.tensor_parallel

use std.vec.vec
use neurx.device.abi
use neurx.distributed.nccl_comm
use neurx.compute.core_kernels

struct tensor_parallel_config {
    int world_size
    int rank
    int tp_size
    int hidden_size
    int hidden_size_local
}

struct sharded_tensor {
    abi.device_tensor local_tensor
    int shard_dim
    int world_size
    int rank
}

tensor_parallel_config g_tp_config

func tensor_parallel_init(tp_size: int, rank: int, hidden_size: int) (bool, string) {
    if tp_size <= 0 || rank < 0 || rank >= tp_size {
        return false, "Invalid TP config"
    }

    if hidden_size % tp_size != 0 {
        return false, "Hidden size must be divisible by TP size"
    }

    hidden_size_local := hidden_size / tp_size

    g_tp_config = tensor_parallel_config {
        world_size: tp_size,
        rank: rank,
        tp_size: tp_size,
        hidden_size: hidden_size,
        hidden_size_local: hidden_size_local,
    }

    return true, ""
}

func shard_weight_along_output(
    weight: abi.device_tensor,
    tp_size: int,
    rank: int
) (sharded_tensor, bool, string) {
    if weight.shape.len() < 2 {
        return sharded_tensor{}, false, "Weight must be 2D or higher"
    }

    if weight.shape[0] % tp_size != 0 {
        return sharded_tensor{}, false, "Output dimension not divisible by TP size"
    }

    shard_size := weight.shape[0] / tp_size
    offset := rank * shard_size

    local_shape := vec[int]()
    local_shape.push(shard_size)
    for i := 1; i < weight.shape.len(); i = i + 1 {
        local_shape.push(weight.shape[i])
    }

    local_element_count := int64(shard_size)
    for i := 1; i < weight.shape.len(); i = i + 1 {
        local_element_count = local_element_count * int64(weight.shape[i])
    }

    sharded := sharded_tensor {
        local_tensor: abi.device_tensor {
            data: weight.data,
            shape: local_shape,
            strides: weight.strides,
            dtype: weight.dtype,
            device_id: weight.device_id,
            element_count: local_element_count,
            ref_count: 1,
            is_view: true,
        },
        shard_dim: 0,
        world_size: tp_size,
        rank: rank,
    }

    return sharded, true, ""
}

func shard_weight_along_input(
    weight: abi.device_tensor,
    tp_size: int,
    rank: int
) (sharded_tensor, bool, string) {
    if weight.shape.len() < 2 {
        return sharded_tensor{}, false, "Weight must be 2D or higher"
    }

    if weight.shape[1] % tp_size != 0 {
        return sharded_tensor{}, false, "Input dimension not divisible by TP size"
    }

    shard_size := weight.shape[1] / tp_size
    offset := rank * shard_size

    local_shape := vec[int]()
    local_shape.push(weight.shape[0])
    local_shape.push(shard_size)
    for i := 2; i < weight.shape.len(); i = i + 1 {
        local_shape.push(weight.shape[i])
    }

    local_element_count := int64(weight.shape[0]) * int64(shard_size)
    for i := 2; i < weight.shape.len(); i = i + 1 {
        local_element_count = local_element_count * int64(weight.shape[i])
    }

    sharded := sharded_tensor {
        local_tensor: abi.device_tensor {
            data: weight.data,
            shape: local_shape,
            strides: weight.strides,
            dtype: weight.dtype,
            device_id: weight.device_id,
            element_count: local_element_count,
            ref_count: 1,
            is_view: true,
        },
        shard_dim: 1,
        world_size: tp_size,
        rank: rank,
    }

    return sharded, true, ""
}

func all_reduce_output(
    local_output: abi.device_tensor,
    tp_size: int
) (abi.device_tensor, bool, string) {
    if local_output.element_count <= 0 {
        return abi.device_tensor{}, false, "Invalid tensor"
    }

    combined := abi.device_tensor {
        data: local_output.data,
        shape: local_output.shape,
        strides: local_output.strides,
        dtype: local_output.dtype,
        device_id: local_output.device_id,
        element_count: local_output.element_count * int64(tp_size),
        ref_count: 1,
        is_view: false,
    }

    return combined, true, ""
}

func all_gather_activations(
    local_activation: abi.device_tensor,
    tp_size: int
) (abi.device_tensor, bool, string) {
    if local_activation.element_count <= 0 {
        return abi.device_tensor{}, false, "Invalid tensor"
    }

    gathered_size := local_activation.element_count * int64(tp_size)

    gathered := abi.device_tensor {
        data: local_activation.data,
        shape: local_activation.shape,
        strides: local_activation.strides,
        dtype: local_activation.dtype,
        device_id: local_activation.device_id,
        element_count: gathered_size,
        ref_count: 1,
        is_view: false,
    }

    return gathered, true, ""
}

func reduce_scatter_gradients(
    full_gradient: abi.device_tensor,
    tp_size: int,
    rank: int
) (abi.device_tensor, bool, string) {
    if full_gradient.element_count <= 0 {
        return abi.device_tensor{}, false, "Invalid tensor"
    }

    local_size := full_gradient.element_count / int64(tp_size)
    offset := int64(rank) * local_size

    local_shape := vec[int]()
    for i := 0; i < full_gradient.shape.len(); i = i + 1 {
        if i == 0 {
            local_shape.push(full_gradient.shape[i] / tp_size)
        } else {
            local_shape.push(full_gradient.shape[i])
        }
    }

    scattered := abi.device_tensor {
        data: full_gradient.data,
        shape: local_shape,
        strides: full_gradient.strides,
        dtype: full_gradient.dtype,
        device_id: full_gradient.device_id,
        element_count: local_size,
        ref_count: 1,
        is_view: true,
    }

    return scattered, true, ""
}

func tensor_parallel_gemm(
    input_tensor: abi.device_tensor,
    weight_shard: sharded_tensor,
    use_all_reduce: bool
) (abi.device_tensor, bool, string) {
    if input_tensor.element_count <= 0 {
        return abi.device_tensor{}, false, "Invalid input"
    }

    local_output, gemm_success, gemm_err := core_kernels.device_tensor_gemm(input_tensor, weight_shard.local_tensor, 1.0, 0.0)
    if !gemm_success {
        return abi.device_tensor{}, false, "GEMM failed: " + gemm_err
    }

    if use_all_reduce {
        output, reduce_success, reduce_err := all_reduce_output(local_output, weight_shard.world_size)
        if !reduce_success {
            return abi.device_tensor{}, false, "All-reduce failed: " + reduce_err
        }

        return output, true, ""
    }

    return local_output, true, ""
}

func get_tensor_parallel_config() (tensor_parallel_config, bool, string) {
    if g_tp_config.tp_size <= 0 {
        return tensor_parallel_config{}, false, "TP not initialized"
    }

    return g_tp_config, true, ""
}
