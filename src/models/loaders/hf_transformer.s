package neurx.models.loaders.hf_transformer
use neurx.models.formats.safetensors_embedding.{safetensors_embedding, f32_tensor_result, load_f32_tensor, read_f32_tensor}

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

func hf_load_values(string path, string name) f32_tensor_result {
    safetensors_embedding tensor = load_f32_tensor(path, name)
    read_f32_tensor(tensor)
}

func load_hf_layer_zero(string path) hf_layer_weights {
    f32_tensor_result input_norm = hf_load_values(path, "model.layers.0.input_layernorm.weight")
    f32_tensor_result q = hf_load_values(path, "model.layers.0.self_attn.q_proj.weight")
    f32_tensor_result k = hf_load_values(path, "model.layers.0.self_attn.k_proj.weight")
    f32_tensor_result v = hf_load_values(path, "model.layers.0.self_attn.v_proj.weight")
    f32_tensor_result o = hf_load_values(path, "model.layers.0.self_attn.o_proj.weight")
    f32_tensor_result post_norm = hf_load_values(path, "model.layers.0.post_attention_layernorm.weight")
    f32_tensor_result gate = hf_load_values(path, "model.layers.0.mlp.gate_proj.weight")
    f32_tensor_result up = hf_load_values(path, "model.layers.0.mlp.up_proj.weight")
    f32_tensor_result down = hf_load_values(path, "model.layers.0.mlp.down_proj.weight")
    if !input_norm.ok || !q.ok || !k.ok || !v.ok || !o.ok || !post_norm.ok || !gate.ok || !up.ok || !down.ok {
        return hf_layer_weights { valid: false, input_norm: [], q_proj: [], k_proj: [], v_proj: [], o_proj: [], post_norm: [], gate_proj: [], up_proj: [], down_proj: [], error_code: "missing_hf_layer_weight" }
    }
    hf_layer_weights { valid: true, input_norm: input_norm.values, q_proj: q.values, k_proj: k.values, v_proj: v.values, o_proj: o.values, post_norm: post_norm.values, gate_proj: gate.values, up_proj: up.values, down_proj: down.values, error_code: "" }
}
