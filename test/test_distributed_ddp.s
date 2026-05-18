package neurx.test_distributed_ddp

use neurx.distributed.comm.{new_process_group, process_group_backend, process_group_rank, process_group_world_size, process_group_initialized}
use neurx.distributed.ddp.{ddp_state, new_ddp_state, ddp_attach_process_group, ddp_add_param, ddp_mark_grad_ready, ddp_reduce_ready_buckets, ddp_finalize_step, ddp_name, ddp_step, ddp_bucket_cap, ddp_param_count, ddp_ready_param_count, ddp_reduced_bucket_count, ddp_gradient_synchronized, ddp_process_group_backend, ddp_process_group_rank, ddp_process_group_world_size, ddp_process_group_initialized, ddp_is_distributed, ddp_sync_scale, ddp_all_reduce_grad, ddp_broadcast_params}

func main() int {
    ddp_state state = new_ddp_state("ddp-demo", 32, false)
    process_group_state pg = new_process_group("gloo", 1, 4)
    state = ddp_attach_process_group(state, pg)

    println("name: ", ddp_name(state))
    println("bucket_cap: ", ddp_bucket_cap(state))
    println("step: ", ddp_step(state))
    println("ddp_backend: ", ddp_process_group_backend(state))
    println("ddp_rank: ", ddp_process_group_rank(state))
    println("ddp_world_size: ", ddp_process_group_world_size(state))
    println("ddp_initialized: ", ddp_process_group_initialized(state))
    println("ddp_is_distributed: ", ddp_is_distributed(state))
    println("ddp_sync_scale: ", ddp_sync_scale(state))

    state = ddp_add_param(state, "w1", 128)
    state = ddp_add_param(state, "w2", 64)
    println("param_count: ", ddp_param_count(state))

    state = ddp_mark_grad_ready(state, "w1")
    println("ready_count_after_w1: ", ddp_ready_param_count(state))

    state = ddp_mark_grad_ready(state, "w2")
    state = ddp_reduce_ready_buckets(state, 4)
    println("gradient_synchronized: ", ddp_gradient_synchronized(state))
    println("reduced_bucket_count: ", ddp_reduced_bucket_count(state))
    []float reduced = ddp_all_reduce_grad(state, pg, [1.0, 2.0])
    []float broadcasted = ddp_broadcast_params(state, pg, [3.0, 4.0])
    println("ddp_all_reduce_grad: ", reduced)
    println("ddp_broadcast_params: ", broadcasted)

    state = ddp_finalize_step(state)
    println("step_after_finalize: ", ddp_step(state))
    println("ready_count_after_finalize: ", ddp_ready_param_count(state))
    println("gradient_synchronized_after_finalize: ", ddp_gradient_synchronized(state))
    0
}
