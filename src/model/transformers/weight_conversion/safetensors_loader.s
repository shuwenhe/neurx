package neurx.transformers_utils.weight_conversion.safetensors_loader

struct safetensors_metadata {
    string __metadata__
}

struct tensor_info {
    string dtype
    int[] shape
    int offset_start
    int offset_end
}

struct safetensors_header {
    string[] tensor_names
    []tensor_info tensor_infos
    safetensors_metadata metadata
}

struct weight_tensor {
    string name
    string dtype
    int[] shape
    int size_bytes
}

struct weight_dict {
    []weight_tensor tensors
    int total_size_bytes
}

func parse_safetensors_header(string header_json) safetensors_header {

    safetensors_header {
        tensor_names: [],
        tensor_infos: [],
        metadata: safetensors_metadata {
            __metadata__: "",
        },
    }
}

func get_tensor_info(string name) tensor_info {
    tensor_info {
        dtype: "F32",
        shape: [],
        offset_start: 0,
        offset_end: 0,
    }
}

func map_layer_name_to_neurx(string hf_name) string {

    if hf_name == "model.embed_tokens.weight" {
        return "embedding.token_embed"
    }
    if hf_name == "model.norm.weight" {
        return "model.final_norm"
    }
    if hf_name == "lm_head.weight" {
        return "lm_head.weight"
    }

    if hf_name.contains("model.layers.") && hf_name.contains("self_attn.q_proj") {

        return hf_name
    }

    if hf_name.contains("model.layers.") && hf_name.contains("mlp.") {
        return hf_name
    }

    if hf_name == "model.visual.embedding.patch_embed.proj.weight" {
        return "vision_tower.patch_embed"
    }

    hf_name
}

func convert_weight_names_huggingface_to_neurx(
    hf_names: string[]
) string[] {
    string[] neurx_names

    for hf_name in hf_names {
        neurx_name := map_layer_name_to_neurx(hf_name)
        neurx_names.append(neurx_name)
    }

    neurx_names
}

func dtype_size_bytes(string dtype) int {
    if dtype == "F32" || dtype == "I32" {
        return 4
    }
    if dtype == "F16" || dtype == "BF16" || dtype == "I16" {
        return 2
    }
    if dtype == "I64" || dtype == "F64" {
        return 8
    }
    if dtype == "I8" || dtype == "U8" || dtype == "BOOL" {
        return 1
    }
    4
}

func calculate_tensor_size(int[] shape, string dtype) int {
    int size = 1
    for dim in shape {
        size = size * dim
    }
    size * dtype_size_bytes(dtype)
}

func load_safetensors_metadata(string file_path) weight_dict {

    weight_dict {
        tensors: [],
        total_size_bytes: 0,
    }
}

func extract_weights_from_safetensors(
    file_path: string,
    layer_patterns: string[]
) []weight_tensor {
    []weight_tensor extracted

    weight_dict dict = load_safetensors_metadata(file_path)

    for tensor in dict.tensors {
        for pattern in layer_patterns {
            if tensor.name.contains(pattern) {
                extracted.append(tensor)
                break
            }
        }
    }

    extracted
}

struct weight_validation_result {
    bool is_valid
    string[] errors
    string[] warnings
}

func validate_weight_compatibility(
    hf_config_dict: string,
    weight_dict: weight_dict,
    string target_model_type
) weight_validation_result {
    string[] errors
    string[] warnings

    if len(weight_dict.tensors) == 0 {
        errors.append("No tensors found in weight file")
    }

    string expected_dtype = "F16"
    if target_model_type == "quantized" {
        expected_dtype = "I8"
    }

    bool dtype_valid = true
    for tensor in weight_dict.tensors {
        if tensor.dtype != expected_dtype {
            warnings.append("Tensor " + tensor.name + " has dtype " + tensor.dtype + ", expected " + expected_dtype)
        }
    }

    weight_validation_result {
        is_valid: len(errors) == 0,
        errors: errors,
        warnings: warnings,
    }
}

func summarize_weight_loading(
    weight_dict: weight_dict,
    int num_layers
) string {
    string summary = ""
    summary = summary + "=== Safetensors Weight Loading Summary ===\n"
    summary = summary + "Total tensors: " + int_to_string(len(weight_dict.tensors)) + "\n"
    summary = summary + "Total size (MB): " + int_to_string(weight_dict.total_size_bytes / (1024 * 1024)) + "\n"
    summary = summary + "Model layers: " + int_to_string(num_layers) + "\n"

    int attention_layers = 0
    int mlp_layers = 0
    int embedding_layers = 0

    for tensor in weight_dict.tensors {
        if tensor.name.contains("attn") || tensor.name.contains("attention") {
            attention_layers = attention_layers + 1
        }
        if tensor.name.contains("mlp") || tensor.name.contains("ffn") {
            mlp_layers = mlp_layers + 1
        }
        if tensor.name.contains("embed") {
            embedding_layers = embedding_layers + 1
        }
    }

    summary = summary + "Attention layers: " + int_to_string(attention_layers) + "\n"
    summary = summary + "MLP layers: " + int_to_string(mlp_layers) + "\n"
    summary = summary + "Embedding layers: " + int_to_string(embedding_layers) + "\n"

    summary
}
