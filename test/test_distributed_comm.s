package neurx.test_distributed_comm

use neurx.distributed.comm.{process_group_state, new_process_group, process_group_rank, process_group_world_size, process_group_initialized, all_reduce_sum, all_reduce_mean, all_gather, reduce_scatter_sum, p2p_send, p2p_recv, destroy_process_group}

func main() int {
    process_group_state state = new_process_group("gloo", 1, 4)

    println("rank: ", process_group_rank(state))
    println("world_size: ", process_group_world_size(state))
    println("initialized: ", process_group_initialized(state))

    []float sum_out = all_reduce_sum(state, [1.0, 2.0])
    []float mean_out = all_reduce_mean(state, [1.0, 2.0])
    []float gather_out = all_gather(state, [1.0, 2.0])
    []float scatter_out = reduce_scatter_sum(state, [1.0, 2.0, 3.0, 4.0])

    println("all_reduce_sum: ", sum_out)
    println("all_reduce_mean: ", mean_out)
    println("all_gather: ", gather_out)
    println("reduce_scatter_sum: ", scatter_out)

    state = p2p_send(state, 2, [3.0, 5.0, 7.0])
    []float recv_out = p2p_recv(state, 2, 2)
    println("p2p_recv: ", recv_out)

    state = destroy_process_group(state)
    println("initialized_after_destroy: ", process_group_initialized(state))
    0
}