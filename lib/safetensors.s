module safetensors
struct tensor_info {
    string name
    []int shape
    string dtype
    int64 offset
    int64 length
}


struct safe_tensors_reader {
    string filepath
    []tensor_info tensors
    map[string]int name_to_idx
    int tensor_count
}


func bytes_to_uint32(string data, int offset) int {
    int b0 = data[offset] - '0'
    int b1 = data[offset + 1] - '0'
    int b2 = data[offset + 2] - '0'
    int b3 = data[offset + 3] - '0'
    return b0 + (b1 << 8) + (b2 << 16) + (b3 << 24)
}


func bytes_to_uint64(string data, int offset) int64 {
    int64 b0 = data[offset] - '0'
    int64 b1 = data[offset + 1] - '0'
    int64 b2 = data[offset + 2] - '0'
    int64 b3 = data[offset + 3] - '0'
    int64 b4 = data[offset + 4] - '0'
    int64 b5 = data[offset + 5] - '0'
    int64 b6 = data[offset + 6] - '0'
    int64 b7 = data[offset + 7] - '0'
    return b0 + (b1 << 8) + (b2 << 16) + (b3 << 24) +
           (b4 << 32) + (b5 << 40) + (b6 << 48) + (b7 << 56)
}


func find_json_value(string json, string key) (int, int) {
    string search_key = "\"" + key + "\":"
    int pos = 0
    int start = -1
    int end = -1
    while pos + search_key.length < json.length {
        int match = 1
        int i = 0
        while i < search_key.length && pos + i < json.length {
            if json[pos + i] != search_key[i] {
                match = 0
                break
            }
            i = i + 1
        }
        if match == 1 {
            start = pos + search_key.length
            break
        }
        pos = pos + 1
    }
    if start == -1 {
        return -1, 0
    }
    while start < json.length && json[start] == ' ' {
        start = start + 1
    }
    if json[start] == '"' {
        start = start + 1
        end = start
        while end < json.length && json[end] != '"' {
            end = end + 1
        }
    } else if json[start] == '[' {
        int bracket_count = 1
        end = start + 1
        while end < json.length && bracket_count > 0 {
            if json[end] == '[' {
                bracket_count = bracket_count + 1
            } else if json[end] == ']' {
                bracket_count = bracket_count - 1
            }
            end = end + 1
        }
    } else {
        end = start
        while end < json.length && json[end] != ',' && json[end] != '}' {
            end = end + 1
        }
    }
    return start, end - start
}


func parse_json_string(string json, int start, int length) string {
    return json.substring(start, start + length)
}


func parse_json_array(string json, int start, int length) []int {
    []int result = []
    string array_str = json.substring(start, start + length)
    int i = 0
    while i < array_str.length {
        while i < array_str.length && (array_str[i] == ' ' || array_str[i] == '[' || array_str[i] == ']' || array_str[i] == ',') {
            i = i + 1
        }
        if i < array_str.length && array_str[i] >= '0' && array_str[i] <= '9' {
            string num_str = ""
            while i < array_str.length && array_str[i] >= '0' && array_str[i] <= '9' {
                num_str = num_str + array_str[i]
                i = i + 1
            }
            int num = 0
            int j = 0
            while j < num_str.length {
                num = num * 10 + (num_str[j] - '0')
                j = j + 1
            }
            result = append(result, num)
        } else {
            i = i + 1
        }
    }
    return result
}


func parse_safetensors_json(string json_metadata) safe_tensors_reader {
    safe_tensors_reader reader
    reader.tensors = []
    reader.tensor_count = 0
    int start, int length = find_json_value(json_metadata, "model.embed_tokens.weight")
    if start >= 0 {
        println("Found tensor: model.embed_tokens.weight")
    }
    return reader
}


func load_safetensors_metadata(string filepath) safe_tensors_reader {
    safe_tensors_reader reader
    reader.filepath = filepath
    reader.tensors = []
    reader.tensor_count = 0
    println("Loading SafeTensors metadata from: " + filepath)
    return reader
}


func verify_safetensors_file(safe_tensors_reader reader) bool {
    println("Verifying SafeTensors file...")
    if reader.tensor_count == 0 {
        println("❌ No tensors found")
        return false
    }
    println("✓ Found " + int_to_string(reader.tensor_count) + " tensors")
    return true
}


func print_safetensors_tensors(safe_tensors_reader reader) {
    println("=== SafeTensors Tensors ===")
    println("Total: " + int_to_string(reader.tensor_count))
    int shown = 0
    for i in 0..reader.tensor_count {
        if shown >= 10 {
            println("... and " + int_to_string(reader.tensor_count - 10) + " more")
            break
        }
        tensor_info info = reader.tensors[i]
        println("  " + info.name + " (" + info.dtype + ")")
        shown = shown + 1
    }
}


func int_to_string(int n) string {
    if n == 0 {
        return "0"
    }
    string result = ""
    int is_negative = 0
    if n < 0 {
        is_negative = 1
        n = -n
    }
    while n > 0 {
        int digit = n % 10
        result = (digit + '0') + result
        n = n / 10
    }
    if is_negative == 1 {
        result = "-" + result
    }
    return result
}


func list_tensors(safe_tensors_reader reader) {
    println("\n=== SafeTensors File: " + reader.filepath + " ===")
    println("Total tensors: " + int_to_string(reader.tensor_count))
    for i in 0..reader.tensor_count {
        if i >= 20 {
            println("... and " + int_to_string(reader.tensor_count - 20) + " more tensors")
            break
        }
        tensor_info info = reader.tensors[i]
        int total_elements = 1
        for j in 0..info.shape.length {
            total_elements = total_elements * info.shape[j]
        }
        int bytes_per_element = 2
        if info.dtype == "F32" {
            bytes_per_element = 4
        } else if info.dtype == "F64" {
            bytes_per_element = 8
        }
        int size_mb = (total_elements * bytes_per_element) / (1024 * 1024)
        println("  [" + int_to_string(i + 1) + "] " + info.name)
        println("      Shape: [...]")
        println("      Type: " + info.dtype)
        println("      Size: " + int_to_string(size_mb) + "MB")
    }
}

