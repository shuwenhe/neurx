package neurx.models.loaders.hf_transformer
extern "intrinsic" func __std_byte_string(int value) string
extern "intrinsic" func __std_clock_ns(int kind) int
import (
    "neurx.runtime.tensor_builder"
    "neurx.runtime.command"
    "neurx.models.formats.hf_config"
    "neurx.models.formats.safetensors_embedding"
)
extern "intrinsic" func __host_file_exists(string path) bool
extern "intrinsic" func __host_read_binary_file(string path) int[]
struct hf_layer_weights {
    bool valid
    float[] input_norm
    float[] q_proj
    float[] k_proj
    float[] v_proj
    float[] q_bias
    float[] k_bias
    float[] v_bias
    float[] o_proj
    float[] post_norm
    float[] gate_proj
    float[] up_proj
    float[] down_proj
    string error_code
}

struct hf_model_weights {
    bool valid
    hf_model_config config
    safetensors_embedding embedding
    float[] input_norm
    float[] q_proj
    float[] k_proj
    float[] v_proj
    float[] q_bias
    float[] k_bias
    float[] v_bias
    float[] o_proj
    float[] post_norm
    float[] gate_proj
    float[] up_proj
    float[] down_proj
    float[] final_norm
    float[] lm_head
    string error_code
}

func hf_trace(string message) {
    if runtime_env_get("NEURX_TRACE", "false") == "true" { println("[neurx-hf] " + message) }
}

func hf_int_string(int value) string {
    if value < 0 { return "-" + hf_int_string(-value) }
    if value == 0 { return "0" }
    string output = ""
    int current = value
    for current > 0 { output = __std_byte_string(48 + current % 10) + output; current = current / 10 }
    output
}

func hf_load_values(string path, string name) f32_tensor_result {
    safetensors_embedding tensor = load_f32_tensor(path, name)
    read_f32_tensor(tensor)
}

func hf_bytes_string(int[] bytes) string { byte_array_string(bytes) }

func hf_find(string text, string pattern, int start) int {
    int i = start
    for i + len(pattern) <= len(text) {
        int j = 0
        bool match = true
        for j < len(pattern) { if text[i + j] != pattern[j] { match = false; j = len(pattern) } else { j = j + 1 } }
        if match { return i }
        i = i + 1
    }
    -1
}

func hf_resolve_tensor_path(string model_dir, string name) string {
    string single = model_dir + "/model.safetensors"
    if __host_file_exists(single) { return single }
    string index_path = model_dir + "/model.safetensors.index.json"
    if !__host_file_exists(index_path) { return "" }
    string index = hf_bytes_string(__host_read_binary_file(index_path))
    int key = hf_find(index, "\"" + name + "\"", 0)
    if key < 0 { return "" }
    int colon = hf_find(index, ":", key + len(name) + 2)
    int quote = hf_find(index, "\"", colon + 1)
    int end = hf_find(index, "\"", quote + 1)
    if colon < 0 || quote < 0 || end < 0 { return "" }
    string shard = ""
    int i = quote + 1
    for i < end { shard = shard + __std_byte_string(index[i]); i = i + 1 }
    model_dir + "/" + shard
}

func hf_load_model_values(string model_dir, string name) f32_tensor_result {
    hf_trace("weight " + name)
    string path = hf_resolve_tensor_path(model_dir, name)
    if path == "" { return hf_load_values(model_dir + "/model.safetensors", name) }
    hf_load_values(path, name)
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
    f32_tensor_result q_bias = hf_load_values(path, prefix + "self_attn.q_proj.bias")
    f32_tensor_result k_bias = hf_load_values(path, prefix + "self_attn.k_proj.bias")
    f32_tensor_result v_bias = hf_load_values(path, prefix + "self_attn.v_proj.bias")
    f32_tensor_result o = hf_load_values(path, prefix + "self_attn.o_proj.weight")
    f32_tensor_result post_norm = hf_load_values(path, prefix + "post_attention_layernorm.weight")
    f32_tensor_result gate = hf_load_values(path, prefix + "mlp.gate_proj.weight")
    f32_tensor_result up = hf_load_values(path, prefix + "mlp.up_proj.weight")
    f32_tensor_result down = hf_load_values(path, prefix + "mlp.down_proj.weight")
    if !input_norm.ok || !q.ok || !k.ok || !v.ok || !o.ok || !post_norm.ok || !gate.ok || !up.ok || !down.ok {
        return hf_layer_weights { valid: false, input_norm: [], q_proj: [], k_proj: [], v_proj: [], q_bias: [], k_bias: [], v_bias: [], o_proj: [], post_norm: [], gate_proj: [], up_proj: [], down_proj: [], error_code: "missing_hf_layer_weight" }
    }
    hf_layer_weights { valid: true, input_norm: input_norm.values, q_proj: q.values, k_proj: k.values, v_proj: v.values, q_bias: q_bias.values, k_bias: k_bias.values, v_bias: v_bias.values, o_proj: o.values, post_norm: post_norm.values, gate_proj: gate.values, up_proj: up.values, down_proj: down.values, error_code: "" }
}

func load_hf_model_layer(string model_dir, int layer) hf_layer_weights {
    string prefix = "model.layers." + hf_int_string(layer) + "."
    f32_tensor_result input_norm = hf_load_model_values(model_dir, prefix + "input_layernorm.weight")
    f32_tensor_result q = hf_load_model_values(model_dir, prefix + "self_attn.q_proj.weight")
    f32_tensor_result k = hf_load_model_values(model_dir, prefix + "self_attn.k_proj.weight")
    f32_tensor_result v = hf_load_model_values(model_dir, prefix + "self_attn.v_proj.weight")
    f32_tensor_result q_bias = hf_load_model_values(model_dir, prefix + "self_attn.q_proj.bias")
    f32_tensor_result k_bias = hf_load_model_values(model_dir, prefix + "self_attn.k_proj.bias")
    f32_tensor_result v_bias = hf_load_model_values(model_dir, prefix + "self_attn.v_proj.bias")
    f32_tensor_result o = hf_load_model_values(model_dir, prefix + "self_attn.o_proj.weight")
    f32_tensor_result post_norm = hf_load_model_values(model_dir, prefix + "post_attention_layernorm.weight")
    f32_tensor_result gate = hf_load_model_values(model_dir, prefix + "mlp.gate_proj.weight")
    f32_tensor_result up = hf_load_model_values(model_dir, prefix + "mlp.up_proj.weight")
    f32_tensor_result down = hf_load_model_values(model_dir, prefix + "mlp.down_proj.weight")
    hf_model_config config = load_hf_config(model_dir)
    if config.attention_bias && (!q_bias.ok || !k_bias.ok || !v_bias.ok) {
        return hf_layer_weights { valid: false, error_code: "missing_attention_bias" }
    }
    if !input_norm.ok || !q.ok || !k.ok || !v.ok || !o.ok || !post_norm.ok || !gate.ok || !up.ok || !down.ok { return hf_layer_weights { valid: false, input_norm: [], q_proj: [], k_proj: [], v_proj: [], q_bias: [], k_bias: [], v_bias: [], o_proj: [], post_norm: [], gate_proj: [], up_proj: [], down_proj: [], error_code: "missing_hf_layer_weight" } }
    int hidden = config.hidden_size
    int kv_width = config.kv_heads * config.head_dim
    int intermediate = config.intermediate_size
    if !hf_tensor_shape(input_norm, 1, hidden) || !hf_tensor_shape(post_norm, 1, hidden) || !hf_tensor_shape(q, hidden, hidden) || !hf_tensor_shape(o, hidden, hidden) || !hf_tensor_shape(k, kv_width, hidden) || !hf_tensor_shape(v, kv_width, hidden) || !hf_tensor_shape(gate, intermediate, hidden) || !hf_tensor_shape(up, intermediate, hidden) || !hf_tensor_shape(down, hidden, intermediate) {
        return hf_layer_weights { valid: false, error_code: "layer_weight_shape_mismatch" }
    }
    if config.attention_bias && (!hf_tensor_shape(q_bias, 1, hidden) || !hf_tensor_shape(k_bias, 1, kv_width) || !hf_tensor_shape(v_bias, 1, kv_width)) {
        return hf_layer_weights { valid: false, error_code: "attention_bias_shape_mismatch" }
    }
    hf_layer_weights { valid: true, input_norm: input_norm.values, q_proj: q.values, k_proj: k.values, v_proj: v.values, q_bias: q_bias.values, k_bias: k_bias.values, v_bias: v_bias.values, o_proj: o.values, post_norm: post_norm.values, gate_proj: gate.values, up_proj: up.values, down_proj: down.values, error_code: "" }
}

func invalid_hf_model(hf_model_config config, string code) hf_model_weights {
    safetensors_embedding empty = safetensors_embedding { valid: false, path: "", rows: 0, columns: 0, data_offset: 0, data_bytes: 0, dtype: "", element_bytes: 0, error_code: code }
    hf_model_weights { valid: false, config: config, embedding: empty, input_norm: [], q_proj: [], k_proj: [], v_proj: [], q_bias: [], k_bias: [], v_bias: [], o_proj: [], post_norm: [], gate_proj: [], up_proj: [], down_proj: [], final_norm: [], lm_head: [], error_code: code }
}

func hf_copy_layer(float[] target, int offset, float[] source) {
    int i = 0
    for i < len(source) { target[offset + i] = source[i]; i = i + 1 }
}

func hf_tensor_shape(f32_tensor_result value, int rows, int columns) bool {
    value.ok && value.tensor.rows == rows && value.tensor.columns == columns
}
func hf_safe_product(int left, int right) int {
    if left <= 0 || right <= 0 || left > 36028797018963967 / right { return -1 }
    left * right
}
func hf_release_builders(int[] builders) {
    int i = 0
    for i < len(builders) { release_builder(builders[i]); i = i + 1 }
}

func load_hf_model(string model_dir) hf_model_weights {
    int loading_started = __std_clock_ns(1)
    int loading_source_bytes = construction_stat(6)
    int loading_elements = construction_stat(7)
    hf_trace("loading model " + model_dir)
    hf_model_config config = load_hf_config(model_dir)
    if !config.valid { return invalid_hf_model(config, config.error_code) }
    string path = hf_resolve_tensor_path(model_dir, "model.embed_tokens.weight")
    if path == "" { return invalid_hf_model(config, "model_weights_not_found") }
    safetensors_embedding embedding = load_f32_tensor(path, "model.embed_tokens.weight")
    if !embedding.valid { return invalid_hf_model(config, "embedding_" + embedding.error_code) }
    hf_trace("config layers=" + hf_int_string(config.layers) + " hidden=" + hf_int_string(config.hidden_size) + " vocabulary=" + hf_int_string(config.vocabulary_size) + " dtype=" + embedding.dtype)
    int hidden_square = hf_safe_product(config.hidden_size, config.hidden_size)
    int kv_width = hf_safe_product(config.kv_heads, config.head_dim)
    int kv_size = hf_safe_product(kv_width, config.hidden_size)
    int mlp_size = hf_safe_product(config.intermediate_size, config.hidden_size)
    if embedding.rows != config.vocabulary_size || embedding.columns != config.hidden_size { return invalid_hf_model(config, "embedding_shape_mismatch") }
    if hf_safe_product(config.layers, hidden_square) < 0 || hf_safe_product(config.layers, kv_size) < 0 || hf_safe_product(config.layers, mlp_size) < 0 || hf_safe_product(config.layers, config.hidden_size) < 0 { return invalid_hf_model(config, "model_size_overflow") }
    int[] builders = int[]{new_float_builder(config.layers * config.hidden_size), new_float_builder(config.layers * kv_width), new_float_builder(config.layers * kv_width), new_float_builder(config.layers * config.hidden_size), new_float_builder(config.layers * hidden_square), new_float_builder(config.layers * kv_size), new_float_builder(config.layers * kv_size), new_float_builder(config.layers * hidden_square), new_float_builder(config.layers * config.hidden_size), new_float_builder(config.layers * mlp_size), new_float_builder(config.layers * mlp_size), new_float_builder(config.layers * mlp_size)}
    int index = 0
    for index < len(builders) {
        if builders[index] <= 0 { hf_release_builders(builders); return invalid_hf_model(config, "tensor_allocation_failed") }
        index = index + 1
    }
    int layer = 0
    for layer < config.layers {
        hf_layer_weights weights = load_hf_model_layer(model_dir, layer)
        if !weights.valid { hf_release_builders(builders); return invalid_hf_model(config, "layer_" + hf_int_string(layer) + "_" + weights.error_code) }
        int status = 0
        if config.attention_bias { status = status + builder_copy_float(builders[0], layer * config.hidden_size, weights.q_bias) }
        if config.attention_bias { status = status + builder_copy_float(builders[1], layer * kv_width, weights.k_bias) }
        if config.attention_bias { status = status + builder_copy_float(builders[2], layer * kv_width, weights.v_bias) }
        status = status + builder_copy_float(builders[3], layer * config.hidden_size, weights.input_norm)
        status = status + builder_copy_float(builders[4], layer * hidden_square, weights.q_proj)
        status = status + builder_copy_float(builders[5], layer * kv_size, weights.k_proj)
        status = status + builder_copy_float(builders[6], layer * kv_size, weights.v_proj)
        status = status + builder_copy_float(builders[7], layer * hidden_square, weights.o_proj)
        status = status + builder_copy_float(builders[8], layer * config.hidden_size, weights.post_norm)
        status = status + builder_copy_float(builders[9], layer * mlp_size, weights.gate_proj)
        status = status + builder_copy_float(builders[10], layer * mlp_size, weights.up_proj)
        status = status + builder_copy_float(builders[11], layer * mlp_size, weights.down_proj)
        if status != 0 { hf_release_builders(builders); return invalid_hf_model(config, "tensor_copy_failed") }
        hf_trace("loaded layer=" + hf_int_string(layer))
        layer = layer + 1
    }
    f32_tensor_result final_norm = hf_load_model_values(model_dir, "model.norm.weight")
    f32_tensor_result lm_head = hf_load_model_values(model_dir, "lm_head.weight")
    if !hf_tensor_shape(final_norm, 1, config.hidden_size) { hf_release_builders(builders); return invalid_hf_model(config, "invalid_final_norm") }
    if !lm_head.ok {
        bool missing_head = lm_head.error_code == "tensor_not_found" || hf_resolve_tensor_path(model_dir, "lm_head.weight") == ""
        if !config.tie_word_embeddings || !missing_head { hf_release_builders(builders); return invalid_hf_model(config, "invalid_lm_head") }
        lm_head = read_f32_tensor(embedding)
    }
    if !hf_tensor_shape(lm_head, config.vocabulary_size, config.hidden_size) { hf_release_builders(builders); return invalid_hf_model(config, "invalid_lm_head") }
    float_construction_result q_bias = finish_float_builder(builders[0])
    float_construction_result k_bias = finish_float_builder(builders[1])
    float_construction_result v_bias = finish_float_builder(builders[2])
    float_construction_result input_norm = finish_float_builder(builders[3])
    float_construction_result q_proj = finish_float_builder(builders[4])
    float_construction_result k_proj = finish_float_builder(builders[5])
    float_construction_result v_proj = finish_float_builder(builders[6])
    float_construction_result o_proj = finish_float_builder(builders[7])
    float_construction_result post_norm = finish_float_builder(builders[8])
    float_construction_result gate_proj = finish_float_builder(builders[9])
    float_construction_result up_proj = finish_float_builder(builders[10])
    float_construction_result down_proj = finish_float_builder(builders[11])
    if !q_bias.ok || !k_bias.ok || !v_bias.ok || !input_norm.ok || !q_proj.ok || !k_proj.ok || !v_proj.ok || !o_proj.ok || !post_norm.ok || !gate_proj.ok || !up_proj.ok || !down_proj.ok { hf_release_builders(builders); return invalid_hf_model(config, "tensor_finalize_failed") }
    hf_trace("all model weights loaded source_bytes=" + hf_int_string(construction_stat(6) - loading_source_bytes) + " elements=" + hf_int_string(construction_stat(7) - loading_elements) + " elapsed_ns=" + hf_int_string(__std_clock_ns(1) - loading_started))
    hf_model_weights { valid: true, config: config, embedding: embedding, q_bias: q_bias.values, k_bias: k_bias.values, v_bias: v_bias.values, input_norm: input_norm.values, q_proj: q_proj.values, k_proj: k_proj.values, v_proj: v_proj.values, o_proj: o_proj.values, post_norm: post_norm.values, gate_proj: gate_proj.values, up_proj: up_proj.values, down_proj: down_proj.values, final_norm: final_norm.values, lm_head: lm_head.values, error_code: "" }
}
