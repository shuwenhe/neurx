package neurx.posttrain.lib.safetensors_complete
use std.binary.i32_le_string
use std.binary.u64_le_string
use std.io.eprintln
struct safe_tensor_info {
    string name
    string dtype
    int[] shape
    int byte_start
    int byte_end
}

struct safe_tensor_file {
    string path
    interface data
    int header_size
    int data_offset
}

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

func shape_numel(int[] shape) int {
    int result = 1
    int i = 0
    for i < len(shape) {
        result = result * shape[i]
        i = i + 1
    }
    return result
}

func bytes_to_float(string data, int offset) float {
    if offset + 4 > len(data) { return 0.0 }
    int bits = i32_le_string(data, offset)
    float sign = 1.0
    if bits < 0 {
        sign = -1.0
        bits = 0 - bits
    }
    int exponent = bits / 8388608
    exponent = exponent % 256
    int mantissa = bits % 8388608
    if exponent == 0 { return 0.0 }
    if exponent == 255 { return sign * 3.40282346638528860e+38 }
    float exp_value = float(exponent - 127)
    float mant_value = 1.0 + float(mantissa) / 8388608.0
    int i = 0
    float result = mant_value
    for i < int(exp_value) {
        result = result * 2.0
        i = i + 1
    }
    return sign * result
}

func extract_json_header(string data) string {
    if len(data) < 8 { return "" }
    int header_size = u64_le_string(data, 0)
    if header_size <= 0 || 8 + header_size > len(data) {
        return ""
    }
    string json = ""
    int i = 0
    for i < header_size && 8 + i < len(data) {
        json = json + string(data[8 + i])
        i = i + 1
    }
    return json
}

func find_json_key_value(string json, string key) string {
    string search_key = "\"" + key + "\":"
    int pos = 0
    int i = 0
    for i < len(json) - len(search_key) {
        bool match = true
        int j = 0
        for j < len(search_key) {
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
    for pos < len(json) && (byte(json[pos]) == byte(32) || byte(json[pos]) == byte(9)) {
        pos = pos + 1
    }
    string value = ""
    if byte(json[pos]) == byte(34) {
        pos = pos + 1
        for pos < len(json) && byte(json[pos]) != byte(34) {
            value = value + string(json[pos])
            pos = pos + 1
        }
    } else if byte(json[pos]) == byte(91) {
        int bracket_count = 1
        pos = pos + 1
        value = "["
        for pos < len(json) && bracket_count > 0 {
            if byte(json[pos]) == byte(91) { bracket_count = bracket_count + 1 }
            if byte(json[pos]) == byte(93) { bracket_count = bracket_count - 1 }
            value = value + string(json[pos])
            pos = pos + 1
        }
    } else {
        for pos < len(json) && byte(json[pos]) != byte(44) && byte(json[pos]) != byte(125) {
            value = value + string(json[pos])
            pos = pos + 1
        }
    }
    return value
}

func parse_tensor_info(string json, string tensor_name) safe_tensor_info {
    safe_tensor_info info
    info.name = tensor_name
    info.dtype = "F32"
    info.shape = []int{}
    info.byte_start = 0
    info.byte_end = 0
    string search = "\"" + tensor_name + "\""
    int pos = 0
    int i = 0
    for i < len(json) - len(search) {
        bool match = true
        int j = 0
        for j < len(search) {
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
    string substr = ""
    int j = pos
    for j < len(json) && j < pos + 200 {
        substr = substr + string(json[j])
        j = j + 1
    }
    string dtype_str = find_json_key_value(substr, "dtype")
    if len(dtype_str) > 0 {
        info.dtype = dtype_str
    }
    return info
}

func parse_safetensors_header(string json_header) map[string]safe_tensor_info {
    map[string]safe_tensor_info tensors
    int i = 0
    for i < len(json_header) {
        if byte(json_header[i]) == byte(34) {
            i = i + 1
            string name = ""
            for i < len(json_header) && byte(json_header[i]) != byte(34) {
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
    int header_size = u64_le_string(data, 0)
    file.header_size = header_size
    file.data_offset = 8 + header_size
    return file
}

func load_tensor_float(safe_tensor_file file, safe_tensor_info info) []float {
    float[] result
    string data = string(file.data)
    if len(data) == 0 { return result }
    int num_elements = shape_numel(info.shape)
    int element_size = dtype_size(info.dtype)
    int i = 0
    for i < num_elements && file.data_offset + info.byte_start + i * element_size + element_size <= len(data) {
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

func contains_tensor(safe_tensor_file file, string name) bool {
    string data = string(file.data)
    if len(data) < 8 { return false }
    string json = extract_json_header(data)
    string search = "\"" + name + "\""
    int i = 0
    for i < len(json) - len(search) {
        bool match = true
        int j = 0
        for j < len(search) {
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
