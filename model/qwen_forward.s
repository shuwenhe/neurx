package neurx.model.qwen_forward
use neurx.model.weight_loader.{model_weights, layer_weights}
use neurx.model.transformer_ops.{
    embedding_lookup, rms_norm, transformer_layer, matmul, add_arrays
}
use std.io.eprintln

// Complete forward pass for Qwen model
// Input: token IDs → Output: logits
func model_forward(
    []int input_ids,        // [batch_size * seq_len]
    model_weights weights,
    int batch_size,
    int seq_len,
    int hidden_size,
    int num_layers,
    int num_heads,
    int intermediate_size,
    int vocab_size
) []float {
    eprintln("[Model Forward] Starting forward pass")
    eprintln("[Model Forward] Batch=" + int_to_str(batch_size) + 
             " Seq=" + int_to_str(seq_len) +
             " Hidden=" + int_to_str(hidden_size))
    
    // Step 1: Embedding lookup
    eprintln("[Model Forward] Step 1/4: Embedding lookup")
    []float hidden_states = embedding_lookup(
        input_ids, weights.embed_tokens,
        batch_size, seq_len, hidden_size, vocab_size
    )
    
    // Step 2: Transformer layers
    eprintln("[Model Forward] Step 2/4: Processing " + int_to_str(num_layers) + " transformer layers")
    int layer_idx = 0
    while layer_idx < num_layers {
        if layer_idx == 0 or layer_idx == num_layers - 1 {
            eprintln("[Model Forward]   Layer " + int_to_str(layer_idx + 1) + "/" + int_to_str(num_layers))
        }
        
        layer_weights layer = weights.layers[layer_idx]
        
        hidden_states = transformer_layer(
            hidden_states,
            layer.input_layernorm,
            layer.post_attention_layernorm,
            layer.q_proj,
            layer.k_proj,
            layer.v_proj,
            layer.o_proj,
            layer.gate_proj,
            layer.up_proj,
            layer.down_proj,
            batch_size,
            seq_len,
            hidden_size,
            num_heads,
            intermediate_size
        )
        
        layer_idx = layer_idx + 1
    }
    
    // Step 3: Final layer norm
    eprintln("[Model Forward] Step 3/4: Final layer normalization")
    hidden_states = rms_norm(
        hidden_states,
        weights.norm_weight,
        batch_size,
        seq_len,
        hidden_size,
        0.000001
    )
    
    // Step 4: LM head (project to vocab size)
    eprintln("[Model Forward] Step 4/4: LM head projection")
    int total_tokens = batch_size * seq_len
    []float logits = matmul(
        hidden_states,
        weights.embed_tokens,  // Tied weights
        total_tokens,
        hidden_size,
        vocab_size
    )
    
    eprintln("[Model Forward] Forward pass complete")
    logits
}

// Apply LoRA to model forward
func model_forward_with_lora(
    []int input_ids,
    model_weights weights,
    []lora_adapter lora_adapters,
    int batch_size,
    int seq_len,
    int hidden_size,
    int num_layers,
    int num_heads,
    int intermediate_size,
    int vocab_size
) []float {
    // For Phase 1: simplified - just run base model
    // TODO: integrate LoRA in Phase 2
    model_forward(
        input_ids, weights,
        batch_size, seq_len, hidden_size,
        num_layers, num_heads, intermediate_size, vocab_size
    )
}

struct lora_adapter {
    string name
    []float lora_A
    []float lora_B
    int rank
    float scaling
}

func int_to_str(int x) string {
    if x == 0 { return "0" }
    if x < 0 { return "-" + int_to_str(0 - x) }
    
    string result = ""
    int num = x
    while num > 0 {
        int digit = num - ((num / 10) * 10)
        if digit == 0 { result = "0" + result }
        if digit == 1 { result = "1" + result }
        if digit == 2 { result = "2" + result }
        if digit == 3 { result = "3" + result }
        if digit == 4 { result = "4" + result }
        if digit == 5 { result = "5" + result }
        if digit == 6 { result = "6" + result }
        if digit == 7 { result = "7" + result }
        if digit == 8 { result = "8" + result }
        if digit == 9 { result = "9" + result }
        num = num / 10
    }
    result
}
