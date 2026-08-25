package neurx.moe.expert_routing

struct expert_layer {
    int expert_id
    int hidden_dim
    int output_dim
    bool available
}

struct moe_config {
    int num_experts
    int num_experts_per_token
    float expert_load_threshold
    string routing_policy
}

struct routing_decision {
    []int expert_indices
    []float routing_weights
}

struct expert_load_stats {
    []int expert_token_counts
    []float expert_load_factors
    float load_balance_loss
}

struct moe_layer {
    []expert_layer experts
    moe_config config
    expert_load_stats load_stats
}

func new_moe_config(
    int num_experts,
    int num_experts_per_token,
) moe_config {
    moe_config{
        num_experts: num_experts,
        num_experts_per_token: num_experts_per_token,
        expert_load_threshold: 1.5,
        routing_policy: "top_k",
    }
}

func new_moe_layer(moe_config config, int hidden_dim) moe_layer {
    experts := []expert_layer{}
    i := 0
    for i < config.num_experts {
        expert := expert_layer{
            expert_id: i,
            hidden_dim: hidden_dim,
            output_dim: hidden_dim,
            available: true,
        }
        experts = append_expert(experts, expert)
        i = i + 1
    }
    load_stats := expert_load_stats{
        expert_token_counts: make_int_array(config.num_experts),
        expert_load_factors: make_float_array(config.num_experts),
        load_balance_loss: 0.0,
    }
    moe_layer{
        experts: experts,
        config: config,
        load_stats: load_stats,
    }
}

func route_token_top_k(
    moe_layer layer,
    []float token_embedding,
) routing_decision {
    num_experts_per_token := layer.config.num_experts_per_token
    num_experts := layer.config.num_experts
    routing_logits := []float{}
    i := 0
    for i < num_experts {
        logit := compute_routing_logit(token_embedding, i)
        routing_logits = append_float(routing_logits, logit)
        i = i + 1
    }
    expert_indices := []int{}
    weights := []float{}
    j := 0
    for j < num_experts_per_token {
        max_idx := 0
        max_val := routing_logits[0]
        k := 1
        for k < routing_logits.len {
            if routing_logits[k] > max_val {
                max_val = routing_logits[k]
                max_idx = k
            }
            k = k + 1
        }
        expert_indices = append_int(expert_indices, max_idx)
        weights = append_float(weights, max_val)
        routing_logits[max_idx] = -1000.0
        j = j + 1
    }
    normalize_routing_weights(weights)
    routing_decision{
        expert_indices: expert_indices,
        routing_weights: weights,
    }
}

func route_token_random(
    moe_layer layer,
    []float token_embedding,
) routing_decision {
    num_experts_per_token := layer.config.num_experts_per_token
    num_experts := layer.config.num_experts
    expert_indices := []int{}
    weights := []float{}
    i := 0
    for i < num_experts_per_token {
        expert_id := i % num_experts
        expert_indices = append_int(expert_indices, expert_id)
        weight := 1.0 / float(num_experts_per_token)
        weights = append_float(weights, weight)
        i = i + 1
    }
    routing_decision{
        expert_indices: expert_indices,
        routing_weights: weights,
    }
}

func update_expert_load(
    moe_layer layer,
    routing_decision routing,
) moe_layer {
    i := 0
    for i < routing.expert_indices.len {
        expert_id := routing.expert_indices[i]
        if expert_id < layer.load_stats.expert_token_counts.len {
            layer.load_stats.expert_token_counts[expert_id] = layer.load_stats.expert_token_counts[expert_id] + 1
        }
        i = i + 1
    }
    layer
}

func compute_load_balance_loss(moe_layer layer) float {
    total_tokens := 0
    i := 0
    for i < layer.load_stats.expert_token_counts.len {
        total_tokens = total_tokens + layer.load_stats.expert_token_counts[i]
        i = i + 1
    }
    if total_tokens == 0 {
        return 0.0
    }
    mean_load := float(total_tokens) / float(layer.load_stats.expert_token_counts.len)
    loss := 0.0
    i = 0
    for i < layer.load_stats.expert_token_counts.len {
        diff := float(layer.load_stats.expert_token_counts[i]) - mean_load
        loss = loss + diff * diff
        i = i + 1
    }
    loss / float(total_tokens)
}

func check_expert_overload(moe_layer layer) []int {
    overloaded := []int{}
    mean_load := 0.0
    i := 0
    for i < layer.load_stats.expert_token_counts.len {
        mean_load = mean_load + float(layer.load_stats.expert_token_counts[i])
        i = i + 1
    }
    mean_load = mean_load / float(layer.load_stats.expert_token_counts.len)
    threshold := mean_load * layer.config.expert_load_threshold
    i = 0
    for i < layer.load_stats.expert_token_counts.len {
        if float(layer.load_stats.expert_token_counts[i]) > threshold {
            overloaded = append_int(overloaded, i)
        }
        i = i + 1
    }
    overloaded
}

func rebalance_expert_load(moe_layer layer) moe_layer {
    overloaded := check_expert_overload(layer)
    if overloaded.len > 0 {
        i := 0
        for i < layer.load_stats.expert_token_counts.len {
            layer.load_stats.expert_token_counts[i] = 0
            i = i + 1
        }
    }
    layer
}

func get_expert_throughput(moe_layer layer) []float {
    throughputs := []float{}
    max_load := 0.0
    i := 0
    for i < layer.load_stats.expert_token_counts.len {
        if float(layer.load_stats.expert_token_counts[i]) > max_load {
            max_load = float(layer.load_stats.expert_token_counts[i])
        }
        i = i + 1
    }
    if max_load == 0.0 {
        max_load = 1.0
    }
    i = 0
    for i < layer.load_stats.expert_token_counts.len {
        throughput := float(layer.load_stats.expert_token_counts[i]) / max_load
        throughputs = append_float(throughputs, throughput)
        i = i + 1
    }
    throughputs
}

func compute_routing_logit([]float embedding, int expert_id) float {
    logit := 0.0
    i := 0
    for i < embedding.len {
        logit = logit + embedding[i] * float(expert_id + 1)
        i = i + 1
    }
    logit
}

func normalize_routing_weights([]float weights) []float {
    total := 0.0
    i := 0
    for i < weights.len {
        total = total + weights[i]
        i = i + 1
    }
    if total > 0.0 {
        i = 0
        for i < weights.len {
            weights[i] = weights[i] / total
            i = i + 1
        }
    }
    weights
}

func append_expert([]expert_layer slice, expert_layer elem) []expert_layer {
    new_slice := []expert_layer{}
    i := 0
    for i < slice.len {
        new_slice = append_expert(new_slice, slice[i])
        i = i + 1
    }
    new_slice = append_expert(new_slice, elem)
    new_slice
}

func append_float([]float slice, float elem) []float {
    new_slice := []float{}
    i := 0
    for i < slice.len {
        new_slice = append_float(new_slice, slice[i])
        i = i + 1
    }
    new_slice = append_float(new_slice, elem)
    new_slice
}

func append_int([]int slice, int elem) []int {
    new_slice := []int{}
    i := 0
    for i < slice.len {
        new_slice = append_int(new_slice, slice[i])
        i = i + 1
    }
    new_slice = append_int(new_slice, elem)
    new_slice
}

func make_int_array(int len) []int {
    arr := []int{}
    i := 0
    for i < len {
        arr = append_int(arr, 0)
        i = i + 1
    }
    arr
}

func make_float_array(int len) []float {
    arr := []float{}
    i := 0
    for i < len {
        arr = append_float(arr, 0.0)
        i = i + 1
    }
    arr
}
