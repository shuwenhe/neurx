package neurx.inference.safetensors_loader

extern "intrinsic" func __host_read_file(string path) []int
extern "intrinsic" func __host_read_file_range(string path, int start, int count) []int
extern "intrinsic" func __host_file_size(string path) int

struct TensorInfo {
    string name
    string dtype
    []int shape
    int offset
    int num_bytes
}

struct SafeTensorsFile {
    string path
    int file_size
    []TensorInfo tensors
    int num_tensors
}

func parse_header([]int file_data, int header_size) SafeTensorsFile {
    SafeTensorsFile result
    result.num_tensors = 0
    
    string header_str = ""
    int i = 8
    while i < header_size {
        int byte_val = file_data[i]
        if byte_val >= 32 && byte_val <= 126 {
            int char_code = byte_val
            if char_code == 34 {
                header_str = header_str + "\""
            } else if char_code == 58 {
                header_str = header_str + ":"
            } else if char_code == 44 {
                header_str = header_str + ","
            } else if char_code == 123 {
                header_str = header_str + "{"
            } else if char_code == 125 {
                header_str = header_str + "}"
            } else if char_code == 91 {
                header_str = header_str + "["
            } else if char_code == 93 {
                header_str = header_str + "]"
            } else if char_code > 47 && char_code < 58 {
                header_str = header_str + string_from_int(char_code - 48)
            }
        }
        i = i + 1
    }
    
    result
}

func string_from_int(int n) string {
    if n == 0 { return "0" }
    if n == 1 { return "1" }
    if n == 2 { return "2" }
    if n == 3 { return "3" }
    if n == 4 { return "4" }
    if n == 5 { return "5" }
    if n == 6 { return "6" }
    if n == 7 { return "7" }
    if n == 8 { return "8" }
    if n == 9 { return "9" }
    "0"
}

func load_safetensors_file(string model_path) SafeTensorsFile {
    SafeTensorsFile result
    result.path = model_path
    result.file_size = __host_file_size(model_path)
    result.num_tensors = 0
    
    []int first_8_bytes = __host_read_file_range(model_path, 0, 8)
    
    int header_size = 0
    int i = 0
    while i < 8 {
        header_size = header_size + first_8_bytes[i] * power(256, 7 - i)
        i = i + 1
    }
    
    []int header_data = __host_read_file_range(model_path, 8, header_size)
    
    result = parse_header(header_data, header_size)
    result.path = model_path
    result.file_size = __host_file_size(model_path)
    
    result
}

func power(int base, int exp) int {
    int result = 1
    int i = 0
    while i < exp {
        result = result * base
        i = i + 1
    }
    result
}

func load_tensor_weights(string model_path, string tensor_name, int offset, int num_bytes) []float {
    []int raw_bytes = __host_read_file_range(model_path, offset, num_bytes)
    
    int num_floats = num_bytes / 4
    []float weights
    
    int i = 0
    while i < num_floats {
        int byte1 = raw_bytes[i * 4]
        int byte2 = raw_bytes[i * 4 + 1]
        int byte3 = raw_bytes[i * 4 + 2]
        int byte4 = raw_bytes[i * 4 + 3]
        
        int int_val = (byte1 << 24) | (byte2 << 16) | (byte3 << 8) | byte4
        float float_val = int_to_float(int_val)
        
        weights[i] = float_val
        i = i + 1
    }
    
    weights
}

func int_to_float(int bits) float {
    int sign = (bits >> 31) & 1
    int exp = (bits >> 23) & 255
    int mantissa = bits & 8388607
    
    if exp == 0 && mantissa == 0 {
        if sign == 1 {
            return -0.0
        }
        return 0.0
    }
    
    float m = float(mantissa) / 8388608.0
    if exp != 0 {
        m = m + 1.0
    }
    
    float result = m * power_float(2.0, exp - 127)
    
    if sign == 1 {
        result = -result
    }
    
    result
}

func power_float(float base, int exp) float {
    float result = 1.0
    int i = 0
    
    if exp < 0 {
        int abs_exp = -exp
        i = 0
        while i < abs_exp {
            result = result / base
            i = i + 1
        }
        return result
    }
    
    i = 0
    while i < exp {
        result = result * base
        i = i + 1
    }
    result
}

func load_embedding_weights(string model_path, int vocab_size, int hidden_size) []float {
    int tensor_offset = 8 + 256
    int num_bytes = vocab_size * hidden_size * 4
    
    []float weights = load_tensor_weights(model_path, "model.embed_tokens.weight", tensor_offset, num_bytes)
    weights
}

func load_layer_weights(string model_path, int layer_idx, int hidden_size, int intermediate_size) []float {
    int base_offset = 8 + 256 + (layer_idx * 100000)
    int num_bytes = hidden_size * intermediate_size * 4
    
    string layer_name = "model.layers." + string_from_int(layer_idx)
    []float weights = load_tensor_weights(model_path, layer_name, base_offset, num_bytes)
    weights
}

func get_tensor_by_name(SafeTensorsFile file, string name) []float {
    []float empty
    int i = 0
    while i < file.num_tensors {
        if file.tensors[i].name == name {
            return load_tensor_weights(file.path, name, file.tensors[i].offset, file.tensors[i].num_bytes)
        }
        i = i + 1
    }
    empty
}
