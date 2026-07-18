package neurx.moe.trae

import "neurx.util.math"

enum trae_moe_status {
    ROUTING = 0
    FORWARD = 1
    BACKWARD = 2
}

struct trae_moe_config {
    int num_experts
    int expert_dim
    int hidden_dim
    int top_k
    float router_bias
    float load_balance_factor
    float expert_capacity_factor
    float attention_enhancement_factor
    bool use_adaptive_routing
    bool use_attention_gating
    int routing_update_interval
    float temperature
    float entropy_regularization
}

struct trae_router_state {
    []float router_weights
    []float router_biases
    []float expert_load
    []float expert_usage
    int total_routed_tokens
    int routing_step
}

struct attention_gate {
    []float gate_weights
    []float gate_biases
    []float alignment_scores
}

struct trae_moe_layer {
    trae_moe_config config
    trae_router_state router_state
    attention_gate gate
    [][]float expert_weights
    [][]float expert_biases
    []float output_weights
    []float output_biases
}

struct trae_forward_result {
    []float output
    float aux_loss
    float load_balance_metric
    float entropy
    []float expert_activations
}

func new_trae_moe_config() trae_moe_config {
    trae_moe_config {
        num_experts: 128,
        expert_dim: 4096,
        hidden_dim: 8192,
        top_k: 8,
        router_bias: 0.0,
        load_balance_factor: 0.001,
        expert_capacity_factor: 1.25,
        attention_enhancement_factor: 0.1,
        use_adaptive_routing: true,
        use_attention_gating: true,
        routing_update_interval: 100,
        temperature: 1.0,
        entropy_regularization: 0.01,
    }
}

func new_trae_router_state(trae_moe_config config) trae_router_state {
    trae_router_state {
        router_weights: math.allocate_float(config.hidden_dim * config.num_experts, 0.0),
        router_biases: math.allocate_float(config.num_experts, config.router_bias),
        expert_load: math.allocate_float(config.num_experts, 0.0),
        expert_usage: math.allocate_float(config.num_experts, 0.0),
        total_routed_tokens: 0,
        routing_step: 0,
    }
}

func new_attention_gate(trae_moe_config config) attention_gate {
    attention_gate {
        gate_weights: math.allocate_float(config.hidden_dim * config.num_experts, 0.0),
        gate_biases: math.allocate_float(config.num_experts, 0.0),
        alignment_scores: math.allocate_float(config.num_experts, 0.0),
    }
}

func new_trae_moe_layer(trae_moe_config config) trae_moe_layer {
    trae_moe_layer layer {
        config: config,
        router_state: new_trae_router_state(config),
        gate: new_attention_gate(config),
        expert_weights: [][]float{cap: config.num_experts},
        expert_biases: [][]float{cap: config.num_experts},
        output_weights: math.allocate_float(config.hidden_dim * config.hidden_dim, 0.0),
        output_biases: math.allocate_float(config.hidden_dim, 0.0),
    }
    
    int i = 0
    while i < config.num_experts {
        layer.expert_weights.push(math.allocate_float(config.expert_dim * config.hidden_dim, 0.0))
        layer.expert_biases.push(math.allocate_float(config.expert_dim, 0.0))
        i = i + 1
    }
    
    layer
}

func trae_routing(trae_moe_layer layer, []float hidden_states, int batch_size, int seq_len) ([]int, []float, []float) {
    int total_tokens = batch_size * seq_len
    int hidden_dim = layer.config.hidden_dim
    int num_experts = layer.config.num_experts
    int top_k = layer.config.top_k
    
    []float router_logits = math.allocate_float(total_tokens * num_experts, 0.0)
    []float routing_probs = math.allocate_float(total_tokens * num_experts, 0.0)
    []int expert_indices = math.allocate_int(total_tokens * top_k, -1)
    []float routing_weights = math.allocate_float(total_tokens * top_k, 0.0)
    
    int token_idx = 0
    while token_idx < total_tokens {
        float[] token_hidden = hidden_states[token_idx * hidden_dim..(token_idx+1) * hidden_dim]
        
        int expert_idx = 0
        while expert_idx < num_experts {
            float logit = layer.router_state.router_biases[expert_idx]
            
            int d = 0
            while d < hidden_dim {
                logit = logit + token_hidden[d] * layer.router_state.router_weights[d * num_experts + expert_idx]
                d = d + 1
            }
            
            router_logits[token_idx * num_experts + expert_idx] = logit
            expert_idx = expert_idx + 1
        }
        
        if layer.config.use_attention_gating {
            expert_idx = 0
            while expert_idx < num_experts {
                float gate_score = layer.gate.gate_biases[expert_idx]
                
                int d = 0
                while d < hidden_dim {
                    gate_score = gate_score + token_hidden[d] * layer.gate.gate_weights[d * num_experts + expert_idx]
                    d = d + 1
                }
                
                router_logits[token_idx * num_experts + expert_idx] = router_logits[token_idx * num_experts + expert_idx] + 
                                                                    layer.config.attention_enhancement_factor * gate_score
                expert_idx = expert_idx + 1
            }
        }
        
        if layer.config.temperature > 0 {
            float temp = layer.config.temperature
            expert_idx = 0
            while expert_idx < num_experts {
                router_logits[token_idx * num_experts + expert_idx] = router_logits[token_idx * num_experts + expert_idx] / temp
                expert_idx = expert_idx + 1
            }
        }
        
        float[] logit_slice = router_logits[token_idx * num_experts..(token_idx+1) * num_experts]
        routing_probs[token_idx * num_experts..(token_idx+1) * num_experts] = math.softmax_1d(logit_slice)
        
        float[] prob_slice = routing_probs[token_idx * num_experts..(token_idx+1) * num_experts]
        ([]int top_indices, []float top_probs) = math.top_k_select(prob_slice, num_experts, top_k)
        
        int k = 0
        while k < top_k {
            expert_indices[token_idx * top_k + k] = top_indices[k]
            routing_weights[token_idx * top_k + k] = top_probs[k]
            k = k + 1
        }
        
        token_idx = token_idx + 1
    }
    
    layer.router_state.total_routed_tokens = layer.router_state.total_routed_tokens + total_tokens
    layer.router_state.routing_step = layer.router_state.routing_step + 1
    
    (expert_indices, routing_weights, routing_probs)
}

func adaptive_routing_update(trae_moe_layer layer) trae_moe_layer {
    if !layer.config.use_adaptive_routing {
        return layer
    }
    
    if layer.router_state.routing_step % layer.config.routing_update_interval != 0 {
        return layer
    }
    
    int num_experts = layer.config.num_experts
    float target_load = float(layer.router_state.total_routed_tokens) / float(num_experts)
    
    int i = 0
    while i < num_experts {
        float load_diff = layer.router_state.expert_load[i] - target_load
        float adjustment = -load_diff * 0.01
        
        layer.router_state.router_biases[i] = layer.router_state.router_biases[i] + adjustment
        
        layer.router_state.router_biases[i] = math.clamp_float(layer.router_state.router_biases[i], -1.0, 1.0)
        
        layer.router_state.expert_usage[i] = layer.router_state.expert_load[i] / target_load
        
        i = i + 1
    }
    
    layer.router_state.total_routed_tokens = 0
    
    layer
}

func compute_load_balance_metric([]float expert_load, int num_experts) float {
    float mean_load = math.mean_float(expert_load)
    
    float variance = 0.0
    int i = 0
    while i < num_experts {
        variance = variance + (expert_load[i] - mean_load) * (expert_load[i] - mean_load)
        i = i + 1
    }
    variance = variance / float(num_experts)
    
    float std_dev = math.sqrt_approx(variance)
    float cv = std_dev / mean_load
    
    1.0 - cv
}

func trae_moe_forward(trae_moe_layer layer, []float hidden_states, int batch_size, int seq_len) trae_forward_result {
    int total_tokens = batch_size * seq_len
    int hidden_dim = layer.config.hidden_dim
    int expert_dim = layer.config.expert_dim
    int num_experts = layer.config.num_experts
    int top_k = layer.config.top_k
    
    ([]int expert_indices, []float routing_weights, []float routing_probs) = trae_routing(layer, hidden_states, batch_size, seq_len)
    
    []float expert_inputs = math.allocate_float(num_experts * expert_dim, 0.0)
    []float expert_outputs = math.allocate_float(num_experts * expert_dim, 0.0)
    []float expert_scales = math.allocate_float(num_experts, 0.0)
    
    int token_idx = 0
    while token_idx < total_tokens {
        int k = 0
        while k < top_k {
            int expert_idx = expert_indices[token_idx * top_k + k]
            float weight = routing_weights[token_idx * top_k + k]
            
            if expert_idx >= 0 && expert_idx < num_experts {
                layer.router_state.expert_load[expert_idx] = layer.router_state.expert_load[expert_idx] + 1.0
                
                int d = 0
                while d < expert_dim {
                    expert_inputs[expert_idx * expert_dim + d] = expert_inputs[expert_idx * expert_dim + d] + 
                                                               hidden_states[token_idx * hidden_dim + d] * weight
                    d = d + 1
                }
                
                expert_scales[expert_idx] = expert_scales[expert_idx] + weight
            }
            
            k = k + 1
        }
        token_idx = token_idx + 1
    }
    
    int expert_idx = 0
    while expert_idx < num_experts {
        if expert_scales[expert_idx] > 0.0 {
            int d = 0
            while d < expert_dim {
                expert_inputs[expert_idx * expert_dim + d] = expert_inputs[expert_idx * expert_dim + d] / expert_scales[expert_idx]
                d = d + 1
            }
            
            float[] input_slice = expert_inputs[expert_idx * expert_dim..(expert_idx+1) * expert_dim]
            expert_outputs[expert_idx * expert_dim..(expert_idx+1) * expert_dim] = expert_forward(
                layer.expert_weights[expert_idx],
                layer.expert_biases[expert_idx],
                input_slice,
                hidden_dim,
                expert_dim
            )
        }
        expert_idx = expert_idx + 1
    }
    
    []float output = math.allocate_float(total_tokens * hidden_dim, 0.0)
    
    token_idx = 0
    while token_idx < total_tokens {
        int k = 0
        while k < top_k {
            int expert_idx = expert_indices[token_idx * top_k + k]
            float weight = routing_weights[token_idx * top_k + k]
            
            if expert_idx >= 0 && expert_idx < num_experts && expert_scales[expert_idx] > 0.0 {
                int d = 0
                while d < expert_dim {
                    output[token_idx * hidden_dim + d] = output[token_idx * hidden_dim + d] + 
                                                         expert_outputs[expert_idx * expert_dim + d] * weight
                    d = d + 1
                }
            }
            
            k = k + 1
        }
        token_idx = token_idx + 1
    }
    
    output = math.matmul_flat(output, layer.output_weights, total_tokens, hidden_dim, hidden_dim)
    output = math.apply_bias(output, layer.output_biases, total_tokens, hidden_dim)
    
    float load_balance_metric = compute_load_balance_metric(layer.router_state.expert_load, num_experts)
    float avg_entropy = 0.0
    token_idx = 0
    while token_idx < total_tokens {
        float[] prob_slice = routing_probs[token_idx * num_experts..(token_idx+1) * num_experts]
        avg_entropy = avg_entropy + math.compute_entropy(prob_slice, num_experts)
        token_idx = token_idx + 1
    }
    avg_entropy = avg_entropy / float(total_tokens)
    
    float aux_loss = (1.0 - load_balance_metric) * layer.config.load_balance_factor - 
                     avg_entropy * layer.config.entropy_regularization
    
    layer = adaptive_routing_update(layer)
    
    trae_forward_result {
        output: output,
        aux_loss: aux_loss,
        load_balance_metric: load_balance_metric,
        entropy: avg_entropy,
        expert_activations: expert_scales,
    }
}

func expert_forward([]float weights, []float biases, []float input, int in_dim, int out_dim) []float {
    []float hidden = math.allocate_float(out_dim, 0.0)
    
    int i = 0
    while i < out_dim {
        hidden[i] = biases[i]
        int j = 0
        while j < in_dim {
            hidden[i] = hidden[i] + input[j] * weights[j * out_dim + i]
            j = j + 1
        }
        hidden[i] = math.gelu_approx(hidden[i])
        i = i + 1
    }
    
    hidden
}

func trae_moe_backward(trae_moe_layer layer, []float grad_output, []float hidden_states, 
                       int batch_size, int seq_len) []float {
    int total_tokens = batch_size * seq_len
    int hidden_dim = layer.config.hidden_dim
    
    []float grad_input = math.allocate_float(total_tokens * hidden_dim, 0.0)
    
    grad_input
}

func trae_moe_compute_aux_loss(trae_moe_layer layer) float {
    int num_experts = layer.config.num_experts
    float total_load = math.sum_float(layer.router_state.expert_load)
    
    float target_load = total_load / float(num_experts)
    float aux_loss = 0.0
    
    int i = 0
    while i < num_experts {
        float diff = layer.router_state.expert_load[i] - target_load
        aux_loss = aux_loss + diff * diff
        i = i + 1
    }
    
    aux_loss / float(num_experts) * layer.config.load_balance_factor
}

func trae_moe_get_load_balance(trae_moe_layer layer) float {
    compute_load_balance_metric(layer.router_state.expert_load, layer.config.num_experts)
}

func trae_moe_reset_load_stats(trae_moe_layer layer) trae_moe_layer {
    int i = 0
    while i < layer.config.num_experts {
        layer.router_state.expert_load[i] = 0.0
        i = i + 1
    }
    layer.router_state.total_routed_tokens = 0
    layer
}
