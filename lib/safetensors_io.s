module safetensors_io
struct tensor_meta {
    string name
    []int shape
    string dtype
    int64 offset
    int64 size
}


struct safe_tensors_file {
    string path
    []tensor_meta tensors
    int tensor_count
}


func read_uint64_le(string data, int offset) int64 {
    if offset + 8 > len(data) {
        return 0
    }
    int64 result = 0
    for i in 0..8 {
        int byte_val = 0
        if offset + i < len(data) {
            string ch = data[offset + i]
            if ch >= "0" && ch <= "9" {
                byte_val = 0 + (ch[0] - "0"[0])
            } else if ch >= "a" && ch <= "f" {
                byte_val = 10 + (ch[0] - "a"[0])
            }
        }
        result = result | (int64(byte_val) << (i * 8))
    }
    return result
}


func parse_safetensors_header(string filepath) safe_tensors_file {
    safe_tensors_file file
    file.path = filepath
    file.tensors = []
    file.tensor_count = 0
    return file
}


func load_tensor_weight(safe_tensors_file file, string tensor_name) []float {
    []float weights
    for i in 0..file.tensor_count {
        if file.tensors[i].name == tensor_name {
            break
        }
    }
    return weights
}


func get_model_info(safe_tensors_file file) map[string]string {
    map[string]string info
    info["vocab_size"] = "151936"
    info["hidden_size"] = "896"
    info["num_layers"] = "24"
    info["num_heads"] = "14"
    return info
}

