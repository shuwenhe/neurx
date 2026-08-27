package neurx.posttrain.lora.lora_layer
use neurx.posttrain.model.model_loader.{fill_model_tensor}

struct lora_linear {
    []float base_weight
    []float lora_a
    []float lora_b
    int in_dim
    int out_dim
    int rank
    float alpha
    float scaling
    float dropout_rate
}

struct lora_adapter {
    []lora_linear q_proj_lora
    []lora_linear k_proj_lora
    []lora_linear v_proj_lora
    []lora_linear o_proj_lora
    []lora_linear gate_proj_lora
    []lora_linear up_proj_lora
    []lora_linear down_proj_lora
    int num_layers
    int rank
    float alpha
    int hidden_size
    int intermediate_size
}

struct lora_config {
    int rank
    float alpha
    float dropout_rate
    []string target_modules
}

func create_lora_linear(int in_dim, int out_dim, int rank, float alpha, float dropout_rate) lora_linear {
    lora_linear layer
    layer.in_dim = in_dim
    layer.out_dim = out_dim
    layer.rank = rank
    layer.alpha = alpha
    layer.scaling = alpha / ((rank as float))
    layer.dropout_rate = dropout_rate
    layer.base_weight = fill_model_tensor(out_dim * in_dim, 0.0)
    layer.lora_a = fill_model_tensor(rank * in_dim, 0.01)
    layer.lora_b = fill_model_tensor(out_dim * rank, 0.0)
    return layer
}

func lora_linear_forward(lora_linear layer, []float input) []float {
    []float output = fill_model_tensor(layer.out_dim, 0.0)
    int out_idx = 0
    for out_idx < layer.out_dim {
        float sum = 0.0
        int in_idx = 0
        for in_idx < layer.in_dim && in_idx < len(input) {
            int w_idx = out_idx * layer.in_dim + in_idx
            if w_idx < len(layer.base_weight) {
                sum = sum + input[in_idx] * layer.base_weight[w_idx]
            }
            in_idx = in_idx + 1
        }
        int r = 0
        for r < layer.rank {
            float lora_out = 0.0
            int in_idx = 0
            for in_idx < layer.in_dim && in_idx < len(input) {
                int a_idx = r * layer.in_dim + in_idx
                if a_idx < len(layer.lora_a) {
                    lora_out = lora_out + input[in_idx] * layer.lora_a[a_idx]
                }
                in_idx = in_idx + 1
            }
            int b_idx = out_idx * layer.rank + r
            if b_idx < len(layer.lora_b) {
                sum = sum + lora_out * layer.lora_b[b_idx] * layer.scaling
            }
            r = r + 1
        }
        output[out_idx] = sum
        out_idx = out_idx + 1
    }
    return output
}

func lora_linear_backward(lora_linear layer, []float input, []float grad_output) float {
    float loss = 0.0
    int out_idx = 0
    for out_idx < len(grad_output) {
        loss = loss + grad_output[out_idx] * grad_output[out_idx]
        out_idx = out_idx + 1
    }
    return loss
}

func update_lora_weights(lora_linear layer, []float gradients, float learning_rate) lora_linear {
    int i = 0
    for i < len(layer.lora_a) && i < len(gradients) {
        layer.lora_a[i] = layer.lora_a[i] - learning_rate * gradients[i]
        i = i + 1
    }
    i = 0
    for i < len(layer.lora_b) && i < len(gradients) {
        int offset = len(layer.lora_a)
        if offset + i < len(gradients) {
            layer.lora_b[i] = layer.lora_b[i] - learning_rate * gradients[offset + i]
        }
        i = i + 1
    }
    return layer
}

func create_lora_adapter(int num_layers, int hidden_size, int intermediate_size, int rank, float alpha, float dropout_rate) lora_adapter {
    lora_adapter adapter
    adapter.num_layers = num_layers
    adapter.rank = rank
    adapter.alpha = alpha
    adapter.hidden_size = hidden_size
    adapter.intermediate_size = intermediate_size
    adapter.q_proj_lora = []lora_linear{}
    adapter.k_proj_lora = []lora_linear{}
    adapter.v_proj_lora = []lora_linear{}
    adapter.o_proj_lora = []lora_linear{}
    adapter.gate_proj_lora = []lora_linear{}
    adapter.up_proj_lora = []lora_linear{}
    adapter.down_proj_lora = []lora_linear{}
    int i = 0
    for i < num_layers {
        adapter.q_proj_lora = append(adapter.q_proj_lora, create_lora_linear(hidden_size, hidden_size, rank, alpha, dropout_rate))
        adapter.k_proj_lora = append(adapter.k_proj_lora, create_lora_linear(hidden_size, hidden_size, rank, alpha, dropout_rate))
        adapter.v_proj_lora = append(adapter.v_proj_lora, create_lora_linear(hidden_size, hidden_size, rank, alpha, dropout_rate))
        adapter.o_proj_lora = append(adapter.o_proj_lora, create_lora_linear(hidden_size, hidden_size, rank, alpha, dropout_rate))
        adapter.gate_proj_lora = append(adapter.gate_proj_lora, create_lora_linear(hidden_size, intermediate_size, rank, alpha, dropout_rate))
        adapter.up_proj_lora = append(adapter.up_proj_lora, create_lora_linear(hidden_size, intermediate_size, rank, alpha, dropout_rate))
        adapter.down_proj_lora = append(adapter.down_proj_lora, create_lora_linear(intermediate_size, hidden_size, rank, alpha, dropout_rate))
        i = i + 1
    }
    return adapter
}

func get_total_lora_params(lora_adapter adapter) int {
    int total = 0
    int i = 0
    for i < len(adapter.q_proj_lora) {
        total = total + adapter.q_proj_lora[i].rank * adapter.q_proj_lora[i].in_dim
        total = total + adapter.q_proj_lora[i].out_dim * adapter.q_proj_lora[i].rank
        i = i + 1
    }
    i = 0
    for i < len(adapter.v_proj_lora) {
        total = total + adapter.v_proj_lora[i].rank * adapter.v_proj_lora[i].in_dim
        total = total + adapter.v_proj_lora[i].out_dim * adapter.v_proj_lora[i].rank
        i = i + 1
    }
    return total
}

func lora_adapter_forward(lora_adapter adapter, int layer_idx, []float hidden_state, string module_name) []float {
    if layer_idx < 0 || layer_idx >= adapter.num_layers {
        return hidden_state
    }
    if module_name == "q_proj" && layer_idx < len(adapter.q_proj_lora) {
        return lora_linear_forward(adapter.q_proj_lora[layer_idx], hidden_state)
    }
    if module_name == "k_proj" && layer_idx < len(adapter.k_proj_lora) {
        return lora_linear_forward(adapter.k_proj_lora[layer_idx], hidden_state)
    }
    if module_name == "v_proj" && layer_idx < len(adapter.v_proj_lora) {
        return lora_linear_forward(adapter.v_proj_lora[layer_idx], hidden_state)
    }
    if module_name == "o_proj" && layer_idx < len(adapter.o_proj_lora) {
        return lora_linear_forward(adapter.o_proj_lora[layer_idx], hidden_state)
    }
    return hidden_state
}
