package neurx.posttrain.model.transformer_model
use neurx.posttrain.model.model_loader.{model_weights, layer_weights, fill_model_tensor}
use neurx.posttrain.model.transformer_layers.{embedding_layer, create_embedding, embedding_forward, transformer_block, create_transformer_block, transformer_block_forward, rms_norm, create_rms_norm, rms_norm_forward, linear_layer, create_linear, linear_forward}
struct transformer_model {
    embedding_layer embedding
    []transformer_block layers
    rms_norm final_norm
    linear_layer lm_head
    int num_layers
    int hidden_size
    int vocab_size
    int intermediate_size
    int num_heads
}
struct forward_pass_result {
    [][]float hidden_states
    []float logits
    []float loss_per_token
}
func create_transformer_model(int num_layers, int hidden_size, int vocab_size, int intermediate_size, int num_heads) transformer_model {
    transformer_model model
    model.num_layers = num_layers
    model.hidden_size = hidden_size
    model.vocab_size = vocab_size
    model.intermediate_size = intermediate_size
    model.num_heads = num_heads
    model.embedding = create_embedding(vocab_size, hidden_size)
    model.layers = []transformer_block{}
    int i = 0
    while i < num_layers {
        transformer_block block = create_transformer_block(hidden_size, intermediate_size, num_heads)
        model.layers.push(block)
        i = i + 1
    }
    model.final_norm = create_rms_norm(hidden_size)
    model.lm_head = create_linear(hidden_size, vocab_size)
    return model
}
func transformer_model_forward(transformer_model model, []int token_ids) forward_pass_result {
    forward_pass_result result
    result.hidden_states = [][]float{}
    result.logits = fill_model_tensor(model.vocab_size, 0.0)
    result.loss_per_token = fill_model_tensor(len(token_ids), 0.0)
    [][]float embeddings = embedding_forward(model.embedding, token_ids)
    if len(embeddings) == 0 {
        return result
    }
    [][]float hidden_states = embeddings
    result.hidden_states.push(embeddings[0])
    int layer_idx = 0
    while layer_idx < model.num_layers && layer_idx < len(model.layers) {
        [][]float new_hidden_states = [][]float{}
        int seq_idx = 0
        while seq_idx < len(hidden_states) {
            []float block_output = transformer_block_forward(model.layers[layer_idx], hidden_states[seq_idx])
            new_hidden_states.push(block_output)
            seq_idx = seq_idx + 1
        }
        hidden_states = new_hidden_states
        if len(new_hidden_states) > 0 {
            result.hidden_states.push(new_hidden_states[0])
        }
        layer_idx = layer_idx + 1
    }
    if len(hidden_states) > 0 {
        []float final_hidden = rms_norm_forward(model.final_norm, hidden_states[len(hidden_states) - 1])
        result.logits = linear_forward(model.lm_head, final_hidden)
    }
    return result
}
func transformer_model_forward_with_loss(transformer_model model, []int input_ids, []int target_ids) forward_pass_result {
    forward_pass_result result = transformer_model_forward(model, input_ids)
    int i = 0
    while i < len(result.logits) && i < len(target_ids) {
        float log_prob = 0.0
        if target_ids[i] >= 0 && target_ids[i] < len(result.logits) {
            float prob = exp(result.logits[target_ids[i]])
            if prob > 0.0 {
                log_prob = 0.0 - log(prob)
            }
        }
        result.loss_per_token[i] = log_prob
        i = i + 1
    }
    return result
}
func load_model_from_safetensors_file(string model_path, int num_layers, int hidden_size, int vocab_size, int intermediate_size) transformer_model {
    transformer_model model = create_transformer_model(num_layers, hidden_size, vocab_size, intermediate_size, 8)
    return model
}
func get_model_layers(transformer_model model) []transformer_block {
    return model.layers
}
func get_embedding_layer(transformer_model model) embedding_layer {
    return model.embedding
}
func get_lm_head(transformer_model model) linear_layer {
    return model.lm_head
}
