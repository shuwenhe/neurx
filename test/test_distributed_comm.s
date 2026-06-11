package neurx.test_distributed_comm

use neurx.distributed.comm.{process_group_state, new_process_group, process_group_rank, process_group_world_size, process_group_initialized, process_group_last_peer, process_group_last_payload, process_group_send_count, process_group_recv_count, process_group_is_ready, process_group_reset, broadcast, all_reduce_sum, all_reduce_mean, all_reduce_max, all_reduce_min, all_reduce_prod, all_gather, all_to_all, reduce_scatter_sum, p2p_send, p2p_recv, destroy_process_group}

func main() int {
    process_group_state state = new_process_group("gloo", 1, 4)

    println("rank: ", process_group_rank(state))
    println("world_size: ", process_group_world_size(state))
    println("initialized: ", process_group_initialized(state))
    println("is_ready: ", process_group_is_ready(state))

    []float broadcast_out = broadcast(state, 0, [9.0, 8.0])
    []float sum_out = all_reduce_sum(state, [1.0, 2.0])
    []float mean_out = all_reduce_mean(state, [1.0, 2.0])
    []float max_out = all_reduce_max(state, [1.0, 2.0])
    []float min_out = all_reduce_min(state, [1.0, 2.0])
    []float prod_out = all_reduce_prod(state, [1.0, 2.0])
    []float gather_out = all_gather(state, [1.0, 2.0])
    []float all_to_all_out = all_to_all(state, [1.0, 2.0, 3.0, 4.0])
    []float scatter_out = reduce_scatter_sum(state, [1.0, 2.0, 3.0, 4.0])

    println("broadcast: ", broadcast_out)
    println("all_reduce_sum: ", sum_out)
    println("all_reduce_mean: ", mean_out)
    println("all_reduce_max: ", max_out)
    println("all_reduce_min: ", min_out)
    println("all_reduce_prod: ", prod_out)
    println("all_gather: ", gather_out)
    println("all_to_all: ", all_to_all_out)
    println("reduce_scatter_sum: ", scatter_out)

    state = p2p_send(state, 2, [3.0, 5.0, 7.0])
    []float recv_out = p2p_recv(state, 2, 2)
    println("p2p_recv: ", recv_out)
    println("last_peer: ", process_group_last_peer(state))
    println("last_payload: ", process_group_last_payload(state))
    println("send_count: ", process_group_send_count(state))
    println("recv_count: ", process_group_recv_count(state))

    state = process_group_reset(state)
    println("send_count_after_reset: ", process_group_send_count(state))
    println("recv_count_after_reset: ", process_group_recv_count(state))

    state = destroy_process_group(state)
    println("initialized_after_destroy: ", process_group_initialized(state))
    0
}
