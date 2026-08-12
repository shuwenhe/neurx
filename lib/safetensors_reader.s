module safetensors_reader
struct tensor_metadata {
    string name
    []int shape
    string dtype
    int64 data_offset
    int64 data_length
}


struct safetensors_file {
    string file_path
    int64 file_size
    []tensor_metadata tensors
    map[string]int tensor_name_to_index
}


func skip_whitespace(string json, int pos) int {
    while pos < json.length && (json[pos] == ' ' || json[pos] == '\n' || json[pos] == '\t' || json[pos] == '\r') {
        pos = pos + 1
    }
    return pos
}


func extract_string_value(string json, int start_pos) (string, int) {
    int i = start_pos
    string result = ""
    while i < json.length && json[i] != '"' {
        i = i + 1
    }
    i = i + 1
    while i < json.length && json[i] != '"' {
        result = result + json[i]
        i = i + 1
    }
    i = i + 1
    return result, i
}


func extract_number_value(string json, int start_pos) (int64, int) {
    int i = start_pos
    string num_str = ""
    while i < json.length && ((json[i] >= '0' && json[i] <= '9') || json[i] == '-') {
        num_str = num_str + json[i]
        i = i + 1
    }
    int64 result = 0
    int sign = 1
    int j = 0
    if num_str[0] == '-' {
        sign = -1
        j = 1
    }
    while j < num_str.length {
        result = result * 10 + (num_str[j] - '0')
        j = j + 1
    }
    return result * sign, i
}


func extract_array_values(string json, int start_pos) ([]int, int) {
    []int result = []
    int i = start_pos
    while i < json.length && json[i] != '[' {
        i = i + 1
    }
    i = i + 1
    while i < json.length && json[i] != ']' {
        i = skip_whitespace(json, i)
        if json[i] >= '0' && json[i] <= '9' {
            string num_str = ""
            while i < json.length && json[i] >= '0' && json[i] <= '9' {
                num_str = num_str + json[i]
                i = i + 1
            }
            int num = 0
            int k = 0
            while k < num_str.length {
                num = num * 10 + (num_str[k] - '0')
                k = k + 1
            }
            result = append(result, num)
        }
        while i < json.length && (json[i] == ',' || json[i] == ' ' || json[i] == '\t') {
            i = i + 1
        }
    }
    i = i + 1
    return result, i
}


func load_safetensors_header(string file_path) safetensors_file {
    safetensors_file result
    result.file_path = file_path
    println("Loading SafeTensors header from: " + file_path)
    return result
}


func verify_safetensors(safetensors_file file) bool {
    println("Verifying SafeTensors file: " + file.file_path)
    if file.tensors.length == 0 {
        println("❌ Error: No tensors found in file")
        return false
    }
    println("✓ SafeTensors verification passed")
    println("  Total tensors: " + int_to_string(file.tensors.length))
    return true
}


func get_tensor_metadata(safetensors_file file, string tensor_name) tensor_metadata {
    tensor_metadata empty_meta
    if tensor_name not in file.tensor_name_to_index {
        println("❌ tensor_2 not found: " + tensor_name)
        return empty_meta
    }
    int index = file.tensor_name_to_index[tensor_name]
    return file.tensors[index]
}


func print_tensor_info(safetensors_file file) {
    println("=== SafeTensors Tensors ===")
    int count = 0
    for i in 0..file.tensors.length {
        if count >= 10 {
            println("... and " + int_to_string(file.tensors.length - 10) + " more")
            break
        }
        tensor_metadata meta = file.tensors[i]
        println(meta.name + ": shape=[...], dtype=" + meta.dtype)
        count = count + 1
    }
}


func int_to_string(int n) string {
    if n == 0 {
        return "0"
    }
    string result = ""
    int abs_n = n
    int is_negative = 0
    if n < 0 {
        is_negative = 1
        abs_n = -n
    }
    while abs_n > 0 {
        int digit = abs_n % 10
        result = digit + "0" + result
        abs_n = abs_n / 10
    }
    if is_negative == 1 {
        result = "-" + result
    }
    return result
}


func int_to_hex(int n) string {
    string hex_chars = "0123456789ABCDEF"
    string result = "0x"
    if n == 0 {
        return "0x0"
    }
    while n > 0 {
        int digit = n % 16
        result = hex_chars[digit] + result
        n = n / 16
    }
    return result
}

