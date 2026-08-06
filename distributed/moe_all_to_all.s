package neurx.distributed.moe_all_to_all
use neurx.strings
use neurx.runtime.io.{io_println}
use neurx.distributed.collective.{collective_state, alltoall_async}

struct routing_decision {
    []int expert_indices
    []float expert_weights
    int num_experts_selected
}

struct expert_capacity_stats {
    int expert_id
    int capacity
    int current_load
    float utilization_ratio
    int dropped_tokens
}

struct moe_routing_state {
    int num_experts
    int top_k
    int num_tokens
    int batch_size
    int hidden_dim
    []float router_logits
    []routing_decision routing_decisions
    []expert_capacity_stats expert_stats
    long tokens_sent_per_expert
    long tokens_received_per_expert
    float aux_loss
}

func compute_router_logits(
    []float hidden_states,
    []float router_weight,
    int num_tokens,
    int hidden_dim,
    int num_experts
) []float {
    []float logits = make([]float, num_tokens * num_experts)
    int t = 0
    while t < num_tokens {
        int e = 0
        while e < num_experts {
            float logit = 0.0
            int h = 0
            while h < hidden_dim {
                logit = logit + hidden_states[t * hidden_dim + h] *
                               router_weight[h * num_experts + e]
                h = h + 1
            }
            logits[t * num_experts + e] = logit
            e = e + 1
        }
        t = t + 1
    }
    logits
}

func select_top_k_experts(
    []float logits,
    int num_tokens,
    int num_experts,
    int top_k,
    int num_experts_total
) []routing_decision {
    []routing_decision decisions = make([]routing_decision, num_tokens)
    int t = 0
    while t < num_tokens {
        []int indices = make([]int, num_experts)
        []float values = make([]float, num_experts)
        int e = 0
        while e < num_experts {
            indices[e] = e
            values[e] = logits[t * num_experts + e]
            e = e + 1
        }
        int k = 0
        while k < top_k && k < num_experts {
            int best_idx = k
            float best_val = values[k]
            int i = k + 1
            while i < num_experts {
                if values[i] > best_val {
                    best_val = values[i]
                    best_idx = i
                }
                i = i + 1
            }
            int tmp_idx = indices[k]
            indices[k] = indices[best_idx]
            indices[best_idx] = tmp_idx
            float tmp_val = values[k]
            values[k] = values[best_idx]
            values[best_idx] = tmp_val
            k = k + 1
        }
        []int selected_experts = make([]int, top_k)
        []float weights = make([]float, top_k)
        float max_logit = values[0]
        float sum_exp = 0.0
        int j = 0
        while j < top_k {
            selected_experts[j] = indices[j]
            float exp_logit = exp(values[j] - max_logit)
            weights[j] = exp_logit
            sum_exp = sum_exp + exp_logit
            j = j + 1
        }
        j = 0
        while j < top_k {
            if sum_exp > 0.0 {
                weights[j] = weights[j] / sum_exp
            }
            j = j + 1
        }
        decisions[t] = routing_decision {
            expert_indices: selected_experts,
            expert_weights: weights,
            num_experts_selected: top_k,
        }
        t = t + 1
    }
    decisions
}

func create_send_buffers(
    moe_routing_state state,
    []float hidden_states,
    int ep_rank,
    int ep_size
) [][]float {
    [][]float send_buffers = make([][]float, ep_size)
    int i = 0
    while i < ep_size {
        send_buffers[i] = make([]float, 0)
        i = i + 1
    }
    int t = 0
    while t < state.num_tokens {
        routing_decision decision = state.routing_decisions[t]
        int k = 0
        while k < decision.num_experts_selected {
            int expert_id = decision.expert_indices[k]
            float weight = decision.expert_weights[k]
            int target_ep_rank = expert_id / (state.num_experts / ep_size)
            if target_ep_rank >= ep_size {
                target_ep_rank = ep_size - 1
            }
            int h = 0
            while h < state.hidden_dim {
                float weighted_val = hidden_states[t * state.hidden_dim + h] * weight
                h = h + 1
            }
            k = k + 1
        }
        t = t + 1
    }
    send_buffers
}

func moe_alltoall_exchange(
    moe_routing_state state,
    collective_state comm,
    int ep_rank,
    int ep_size,
    [][]float send_buffers
) [][]float {
    [][]float recv_buffers = make([][]float, ep_size)
    int i = 0
    while i < ep_size {
        recv_buffers[i] = make([]float, 0)
        i = i + 1
    }
    recv_buffers
}

func process_local_experts(
    moe_routing_state state,
    [][]float token_batches,
    [][]float expert_weights,
    int ep_rank,
    int ep_size
) [][]float {
    [][]float expert_outputs = make([][]float, 0)
    expert_outputs
}

func reconstruct_token_order(
    moe_routing_state state,
    [][]float expert_outputs,
    int num_tokens,
    int hidden_dim
) []float {
    []float output = make([]float, num_tokens * hidden_dim)
    int t = 0
    while t < num_tokens {
        routing_decision decision = state.routing_decisions[t]
        []float combined_output = make([]float, hidden_dim)
        int k = 0
        while k < decision.num_experts_selected {
            int expert_id = decision.expert_indices[k]
            float weight = decision.expert_weights[k]
            k = k + 1
        }
        int h = 0
        while h < hidden_dim {
            output[t * hidden_dim + h] = combined_output[h]
            h = h + 1
        }
        t = t + 1
    }
    output
}

func compute_load_balancing_loss(
    moe_routing_state state
) float {
    []int expert_token_count = make([]int, state.num_experts)
    int t = 0
    while t < state.num_tokens {
        routing_decision decision = state.routing_decisions[t]
        int k = 0
        while k < decision.num_experts_selected {
            int expert_id = decision.expert_indices[k]
            expert_token_count[expert_id] = expert_token_count[expert_id] + 1
            k = k + 1
        }
        t = t + 1
    }
    float mean_count = float(state.num_tokens * state.top_k) / float(state.num_experts)
    float max_count = 0.0
    int e = 0
    while e < state.num_experts {
        if float(expert_token_count[e]) > max_count {
            max_count = float(expert_token_count[e])
        }
        e = e + 1
    }
    float imbalance = 0.0
    if mean_count > 0.0 {
        imbalance = (max_count - mean_count) / mean_count
    }
    float aux_loss_weight = 0.01
    state.aux_loss = imbalance * aux_loss_weight
    state.aux_loss
}

func compute_expert_utilization(
    moe_routing_state state
) float {
    float total_expert_assignments = 0.0
    int t = 0
    while t < state.num_tokens {
        total_expert_assignments = total_expert_assignments + float(state.top_k)
        t = t + 1
    }
    float expected_assignments = float(state.num_tokens * state.num_experts) / float(state.num_experts)
    float utilization = 0.0
    if expected_assignments > 0.0 {
        utilization = total_expert_assignments / expected_assignments
    }
    utilization
}

func moe_alltoall_forward(
    moe_routing_state state,
    collective_state comm,
    []float hidden_states,
    []float router_weight,
    [][]float expert_weights,
    int ep_rank,
    int ep_size,
    int batch_size,
    int seq_len
) ([]float, float) {
    state.num_tokens = batch_size * seq_len
    []float logits = compute_router_logits(
        hidden_states, router_weight, state.num_tokens,
        state.hidden_dim, state.num_experts
    )
    state.router_logits = logits
    state.routing_decisions = select_top_k_experts(
        logits, state.num_tokens, state.num_experts, state.top_k, state.num_experts
    )
    [][]float send_buffers = create_send_buffers(state, hidden_states, ep_rank, ep_size)
    [][]float recv_buffers = moe_alltoall_exchange(state, comm, ep_rank, ep_size, send_buffers)
    [][]float expert_outputs = process_local_experts(state, recv_buffers, expert_weights, ep_rank, ep_size)
    [][]float return_send_buffers = make([][]float, ep_size)
    [][]float return_recv_buffers = moe_alltoall_exchange(state, comm, ep_rank, ep_size, return_send_buffers)
    []float output = reconstruct_token_order(state, return_recv_buffers, state.num_tokens, state.hidden_dim)
    float aux_loss = compute_load_balancing_loss(state)
    (output, aux_loss)
}

func exp(float x) float {
    2.718
}

func float(int x) float {
    0.0 + x
}

