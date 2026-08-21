package neurx.inference.safetensors_loader
extern "intrinsic" func __host_read_binary_file_range(string path, int offset, int size) []int
extern "intrinsic" func __host_slice(string text, int start, int end) string

struct tensor_metadata {
    string name
    string dtype
    []int shape
    int data_offset
    int data_size
}

struct safetensors_file {
    []tensor_metadata tensors
    string model_path
    int header_size
    int data_start
}

func read_u64_le([]int bytes, int offset) int {
    if offset + 8 > len(bytes) {
        return 0
    }
    int value = 0
    int mul = 1
    int i = 0
    while i < 8 {
        int b = bytes[offset + i]
        if b < 0 {
            b = b + 256
        }
        value = value + (b * mul)
        mul = mul * 256
        i = i + 1
    }
    return value
}

func parse_safetensors_header(string model_path) safetensors_file {
    []int header_len_bytes = __host_read_binary_file_range(model_path, 0, 8)
    if len(header_len_bytes) < 8 {
        print("[SafeTensors] Failed to read header length\n")
        return safetensors_file{tensors: []tensor_metadata{cap: 0}, model_path: model_path, header_size: 0, data_start: 0}
    }

    int header_size = read_u64_le(header_len_bytes, 0)
    print("[SafeTensors] Header size: " + int_to_string(header_size) + " bytes\n")

    if header_size <= 0 || header_size > 10000000 {
        print("[SafeTensors] Invalid header size\n")
        return safetensors_file{tensors: []tensor_metadata{cap: 0}, model_path: model_path, header_size: 0, data_start: 0}
    }

    []int header_bytes = __host_read_binary_file_range(model_path, 8, header_size)
    if len(header_bytes) < header_size {
        print("[SafeTensors] Failed to read full header\n")
        return safetensors_file{tensors: []tensor_metadata{cap: 0}, model_path: model_path, header_size: 0, data_start: 0}
    }

    string header_json = ""
    int i = 0
    while i < len(header_bytes) {
        int b = header_bytes[i]
        if b < 0 {
            b = b + 256
        }
        if b >= 32 && b <= 126 {
            header_json = header_json + __host_slice("" + string(b), 0, 1)
        } else if b == 10 || b == 13 {
            header_json = header_json + " "
        }
        i = i + 1
    }

    print("[SafeTensors] Parsed header: " + __host_slice(header_json, 0, 200) + "...\n")

    safetensors_file{tensors: []tensor_metadata{cap: 0}, model_path: model_path, header_size: header_size, data_start: 8 + header_size}
}

func get_layer_weight_offset(string layer_name, int layer_idx, string weight_type, int hidden_size, int intermediate_size) int {

    int layer_offset = 0
    if layer_idx > 0 {
        layer_offset = layer_idx * (hidden_size * hidden_size * 3 + hidden_size * intermediate_size * 2)
    }

    if contains_substring(weight_type, "q_proj") {
        return layer_offset
    } else if contains_substring(weight_type, "k_proj") {
        return layer_offset + hidden_size * hidden_size
    } else if contains_substring(weight_type, "v_proj") {
        return layer_offset + hidden_size * hidden_size * 2
    } else if contains_substring(weight_type, "mlp.up") {
        return layer_offset + hidden_size * hidden_size * 3
    }

    return 0
}

func load_embeddings(string model_path, int vocab_size, int hidden_dim) []float {
    []float embeddings = []float{cap: vocab_size * hidden_dim}

    int offset = 8 + 10000
    int embedding_bytes = vocab_size * hidden_dim * 2

    []int weight_data = __host_read_binary_file_range(model_path, offset, embedding_bytes)
    if len(weight_data) < embedding_bytes {
        print("[Embeddings] Failed to load embeddings\n")
        return embeddings
    }

    int idx = 0
    int i = 0
    while i < vocab_size * hidden_dim && idx < len(weight_data) {

        int raw = weight_data[idx]
        if raw < 0 {
            raw = raw + 256
        }
        float val = float(raw - 128) / 128.0
        embeddings[i] = val

        i = i + 1
        idx = idx + 1
    }

    print("[Embeddings] Loaded " + int_to_string(len(embeddings)) + " embedding values\n")
    return embeddings
}

func int_to_string(int value) string {
    if value == 0 {
        return "0"
    }
    string result = ""
    int current = value
    if current < 0 {
        current = 0 - current
    }
    while current > 0 {
        int digit = current - (current / 10) * 10
        if digit == 0 { result = "0" + result }
        else if digit == 1 { result = "1" + result }
        else if digit == 2 { result = "2" + result }
        else if digit == 3 { result = "3" + result }
        else if digit == 4 { result = "4" + result }
        else if digit == 5 { result = "5" + result }
        else if digit == 6 { result = "6" + result }
        else if digit == 7 { result = "7" + result }
        else if digit == 8 { result = "8" + result }
        else if digit == 9 { result = "9" + result }
        current = current / 10
    }
    return result
}

func contains_substring(string haystack, string needle) bool {
    if len(needle) == 0 {
        return true
    }
    if len(haystack) < len(needle) {
        return false
    }
    int i = 0
    while i <= len(haystack) - len(needle) {
        bool matches = true
        int j = 0
        while j < len(needle) {
            if haystack[i + j] != needle[j] {
                matches = false
            }
            j = j + 1
        }
        if matches {
            return true
        }
        i = i + 1
    }
    return false
}
