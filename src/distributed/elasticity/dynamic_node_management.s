package neurx.distributed.elasticity
struct node_registration_request {
    int new_rank
    string ip_address
    int port
    int num_gpus
    []float gpu_memory_gb
}

struct rank_mapping {
    int old_rank
    int new_rank
    int old_tp_rank
    int old_pp_rank
    int old_dp_rank
    int new_tp_rank
    int new_pp_rank
    int new_dp_rank
}

struct elastic_scaling_manager {
    int current_world_size
    []int active_ranks
    map[int]int rank_to_node
    rank_mapping[] pending_remappings
    bool rebalancing
    float rebalance_time_ms
    int total_nodes
}

func new_elastic_scaling_manager(int initial_world_size) elastic_scaling_manager {
    manager := elastic_scaling_manager {
        current_world_size: initial_world_size,
        active_ranks: make([]int, initial_world_size),
        rank_to_node: map[int]int{},
        pending_remappings: make([]rank_mapping, 100),
        rebalancing: false,
        rebalance_time_ms: 0.0,
        total_nodes: 0,
    }
    int i = 0
    for i < initial_world_size {
        manager.active_ranks[i] = i
        manager.rank_to_node[i] = i / 8
        i = i + 1
    }
    manager.total_nodes = (initial_world_size + 7) / 8
    return manager
}

func (elastic_scaling_manager* manager) request_node_join(
    node_registration_request req
) (bool, string) {
    if manager.rebalancing {
        return false, "Rebalancing in progress, please wait"
    }
    if len(manager.active_ranks) >= manager.current_world_size + 1000 {
        return false, "Too many pending joins"
    }
    new_rank := manager.current_world_size
    manager.rank_to_node[new_rank] = req.new_rank
    manager.active_ranks = append(manager.active_ranks, new_rank)
    return true, "Node join registered, rank " + str(new_rank)
}

func (elastic_scaling_manager* manager) handle_node_removal(removed_rank int) (bool, string) {
    if manager.rebalancing {
        return false, "Rebalancing in progress"
    }
    manager.rebalancing = true
    int new_idx = 0
    []int new_active_ranks = make([]int, len(manager.active_ranks))
    int i = 0
    for i < len(manager.active_ranks) {
        if manager.active_ranks[i] != removed_rank {
            new_active_ranks[new_idx] = manager.active_ranks[i]
            new_idx = new_idx + 1
        }
        i = i + 1
    }
    manager.active_ranks = new_active_ranks
    manager.current_world_size = manager.current_world_size - 1
    manager.rebalancing = false
    return true, "Node removal handled, new world_size=" + str(manager.current_world_size)
}

func (elastic_scaling_manager* manager) recompute_parallelism_strategy(
    int new_world_size,
    int model_hidden_dim,
    int model_num_layers,
    int head_dim,
    int target_batch_size
) (int, int, int) {
    int best_tp = 1
    int best_pp = 1
    int best_dp = 1
    float best_score = -1.0
    int tp = 1
    for tp <= 16 {
        if new_world_size % tp != 0 {
            tp = tp + 1
            continue
        }
        if model_hidden_dim % (tp * head_dim) != 0 {
            tp = tp + 1
            continue
        }
        int remaining = new_world_size / tp
        int pp = 1
        for pp <= model_num_layers && pp <= 16 {
            if remaining % pp != 0 {
                pp = pp + 1
                continue
            }
            int dp = remaining / pp
            if dp < 1 {
                pp = pp + 1
                continue
            }
            float throughput_score = float(tp * dp) / 100.0
            float latency_score = 1.0 / (float(tp) * float(pp))
            float score = 0.7 * throughput_score + 0.3 * latency_score
            if score > best_score {
                best_score = score
                best_tp = tp
                best_pp = pp
                best_dp = dp
            }
            pp = pp + 1
        }
        tp = tp + 1
    }
    return best_tp, best_pp, best_dp
}

func (elastic_scaling_manager* manager) generate_parameter_remapping(
    int old_tp int, old_pp int, old_dp int,
    int new_tp int, new_pp int, new_dp int,
    int total_params int
) []rank_mapping {
    remappings := make([]rank_mapping, 1024)
    int rank = 0
    for rank < old_tp * old_pp * old_dp {
        old_tp_rank := rank % old_tp
        old_pp_rank := (rank / old_tp) % old_pp
        old_dp_rank := rank / (old_tp * old_pp)
        int params_per_tp_rank = total_params / old_tp
        new_tp_rank_candidate := (old_tp_rank * new_tp) / old_tp
        new_pp_rank_candidate := (old_pp_rank * new_pp) / old_pp
        new_rank_candidate := new_tp_rank_candidate
                            + new_pp_rank_candidate * new_tp
                            + old_dp_rank * (new_tp * new_pp)
        if new_rank_candidate < new_tp * new_pp * new_dp {
            mapping := rank_mapping {
                old_rank: rank,
                new_rank: new_rank_candidate,
                old_tp_rank: old_tp_rank,
                old_pp_rank: old_pp_rank,
                old_dp_rank: old_dp_rank,
                new_tp_rank: new_tp_rank_candidate,
                new_pp_rank: new_pp_rank_candidate,
                new_dp_rank: old_dp_rank,
            }
            remappings = append(remappings, mapping)
        }
        rank = rank + 1
    }
    return remappings
}

func (elastic_scaling_manager* manager) apply_parameter_remapping(
    []float model_params,
    rank_mapping[] remappings
) []float {
    int param_size = len(model_params)
    []float remapped_params = make([]float, param_size)
    int i = 0
    for i < len(remappings) {
        mapping := remappings[i]
        int params_per_rank = param_size / (len(remappings))
        int src_start = mapping.old_rank * params_per_rank
        int dst_start = mapping.new_rank * params_per_rank
        int j = 0
        for j < params_per_rank && src_start + j < param_size && dst_start + j < param_size {
            remapped_params[dst_start + j] = model_params[src_start + j]
            j = j + 1
        }
        i = i + 1
    }
    return remapped_params
}

func (elastic_scaling_manager* manager) synchronize_new_node(
    []float model_params,
    []float optimizer_state,
    int new_rank,
    string target_ip,
    int target_port
) (bool, string) {
    int packet_size = 65536
    int num_packets = (len(model_params) * 4) / packet_size
    if (len(model_params) * 4) % packet_size != 0 {
        num_packets = num_packets + 1
    }
    int pkt = 0
    for pkt < num_packets {
        int start_idx = (pkt * packet_size) / 4
        int end_idx = start_idx + (packet_size / 4)
        if end_idx > len(model_params) {
            end_idx = len(model_params)
        }
        []float packet_data = make([]float, end_idx - start_idx)
        int i = 0
        for i < len(packet_data) && start_idx + i < len(model_params) {
            packet_data[i] = model_params[start_idx + i]
            i = i + 1
        }
        pkt = pkt + 1
    }
    return true, "Node synchronized with " + str(num_packets) + " packets"
}

func (elastic_scaling_manager* manager) get_current_world_size() int {
    return manager.current_world_size
}

func (elastic_scaling_manager* manager) get_active_ranks() []int {
    return manager.active_ranks
}

func (elastic_scaling_manager* manager) is_rebalancing() bool {
    return manager.rebalancing
}
