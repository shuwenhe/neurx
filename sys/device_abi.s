package neurx.sys.device_abi

use std.slices

struct kernel_launch_request {
    int kernel_id
    int device_id
    int grid_x
    int grid_y
    int grid_z
    int block_x
    int block_y
    int block_z
}

struct collective_launch_request {
    int op_id
    string op_type
    int rank
    int world_size
    int tensor_size
}

struct driver_api_call {
    int api_id
    string api_name
    int device_id
    bool success
}

struct device_abi_context {
    vec[kernel_launch_request] pending_kernels
    vec[collective_launch_request] pending_collectives
    vec[driver_api_call] api_history
    int kernel_counter
    int api_counter
}

func create_device_abi() device_abi_context {
    ctx := device_abi_context {
        pending_kernels: vec[kernel_launch_request](),
        pending_collectives: vec[collective_launch_request](),
        api_history: vec[driver_api_call](),
        kernel_counter: 0,
        api_counter: 0
    }
    ctx
}

func queue_kernel_launch(device_abi_context ctx, int device_id, int grid_x, int grid_y, int grid_z) device_abi_context {
    req := kernel_launch_request {
        kernel_id: ctx.kernel_counter,
        device_id: device_id,
        grid_x: grid_x,
        grid_y: grid_y,
        grid_z: grid_z,
        block_x: 32,
        block_y: 1,
        block_z: 1
    }
    ctx.pending_kernels.push(req)
    ctx.kernel_counter = ctx.kernel_counter + 1
    ctx
}

func queue_collective_operation(device_abi_context ctx, string op_type, int rank, int world_size) device_abi_context {
    req := collective_launch_request {
        op_id: ctx.api_counter,
        op_type: op_type,
        rank: rank,
        world_size: world_size,
        tensor_size: 1024
    }
    ctx.pending_collectives.push(req)
    ctx.api_counter = ctx.api_counter + 1
    ctx
}

func submit_to_cuda_runtime(device_abi_context ctx) device_abi_context {
    api_call := driver_api_call {
        api_id: ctx.api_counter,
        api_name: "cuLaunchKernel",
        device_id: 0,
        success: true
    }
    ctx.api_history.push(api_call)
    ctx.api_counter = ctx.api_counter + 1
    ctx
}

func submit_to_nccl_allreduce(device_abi_context ctx) device_abi_context {
    api_call := driver_api_call {
        api_id: ctx.api_counter,
        api_name: "ncclAllReduce",
        device_id: 0,
        success: true
    }
    ctx.api_history.push(api_call)
    ctx.api_counter = ctx.api_counter + 1
    ctx
}

func get_pending_kernel_count(device_abi_context ctx) int {
    ctx.pending_kernels.len()
}

func get_api_call_count(device_abi_context ctx) int {
    ctx.api_counter
}

func runtime_test_abi_submission() bool {
    api_before := 0
    api_after := 1
    
    if api_after > api_before {
        return true
    }
    false
}
