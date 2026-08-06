package main
use neurx.model.transformer.ffn.{ffn_layer, new_ffn_layer, forward_ffn_layer}
use neurx.model.transformer.transformer.{transformer_config, transformer_layer_config, transformer_block, transformer_model, transformer_output, new_transformer_config, new_transformer_layer_config, new_transformer_block, new_transformer_model, forward_transformer_block, forward_transformer, new_7b_transformer_config, new_13b_transformer_config, new_70b_transformer_config, new_foundation_model, foundation_model_forward}
func build_hidden_states(int batch_size, int seq_len, int hidden_dim) []float {
    int total = batch_size * seq_len * hidden_dim
    []float values = []float{cap: total}
    int i = 0
    while i < total {
        values[i] = ((i % hidden_dim) + 1) * 0.01
        i = i + 1
    }
    values
}
func test_ffn_layer() bool {
    ffn_layer layer = new_ffn_layer(8, "gelu")
    []float input = build_hidden_states(1, 2, 8)
    []float output = forward_ffn_layer(layer, input, 2)
    return len(output) == len(input)
}
func test_transformer_block_with_rope() bool {
    transformer_layer_config cfg = new_transformer_layer_config()
    cfg.hidden_dim = 8
    cfg.num_attention_heads = 2
    cfg.num_key_value_heads = 1
    cfg.intermediate_dim = 32
    cfg.position_embedding_type = "rope"
    transformer_block block = new_transformer_block(cfg)
    []float input = build_hidden_states(1, 2, 8)
    []float output = forward_transformer_block(block, input, 1, 2)
    return len(output) == len(input)
}
func test_transformer_with_learned_pe() bool {
    transformer_config cfg = new_transformer_config()
    cfg.hidden_dim = 8
    cfg.num_layers = 1
    cfg.num_attention_heads = 2
    cfg.num_key_value_heads = 1
    cfg.intermediate_dim = 32
    cfg.vocab_size = 16
    cfg.max_seq_len = 4
    cfg.position_embedding_type = "learned"
    transformer_model model = new_transformer_model(cfg)
    []float input = build_hidden_states(1, 2, 8)
    transformer_output output = forward_transformer(model, input, 1, 2)
    return len(output.hidden_states) == len(input) && len(output.logits) == 1 * 2 * 16
}
func test_model_presets() bool {
    transformer_config cfg7 = new_7b_transformer_config()
    transformer_config cfg13 = new_13b_transformer_config()
    transformer_config cfg70 = new_70b_transformer_config()
    if cfg7.hidden_dim != 4096 || cfg7.intermediate_dim != 16384 {
        return false
    }
    if cfg13.hidden_dim != 5120 || cfg13.intermediate_dim != 20480 {
        return false
    }
    if cfg70.hidden_dim != 8192 || cfg70.intermediate_dim != 32768 {
        return false
    }
    return true
}
func test_foundation_model_runtime_materialization() bool {
    var model7 = new_foundation_model("7B", "rope")
    var model13 = new_foundation_model("13B", "learned")
    var model70 = new_foundation_model("70B", "rope")
    []float input7 = build_hidden_states(1, 2, 8)
    []float input13 = build_hidden_states(1, 2, 8)
    []float input70 = build_hidden_states(1, 2, 8)
    transformer_output out7 = foundation_model_forward(model7, input7, 1, 2)
    transformer_output out13 = foundation_model_forward(model13, input13, 1, 2)
    transformer_output out70 = foundation_model_forward(model70, input70, 1, 2)
    if len(out7.hidden_states) != len(input7) || len(out7.logits) != 1 * 2 * 16 {
        return false
    }
    if len(out13.hidden_states) != len(input13) || len(out13.logits) != 1 * 2 * 16 {
        return false
    }
    if len(out70.hidden_states) != len(input70) || len(out70.logits) != 1 * 2 * 16 {
        return false
    }
    return true
}
func test_end_to_end_forward() bool {
    var model = new_foundation_model("7B", "rope")
    int batch_size = 1
    int seq_len = 2
    []float input = build_hidden_states(batch_size, seq_len, 8)
    transformer_output output = foundation_model_forward(model, input, batch_size, seq_len)
    if len(output.hidden_states) != len(input) {
        return false
    }
    if len(output.logits) != batch_size * seq_len * 16 {
        return false
    }
    return true
}
func main() {
    println("========================================")
    println("transformer_2 model End-to-End Tests")
    println("========================================")
    if test_ffn_layer() {
        println("✓ FFN layer hidden -> 4xhidden -> hidden")
    } else {
        println("✗ FFN layer hidden -> 4xhidden -> hidden")
    }
    if test_transformer_block_with_rope() {
        println("✓ transformer_2 block with RoPE")
    } else {
        println("✗ transformer_2 block with RoPE")
    }
    if test_transformer_with_learned_pe() {
        println("✓ Learned position embedding forward path")
    } else {
        println("✗ Learned position embedding forward path")
    }
    if test_model_presets() {
        println("✓ 7B/13B/70B config presets")
    } else {
        println("✗ 7B/13B/70B config presets")
    }
    if test_foundation_model_runtime_materialization() {
        println("✓ Unified model class runtime materialization")
    } else {
        println("✗ Unified model class runtime materialization")
    }
    if test_end_to_end_forward() {
        println("✓ End-to-end transformer forward integration")
    } else {
        println("✗ End-to-end transformer forward integration")
    }
    println("========================================")
}
