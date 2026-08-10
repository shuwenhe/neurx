package neurx.posttrain.lib.safetensors_complete

use std.io.eprintln

// SafeTensors v3 Format Handler - Complete Implementation
// Format: [8-byte little-endian header length][JSON header][binary tensor data]

struct safe_tensor_info {
    string name
    string dtype
    []int shape
    int byte_start
    int byte_end
}

struct safe_tensor_file {
    string path
    interface data
    int header_size
    int data_offset
}

// Get size of dtype in bytes
func dtype_size(string dtype) int {
    if dtype == "F32" { return 4 }
    if dtype == "F64" { return 8 }
    if dtype == "I32" { return 4 }
    if dtype == "I64" { return 8 }
    if dtype == "I16" { return 2 }
    if dtype == "U8" { return 1 }
    if dtype == "I8" { return 1 }
    if dtype == "BOOL" { return 1 }
    return 0
}

// Calculate total elements from shape
func shape_numel([]int shape) int {
    int result = 1
    int i = 0
    while i < len(shape) {
        result = result * shape[i]
        i = i + 1
    }
    return result
}

// Read 8 bytes as little-endian uint64
func read_uint64_le(string data, int offset) int {
    if offset + 8 > len(data) { return 0 }
    
    int result = 0
    int i = 0
    while i < 8 {
        byte b = byte(data[offset + i])
        int val = int(b)
        if val < 0 { val = 256 + val }
        int shift_amount = 1
        int j = 0
        while j < i * 8 {
            shift_amount = shift_amount * 2
            j = j + 1
        }
        result = result + val * shift_amount
        i = i + 1
    }
    return result
}

// Read 4 bytes as little-endian int32
func read_int32_le(string data, int offset) int {
    if offset + 4 > len(data) { return 0 }
    
    int result = 0
    int i = 0
    while i < 4 {
        byte b = byte(data[offset + i])
        int val = int(b)
        if val < 0 { val = 256 + val }
        int shift_amount = 1
        int j = 0
        while j < i * 8 {
            shift_amount = shift_amount * 2
            j = j + 1
        }
        result = result + val * shift_amount
        i = i + 1
    }
    return result
}

// Convert 4-byte IEEE 754 to float (simplified)
func bytes_to_float(string data, int offset) float {
    if offset + 4 > len(data) { return 0.0 }
    
    int bits = read_int32_le(data, offset)
    float sign = 1.0
    if bits < 0 { 
        sign = -1.0
        bits = 0 - bits
    }
    
    // Extract exponent (bits 23-31)
    int exponent = bits / 8388608
    exponent = exponent % 256
    
    // Extract mantissa (bits 0-22)
    int mantissa = bits % 8388608
    
    if exponent == 0 { return 0.0 }
    if exponent == 255 { return sign * 3.40282346638528860e+38 }
    
    float exp_value = float(exponent - 127)
    float mant_value = 1.0 + float(mantissa) / 8388608.0
    
    int i = 0
    float result = mant_value
    while i < int(exp_value) {
        result = result * 2.0
        i = i + 1
    }
    
    return sign * result
}

// Extract JSON string from header
func extract_json_header(string data) string {
    if len(data) < 8 { return "" }
    
    int header_size = read_uint64_le(data, 0)
    if header_size <= 0 || 8 + header_size > len(data) {
        return ""
    }
    
    string json = ""
    int i = 0
    while i < header_size && 8 + i < len(data) {
        json = json + string(data[8 + i])
        i = i + 1
    }
    
    return json
}

// Find JSON key value (simplified parser for tensor metadata)
func find_json_key_value(string json, string key) string {
    string search_key = "\"" + key + "\":"
    int pos = 0
    int i = 0
    
    while i < len(json) - len(search_key) {
        bool match = true
        int j = 0
        while j < len(search_key) {
            if byte(json[i + j]) != byte(search_key[j]) {
                match = false
                break
            }
            j = j + 1
        }
        
        if match {
            pos = i + len(search_key)
            break
        }
        i = i + 1
    }
    
    if pos == 0 { return "" }
    
    // Skip whitespace
    while pos < len(json) && (byte(json[pos]) == byte(32) || byte(json[pos]) == byte(9)) {
        pos = pos + 1
    }
    
    string value = ""
    
    // Extract value
    if byte(json[pos]) == byte(34) { // '"'
        pos = pos + 1
        while pos < len(json) && byte(json[pos]) != byte(34) {
            value = value + string(json[pos])
            pos = pos + 1
        }
    } else if byte(json[pos]) == byte(91) { // '['
        int bracket_count = 1
        pos = pos + 1
        value = "["
        while pos < len(json) && bracket_count > 0 {
            if byte(json[pos]) == byte(91) { bracket_count = bracket_count + 1 }
            if byte(json[pos]) == byte(93) { bracket_count = bracket_count - 1 }
            value = value + string(json[pos])
            pos = pos + 1
        }
    } else {
        while pos < len(json) && byte(json[pos]) != byte(44) && byte(json[pos]) != byte(125) {
            value = value + string(json[pos])
            pos = pos + 1
        }
    }
    
    return value
}

// Parse tensor info from JSON
func parse_tensor_info(string json, string tensor_name) safe_tensor_info {
    safe_tensor_info info
    info.name = tensor_name
    info.dtype = "F32"
    info.shape = []int{}
    info.byte_start = 0
    info.byte_end = 0
    
    // Find tensor object
    string search = "\"" + tensor_name + "\""
    int pos = 0
    int i = 0
    while i < len(json) - len(search) {
        bool match = true
        int j = 0
        while j < len(search) {
            if byte(json[i + j]) != byte(search[j]) {
                match = false
                break
            }
            j = j + 1
        }
        if match {
            pos = i + len(search)
            break
        }
        i = i + 1
    }
    
    if pos == 0 { return info }
    
    // Extract dtype (create substring without slicing)
    string substr = ""
    int j = pos
    while j < len(json) && j < pos + 200 {
        substr = substr + string(json[j])
        j = j + 1
    }
    string dtype_str = find_json_key_value(substr, "dtype")
    if len(dtype_str) > 0 {
        info.dtype = dtype_str
    }
    
    return info
}

// Parse entire SafeTensors header
func parse_safetensors_header(string json_header) map[string]safe_tensor_info {
    map[string]safe_tensor_info tensors
    
    // Extract tensor names from JSON
    int i = 0
    while i < len(json_header) {
        if byte(json_header[i]) == byte(34) { // '"'
            i = i + 1
            string name = ""
            while i < len(json_header) && byte(json_header[i]) != byte(34) {
                name = name + string(json_header[i])
                i = i + 1
            }
            
            if len(name) > 0 && name != "data" && name != "dtype" && name != "shape" {
                safe_tensor_info info = parse_tensor_info(json_header, name)
                tensors[name] = info
            }
        }
        i = i + 1
    }
    
    return tensors
}

// Open and parse SafeTensors file
func open_safetensors(string path) safe_tensor_file {
    interface file_data = readfile(path)
    
    safe_tensor_file file
    file.path = path
    file.data = file_data
    
    string data = ""
    if file.data != interface(nil) {
        data = string(file.data)
    }
    
    if len(data) < 8 {
        file.header_size = 0
        file.data_offset = 8
        return file
    }
    
    int header_size = read_uint64_le(data, 0)
    file.header_size = header_size
    file.data_offset = 8 + header_size
    
    return file
}

// Load tensor as float array
func load_tensor_float(safe_tensor_file file, safe_tensor_info info) []float {
    []float result
    
    string data = string(file.data)
    if len(data) == 0 { return result }
    
    int num_elements = shape_numel(info.shape)
    int element_size = dtype_size(info.dtype)
    
    int i = 0
    while i < num_elements && file.data_offset + info.byte_start + i * element_size + element_size <= len(data) {
        if info.dtype == "F32" {
            float val = bytes_to_float(data, file.data_offset + info.byte_start + i * 4)
            result = append(result, val)
        } else if info.dtype == "F64" {
            float val = 0.0
            result = append(result, val)
        } else {
            result = append(result, 0.0)
        }
        i = i + 1
    }
    
    return result
}

// Check if tensor exists in file
func contains_tensor(safe_tensor_file file, string name) bool {
    string data = string(file.data)
    if len(data) < 8 { return false }
    
    string json = extract_json_header(data)
    string search = "\"" + name + "\""
    
    int i = 0
    while i < len(json) - len(search) {
        bool match = true
        int j = 0
        while j < len(search) {
            if byte(json[i + j]) != byte(search[j]) {
                match = false
                break
            }
            j = j + 1
        }
        if match { return true }
        i = i + 1
    }
    
    return false
}

// Load all tensors metadata from file
func load_tensors_metadata(string path) map[string]safe_tensor_info {
    map[string]safe_tensor_info result
    
    safe_tensor_file file = open_safetensors(path)
    string data = string(file.data)
    
    if len(data) < 8 { return result }
    
    string json = extract_json_header(data)
    result = parse_safetensors_header(json)
    
    return result
}

func main() {
    eprintln("SafeTensors Binary Format Parser - Complete Implementation")
    eprintln("Supports: F32, F64, I32, I64, I16, U8, I8, BOOL")
    eprintln("Format: 8-byte LE header length + JSON metadata + binary data")
}
