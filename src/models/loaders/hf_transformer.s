package neurx.models.loaders.hf_transformer
use neurx.models.formats.safetensors_embedding.{safetensors_embedding, f32_tensor_result, load_f32_tensor, read_f32_tensor}
use neurx.models.formats.hf_config.{hf_model_config, load_hf_config}

struct hf_layer_weights {
    bool valid
    []float input_norm
    []float q_proj
    []float k_proj
    []float v_proj
    []float o_proj
    []float post_norm
    []float gate_proj
    []float up_proj
    []float down_proj
    string error_code
}

struct hf_model_weights {
    bool valid
    hf_model_config config
    safetensors_embedding embedding
    []float input_norm
    []float q_proj
    []float k_proj
    []float v_proj
    []float o_proj
    []float post_norm
    []float gate_proj
    []float up_proj
    []float down_proj
    []float final_norm
    []float lm_head
    string error_code
}

func hf_int_string(int value) string {
    if value == 0 { return "0" }
    string output = ""
    int current = value
    while current > 0 { output = string(48 + current % 10) + output; current = current / 10 }
    output
}

func hf_load_values(string path, string name) f32_tensor_result {
    safetensors_embedding tensor = load_f32_tensor(path, name)
    read_f32_tensor(tensor)
}

func load_hf_layer_zero(string path) hf_layer_weights {
    load_hf_layer(path, 0)
}

func load_hf_layer(string path, int layer) hf_layer_weights {
    string prefix = "model.layers." + hf_int_string(layer) + "."
    f32_tensor_result input_norm = hf_load_values(path, prefix + "input_layernorm.weight")
    f32_tensor_result q = hf_load_values(path, prefix + "self_attn.q_proj.weight")
    f32_tensor_result k = hf_load_values(path, prefix + "self_attn.k_proj.weight")
    f32_tensor_result v = hf_load_values(path, prefix + "self_attn.v_proj.weight")
    f32_tensor_result o = hf_load_values(path, prefix + "self_attn.o_proj.weight")
    f32_tensor_result post_norm = hf_load_values(path, prefix + "post_attention_layernorm.weight")
    f32_tensor_result gate = hf_load_values(path, prefix + "mlp.gate_proj.weight")
    f32_tensor_result up = hf_load_values(path, prefix + "mlp.up_proj.weight")
    f32_tensor_result down = hf_load_values(path, prefix + "mlp.down_proj.weight")
    if !input_norm.ok || !q.ok || !k.ok || !v.ok || !o.ok || !post_norm.ok || !gate.ok || !up.ok || !down.ok {
        return hf_layer_weights { valid: false, input_norm: [], q_proj: [], k_proj: [], v_proj: [], o_proj: [], post_norm: [], gate_proj: [], up_proj: [], down_proj: [], error_code: "missing_hf_layer_weight" }
    }
    hf_layer_weights { valid: true, input_norm: input_norm.values, q_proj: q.values, k_proj: k.values, v_proj: v.values, o_proj: o.values, post_norm: post_norm.values, gate_proj: gate.values, up_proj: up.values, down_proj: down.values, error_code: "" }
}

func invalid_hf_model(hf_model_config config, string code) hf_model_weights {
    safetensors_embedding empty = safetensors_embedding { valid: false, path: "", rows: 0, columns: 0, data_offset: 0, data_bytes: 0, error_code: code }
    hf_model_weights { valid: false, config: config, embedding: empty, input_norm: [], q_proj: [], k_proj: [], v_proj: [], o_proj: [], post_norm: [], gate_proj: [], up_proj: [], down_proj: [], final_norm: [], lm_head: [], error_code: code }
}

func hf_copy_layer([]float target, int offset, []float source) {
    int i = 0
    while i < len(source) { target[offset + i] = source[i]; i = i + 1 }
}

func load_hf_model(string model_dir) hf_model_weights {
    hf_model_config config = load_hf_config(model_dir)
    if !config.valid { return invalid_hf_model(config, config.error_code) }
    string path = model_dir + "/model.safetensors"
    safetensors_embedding embedding = load_f32_tensor(path, "model.embed_tokens.weight")
    if !embedding.valid { return invalid_hf_model(config, "embedding_" + embedding.error_code) }
    int hidden_square = config.hidden_size * config.hidden_size
    int kv_size = config.kv_heads * config.head_dim * config.hidden_size
    int mlp_size = config.intermediate_size * config.hidden_size
    []float input_norm = []float{cap: config.layers * config.hidden_size}
    []float q_proj = []float{cap: config.layers * hidden_square}
    []float k_proj = []float{cap: config.layers * kv_size}
    []float v_proj = []float{cap: config.layers * kv_size}
    []float o_proj = []float{cap: config.layers * hidden_square}
    []float post_norm = []float{cap: config.layers * config.hidden_size}
    []float gate_proj = []float{cap: config.layers * mlp_size}
    []float up_proj = []float{cap: config.layers * mlp_size}
    []float down_proj = []float{cap: config.layers * mlp_size}
    int layer = 0
    while layer < config.layers {
        hf_layer_weights weights = load_hf_layer(path, layer)
        if !weights.valid { return invalid_hf_model(config, "layer_" + hf_int_string(layer) + "_" + weights.error_code) }
        hf_copy_layer(input_norm, layer * config.hidden_size, weights.input_norm)
        hf_copy_layer(q_proj, layer * hidden_square, weights.q_proj)
        hf_copy_layer(k_proj, layer * kv_size, weights.k_proj)
        hf_copy_layer(v_proj, layer * kv_size, weights.v_proj)
        hf_copy_layer(o_proj, layer * hidden_square, weights.o_proj)
        hf_copy_layer(post_norm, layer * config.hidden_size, weights.post_norm)
        hf_copy_layer(gate_proj, layer * mlp_size, weights.gate_proj)
        hf_copy_layer(up_proj, layer * mlp_size, weights.up_proj)
        hf_copy_layer(down_proj, layer * mlp_size, weights.down_proj)
        layer = layer + 1
    }
    f32_tensor_result final_norm = hf_load_values(path, "model.norm.weight")
    f32_tensor_result lm_head = hf_load_values(path, "lm_head.weight")
    if !final_norm.ok { return invalid_hf_model(config, "missing_final_norm") }
    if !lm_head.ok {
        lm_head = read_f32_tensor(embedding)
        if !lm_head.ok { return invalid_hf_model(config, "missing_lm_head") }
    }
    hf_model_weights { valid: true, config: config, embedding: embedding, input_norm: input_norm, q_proj: q_proj, k_proj: k_proj, v_proj: v_proj, o_proj: o_proj, post_norm: post_norm, gate_proj: gate_proj, up_proj: up_proj, down_proj: down_proj, final_norm: final_norm.values, lm_head: lm_head.values, error_code: "" }
}
