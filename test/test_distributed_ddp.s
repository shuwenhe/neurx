package neurx.test_distributed_ddp

use neurx.distributed.ddp.{ddp_state, new_ddp_state, ddp_add_param, ddp_mark_grad_ready, ddp_reduce_ready_buckets, ddp_finalize_step, ddp_name, ddp_step, ddp_bucket_cap, ddp_param_count, ddp_ready_param_count, ddp_reduced_bucket_count, ddp_gradient_synchronized}

func main() int {
    ddp_state state = new_ddp_state("ddp-demo", 32, false)

    println("name: ", ddp_name(state))
    println("bucket_cap: ", ddp_bucket_cap(state))
    println("step: ", ddp_step(state))

    state = ddp_add_param(state, "w1", 128)
    state = ddp_add_param(state, "w2", 64)
    println("param_count: ", ddp_param_count(state))

    state = ddp_mark_grad_ready(state, "w1")
    println("ready_count_after_w1: ", ddp_ready_param_count(state))

    state = ddp_mark_grad_ready(state, "w2")
    state = ddp_reduce_ready_buckets(state, 4)
    println("gradient_synchronized: ", ddp_gradient_synchronized(state))
    println("reduced_bucket_count: ", ddp_reduced_bucket_count(state))

    state = ddp_finalize_step(state)
    println("step_after_finalize: ", ddp_step(state))
    println("ready_count_after_finalize: ", ddp_ready_param_count(state))
    println("gradient_synchronized_after_finalize: ", ddp_gradient_synchronized(state))
    0
}