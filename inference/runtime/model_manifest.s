package neurx.inference.runtime.model_manifest

use neurx.runtime.io.{runtime_file_exists, runtime_read_text_file, runtime_run_command_output, runtime_shell_escape}

extern "intrinsic" func __host_read_binary_file_range(string path, int start, int count) []int

struct hf_model_config {
    string architecture
    string model_type
    string dtype
    string hidden_act
    int vocab_size
    int hidden_size
    int intermediate_size
    int num_layers
    int num_attention_heads
    int num_kv_heads
    int max_position_embeddings
    int sliding_window
    int bos_token_id
    int eos_token_id
    float rms_norm_eps
    float rope_theta
    bool tie_word_embeddings
    bool use_sliding_window
}


struct safetensors_tensor_manifest {
    string name
    string dtype
    []int shape
    int data_start
    int data_end
    int byte_count
}


struct safetensors_archive_manifest {
    string path
    int file_size
    int header_size
    int data_start
    []safetensors_tensor_manifest tensors
    bool valid
    string error_message
}


struct hf_model_manifest {
    string model_directory
    hf_model_config config
    []safetensors_archive_manifest archives
    int tensor_count
    int weight_bytes
    bool valid
    string error_message
}


func model_empty_config() hf_model_config {
    hf_model_config config
    config.architecture = ""
    config.model_type = ""
    config.dtype = ""
    config.hidden_act = ""
    config.vocab_size = 0
    config.hidden_size = 0
    config.intermediate_size = 0
    config.num_layers = 0
    config.num_attention_heads = 0
    config.num_kv_heads = 0
    config.max_position_embeddings = 0
    config.sliding_window = 0
    config.bos_token_id = -1
    config.eos_token_id = -1
    config.rms_norm_eps = 0.0
    config.rope_theta = 0.0
    config.tie_word_embeddings = false
    config.use_sliding_window = false
    config
}


func model_empty_archive(string path) safetensors_archive_manifest {
    safetensors_archive_manifest archive
    archive.path = path
    archive.file_size = 0
    archive.header_size = 0
    archive.data_start = 0
    archive.tensors = []
    archive.valid = false
    archive.error_message = ""
    archive
}


func model_empty_manifest(string directory) hf_model_manifest {
    hf_model_manifest manifest
    manifest.model_directory = directory
    manifest.config = model_empty_config()
    manifest.archives = []
    manifest.tensor_count = 0
    manifest.weight_bytes = 0
    manifest.valid = false
    manifest.error_message = ""
    manifest
}


func model_find(string text, string pattern, int start) int {
    if len(pattern) == 0 { return start }
    int i = start
    if i < 0 { i = 0 }
    while i + len(pattern) <= len(text) {
        int j = 0
        bool matched = true
        while j < len(pattern) {
            if text[i + j] != pattern[j] {
                matched = false
                break
            }
            j = j + 1
        }
        if matched { return i }
        i = i + 1
    }
    -1
}


func model_slice(string text, int start, int end) string {
    string result = ""
    int begin = start
    int stop = end
    if begin < 0 { begin = 0 }
    if stop > len(text) { stop = len(text) }
    int i = begin
    while i < stop {
        result = result + string(text[i])
        i = i + 1
    }
    result
}


func model_skip_space(string text, int start) int {
    int i = start
    while i < len(text) {
        int ch = text[i]
        if ch != 32 && ch != 9 && ch != 10 && ch != 13 { return i }
        i = i + 1
    }
    i
}


func model_json_value_start(string text, string key) int {
    int key_position = model_find(text, "\"" + key + "\"", 0)
    if key_position < 0 { return -1 }
    int colon = model_find(text, ":", key_position + len(key) + 2)
    if colon < 0 { return -1 }
    model_skip_space(text, colon + 1)
}


func model_json_string(string text, string key) string {
    int start = model_json_value_start(text, key)
    if start < 0 || start >= len(text) || text[start] != 34 { return "" }
    string result = ""
    int i = start + 1
    bool escaped = false
    while i < len(text) {
        int ch = text[i]
        if escaped {
            result = result + string(ch)
            escaped = false
        } else if ch == 92 {
            escaped = true
        } else if ch == 34 {
            return result
        } else {
            result = result + string(ch)
        }
        i = i + 1
    }
    ""
}


func model_json_first_array_string(string text, string key) string {
    int start = model_json_value_start(text, key)
    if start < 0 { return "" }
    int quote = model_find(text, "\"", start)
    if quote < 0 { return "" }
    int end = model_find(text, "\"", quote + 1)
    if end < 0 { return "" }
    model_slice(text, quote + 1, end)
}


func model_json_int(string text, string key, int fallback) int {
    int start = model_json_value_start(text, key)
    if start < 0 { return fallback }
    int sign = 1
    if start < len(text) && text[start] == 45 {
        sign = -1
        start = start + 1
    }
    int value = 0
    bool found = false
    int i = start
    while i < len(text) {
        int ch = text[i]
        if ch < 48 || ch > 57 { break }
        value = value * 10 + ch - 48
        found = true
        i = i + 1
    }
    if !found { return fallback }
    value * sign
}


func model_pow10(int exponent) float {
    float value = 1.0
    int i = 0
    if exponent >= 0 {
        while i < exponent {
            value = value * 10.0
            i = i + 1
        }
    } else {
        while i < 0 - exponent {
            value = value / 10.0
            i = i + 1
        }
    }
    value
}


func model_json_float(string text, string key, float fallback) float {
    int start = model_json_value_start(text, key)
    if start < 0 { return fallback }
    int sign = 1
    if text[start] == 45 {
        sign = -1
        start = start + 1
    }
    float value = 0.0
    bool found = false
    int i = start
    while i < len(text) && text[i] >= 48 && text[i] <= 57 {
        value = value * 10.0 + float(text[i] - 48)
        found = true
        i = i + 1
    }
    if i < len(text) && text[i] == 46 {
        i = i + 1
        float scale = 0.1
        while i < len(text) && text[i] >= 48 && text[i] <= 57 {
            value = value + float(text[i] - 48) * scale
            scale = scale * 0.1
            found = true
            i = i + 1
        }
    }
    int exponent = 0
    int exponent_sign = 1
    if i < len(text) && (text[i] == 101 || text[i] == 69) {
        i = i + 1
        if i < len(text) && text[i] == 45 {
            exponent_sign = -1
            i = i + 1
        } else if i < len(text) && text[i] == 43 {
            i = i + 1
        }
        while i < len(text) && text[i] >= 48 && text[i] <= 57 {
            exponent = exponent * 10 + text[i] - 48
            i = i + 1
        }
    }
    if !found { return fallback }
    value * float(sign) * model_pow10(exponent * exponent_sign)
}


func model_json_bool(string text, string key, bool fallback) bool {
    int start = model_json_value_start(text, key)
    if start < 0 { return fallback }
    if model_find(text, "true", start) == start { return true }
    if model_find(text, "false", start) == start { return false }
    fallback
}


func model_load_config(string directory) hf_model_config {
    string text = runtime_read_text_file(directory + "/config.json")
    hf_model_config config = model_empty_config()
    config.architecture = model_json_first_array_string(text, "architectures")
    config.model_type = model_json_string(text, "model_type")
    config.dtype = model_json_string(text, "torch_dtype")
    config.hidden_act = model_json_string(text, "hidden_act")
    config.vocab_size = model_json_int(text, "vocab_size", 0)
    config.hidden_size = model_json_int(text, "hidden_size", 0)
    config.intermediate_size = model_json_int(text, "intermediate_size", 0)
    config.num_layers = model_json_int(text, "num_hidden_layers", 0)
    config.num_attention_heads = model_json_int(text, "num_attention_heads", 0)
    config.num_kv_heads = model_json_int(text, "num_key_value_heads", config.num_attention_heads)
    config.max_position_embeddings = model_json_int(text, "max_position_embeddings", 0)
    config.sliding_window = model_json_int(text, "sliding_window", 0)
    config.bos_token_id = model_json_int(text, "bos_token_id", -1)
    config.eos_token_id = model_json_int(text, "eos_token_id", -1)
    config.rms_norm_eps = model_json_float(text, "rms_norm_eps", 0.000001)
    config.rope_theta = model_json_float(text, "rope_theta", 10000.0)
    config.tie_word_embeddings = model_json_bool(text, "tie_word_embeddings", false)
    config.use_sliding_window = model_json_bool(text, "use_sliding_window", false)
    config
}


func model_config_valid(hf_model_config config) bool {
    config.model_type != "" && config.vocab_size > 0 && config.hidden_size > 0 && config.intermediate_size > 0 && config.num_layers > 0 && config.num_attention_heads > 0 && config.num_kv_heads > 0 && config.max_position_embeddings > 0 && config.hidden_size / config.num_attention_heads > 0
}


func model_architecture_supported(hf_model_config config) bool {
    config.model_type == "qwen2" || config.model_type == "llama" || config.model_type == "mistral" || config.model_type == "gemma" || config.model_type == "gemma2" || config.model_type == "phi3" || config.model_type == "deepseek_v2"
}


func model_parse_positive_int(string text) int {
    int value = 0
    int i = 0
    while i < len(text) {
        int ch = text[i]
        if ch >= 48 && ch <= 57 { value = value * 10 + ch - 48 }
        i = i + 1
    }
    value
}


func model_file_size(string path) int {
    string output = runtime_run_command_output("stat -c %s " + runtime_shell_escape(path))
    model_parse_positive_int(output)
}


func model_u64_le([]int bytes, int offset) int {
    if offset < 0 || offset + 8 > len(bytes) { return -1 }
    int value = 0
    int multiplier = 1
    int i = 0
    while i < 8 {
        int current = bytes[offset + i]
        if current < 0 { current = current + 256 }
        value = value + current * multiplier
        multiplier = multiplier * 256
        i = i + 1
    }
    value
}


func model_bytes_to_string([]int bytes) string {
    string result = ""
    int i = 0
    while i < len(bytes) {
        int ch = bytes[i]
        if ch < 0 { ch = ch + 256 }
        result = result + string(ch)
        i = i + 1
    }
    result
}


func model_matching_end(string text, int start, int open_char, int close_char) int {
    int depth = 0
    bool in_string = false
    bool escaped = false
    int i = start
    while i < len(text) {
        int ch = text[i]
        if in_string {
            if escaped {
                escaped = false
            } else if ch == 92 {
                escaped = true
            } else if ch == 34 {
                in_string = false
            }
        } else if ch == 34 {
            in_string = true
        } else if ch == open_char {
            depth = depth + 1
        } else if ch == close_char {
            depth = depth - 1
            if depth == 0 { return i }
        }
        i = i + 1
    }
    -1
}


func model_json_int_array(string object_text, string key) []int {
    []int values = []int{cap: 8}
    int start = model_json_value_start(object_text, key)
    if start < 0 || start >= len(object_text) || object_text[start] != 91 { return [] }
    int end = model_matching_end(object_text, start, 91, 93)
    if end < 0 { return [] }
    int i = start + 1
    while i < end {
        i = model_skip_space(object_text, i)
        if i >= end { break }
        int value = 0
        bool found = false
        while i < end && object_text[i] >= 48 && object_text[i] <= 57 {
            value = value * 10 + object_text[i] - 48
            found = true
            i = i + 1
        }
        if found { values = append(values, value) }
        while i < end && object_text[i] != 44 { i = i + 1 }
        if i < end { i = i + 1 }
    }
    values
}


func model_parse_tensor(string name, string object_text, int data_start) safetensors_tensor_manifest {
    []int offsets = model_json_int_array(object_text, "data_offsets")
    safetensors_tensor_manifest tensor
    tensor.name = name
    tensor.dtype = model_json_string(object_text, "dtype")
    tensor.shape = model_json_int_array(object_text, "shape")
    tensor.data_start = -1
    tensor.data_end = -1
    tensor.byte_count = 0
    if len(offsets) == 2 {
        tensor.data_start = data_start + offsets[0]
        tensor.data_end = data_start + offsets[1]
        tensor.byte_count = offsets[1] - offsets[0]
    }
    tensor
}


func model_parse_archive(string path) safetensors_archive_manifest {
    safetensors_archive_manifest archive = model_empty_archive(path)
    if !runtime_file_exists(path) {
        archive.error_message = "safetensors file not found"
        return archive
    }
    archive.file_size = model_file_size(path)
    archive.header_size = model_u64_le(__host_read_binary_file_range(path, 0, 8), 0)
    if archive.header_size <= 0 || archive.header_size > 134217728 {
        archive.error_message = "invalid safetensors header size"
        return archive
    }
    string header = model_bytes_to_string(__host_read_binary_file_range(path, 8, archive.header_size))
    if len(header) != archive.header_size {
        archive.error_message = "incomplete safetensors header"
        return archive
    }
    archive.data_start = 8 + archive.header_size
    int cursor = model_skip_space(header, 0)
    if cursor >= len(header) || header[cursor] != 123 {
        archive.error_message = "safetensors header is not an object"
        return archive
    }
    cursor = cursor + 1
    while cursor < len(header) {
        cursor = model_skip_space(header, cursor)
        if cursor >= len(header) || header[cursor] == 125 { break }
        if header[cursor] != 34 {
            archive.error_message = "invalid safetensors tensor name"
            return archive
        }
        int name_end = model_find(header, "\"", cursor + 1)
        if name_end < 0 {
            archive.error_message = "unterminated safetensors tensor name"
            return archive
        }
        string name = model_slice(header, cursor + 1, name_end)
        int colon = model_find(header, ":", name_end + 1)
        if colon < 0 {
            archive.error_message = "missing safetensors tensor object"
            return archive
        }
        int object_start = model_skip_space(header, colon + 1)
        if object_start >= len(header) || header[object_start] != 123 {
            archive.error_message = "invalid safetensors tensor object"
            return archive
        }
        int object_end = model_matching_end(header, object_start, 123, 125)
        if object_end < 0 {
            archive.error_message = "unterminated safetensors tensor object"
            return archive
        }
        if name != "__metadata__" {
            string object_text = model_slice(header, object_start, object_end + 1)
            safetensors_tensor_manifest tensor = model_parse_tensor(name, object_text, archive.data_start)
            if tensor.dtype == "" || len(tensor.shape) == 0 || tensor.byte_count <= 0 || tensor.data_start < archive.data_start || tensor.data_end > archive.file_size {
                archive.error_message = "invalid tensor metadata: " + name
                return archive
            }
            archive.tensors = append(archive.tensors, tensor)
        }
        cursor = object_end + 1
        cursor = model_skip_space(header, cursor)
        if cursor < len(header) && header[cursor] == 44 { cursor = cursor + 1 }
    }
    if len(archive.tensors) == 0 {
        archive.error_message = "safetensors archive contains no tensors"
        return archive
    }
    archive.valid = true
    archive
}


func model_find_tensor(hf_model_manifest manifest, string name) int {
    int flat_index = 0
    int archive_index = 0
    while archive_index < len(manifest.archives) {
        safetensors_archive_manifest archive = manifest.archives[archive_index]
        int tensor_index = 0
        while tensor_index < len(archive.tensors) {
            if archive.tensors[tensor_index].name == name { return flat_index }
            flat_index = flat_index + 1
            tensor_index = tensor_index + 1
        }
        archive_index = archive_index + 1
    }
    -1
}


func model_manifest_has_required_tensors(hf_model_manifest manifest) bool {
    bool embedding = model_find_tensor(manifest, "model.embed_tokens.weight") >= 0
    bool norm = model_find_tensor(manifest, "model.norm.weight") >= 0
    bool head = manifest.config.tie_word_embeddings || model_find_tensor(manifest, "lm_head.weight") >= 0
    bool first_q = model_find_tensor(manifest, "model.layers.0.self_attn.q_proj.weight") >= 0
    bool last_q = model_find_tensor(manifest, "model.layers." + int_to_str(manifest.config.num_layers - 1) + ".self_attn.q_proj.weight") >= 0
    embedding && norm && head && first_q && last_q
}


func load_hf_model_manifest(string directory) hf_model_manifest {
    hf_model_manifest manifest = model_empty_manifest(directory)
    if !runtime_file_exists(directory + "/config.json") {
        manifest.error_message = "config.json not found"
        return manifest
    }
    manifest.config = model_load_config(directory)
    if !model_config_valid(manifest.config) {
        manifest.error_message = "invalid Hugging Face model config"
        return manifest
    }
    if !model_architecture_supported(manifest.config) {
        manifest.error_message = "model architecture is not supported"
        return manifest
    }
    string archive_path = directory + "/model.safetensors"
    safetensors_archive_manifest archive = model_parse_archive(archive_path)
    if !archive.valid {
        manifest.error_message = archive.error_message
        return manifest
    }
    manifest.archives = append(manifest.archives, archive)
    manifest.tensor_count = len(archive.tensors)
    manifest.weight_bytes = archive.file_size - archive.data_start
    if !model_manifest_has_required_tensors(manifest) {
        manifest.error_message = "required transformer tensors are missing"
        return manifest
    }
    manifest.valid = true
    manifest
}

