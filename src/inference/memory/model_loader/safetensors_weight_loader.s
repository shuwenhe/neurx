package neurx.inference.safetensors_weight_loader
use std.encoding.bytes_to_string
extern "intrinsic" func __host_read_binary_file_range(string path, int start, int count) int[]
extern "intrinsic" func __host_read_binary_file(string path) int[]
extern "intrinsic" func __host_file_exists(string path) bool
extern "intrinsic" func __host_slice(string text, int start, int end) string
struct tensor_meta {
    string name
    int[] shape
    string dtype
    int data_offset
    int data_length
    int num_elements
}

struct safetensors_header {
    string path
    int header_length
    []tensor_meta tensors
    int total_tensors
    int data_start
    bool valid
}

func load_safetensors_header(string path) safetensors_header {
    safetensors_header hdr = safetensors_header{
        path: path,
        header_length: 0,
        tensors: []tensor_meta{},
        total_tensors: 0,
        data_start: 0,
        valid: false,
    }
    if !__host_file_exists(path) {
        return hdr
    }
    int[] prefix = __host_read_binary_file_range(path, 0, 8)
    if len(prefix) < 8 {
        return hdr
    }
    int header_len = prefix[0]
    header_len = header_len + prefix[1] * 256
    header_len = header_len + prefix[2] * 65536
    header_len = header_len + prefix[3] * 16777216
    hdr.header_length = header_len
    hdr.data_start = 8 + header_len
    int[] header_bytes = __host_read_binary_file_range(path, 8, header_len)
    string json = bytes_to_string(header_bytes)
    []tensor_meta tensors = parse_header_json(json)
    hdr.tensors = tensors
    hdr.total_tensors = len(tensors)
    hdr.valid = len(tensors) > 0
    hdr
}

func skip_ws(string json, int pos) int {
    for pos < len(json) {
        int ch = int(json[pos])
        if ch == 32 || ch == 10 || ch == 13 || ch == 9 {
            pos = pos + 1
        } else {
            break
        }
    }
    pos
}

func parse_header_json(string json) []tensor_meta {
    []tensor_meta tensors = []tensor_meta{}
    int pos = skip_ws(json, 0)
    if pos >= len(json) || int(json[pos]) != 123 {
        return tensors
    }
    pos = pos + 1
    for pos < len(json) {
        pos = skip_ws(json, pos)
        if pos >= len(json) {
            break
        }
        if int(json[pos]) == 125 {
            break
        }
        if int(json[pos]) == 44 {
            pos = pos + 1
            continue
        }
        string key = ""
        (string k, int next) = parse_json_string(json, pos)
        key = k
        pos = next
        pos = skip_ws(json, pos)
        if pos >= len(json) || int(json[pos]) != 58 {
            break
        }
        pos = pos + 1
        pos = skip_ws(json, pos)
        if pos >= len(json) {
            break
        }
        if int(json[pos]) == 123 {
            tensor_meta t = parse_tensor_object(json, pos, key)
            pos = find_object_end(json, pos)
            if t.name != "" && t.name != "__metadata__" {
                tensors = append(tensors, t)
            }
        } else if int(json[pos]) == 34 {
            (string v, int after) = parse_json_string(json, pos)
            pos = after
        } else {
            pos = skip_value(json, pos)
        }
    }
    tensors
}

func parse_json_string(string json, int start) (string, int) {
    int pos = start
    for pos < len(json) && int(json[pos]) != 34 {
        pos = pos + 1
    }
    if pos >= len(json) {
        return "", pos
    }
    pos = pos + 1
    string result = ""
    for pos < len(json) && int(json[pos]) != 34 {
        if int(json[pos]) == 92 && pos + 1 < len(json) {
            pos = pos + 1
        }
        result = result + string(json[pos])
        pos = pos + 1
    }
    if pos < len(json) {
        pos = pos + 1
    }
    (result, pos)
}

func parse_tensor_object(string json, int start, string name) tensor_meta {
    tensor_meta t = tensor_meta{name: name, shape: []int{}, dtype: "", data_offset: 0, data_length: 0, num_elements: 0}
    int pos = start + 1
    for pos < len(json) {
        pos = skip_ws(json, pos)
        if pos >= len(json) {
            break
        }
        if int(json[pos]) == 125 {
            break
        }
        if int(json[pos]) == 44 {
            pos = pos + 1
            continue
        }
        (string key, int after_key) = parse_json_string(json, pos)
        pos = skip_ws(json, after_key)
        if pos >= len(json) || int(json[pos]) != 58 {
            break
        }
        pos = pos + 1
        pos = skip_ws(json, pos)
        if key == "dtype" {
            (string v, int next) = parse_json_string(json, pos)
            t.dtype = v
            pos = next
        } else if key == "data_offsets" {
            (int[] offsets, int next) = parse_int_array(json, pos)
            if len(offsets) >= 2 {
                t.data_offset = offsets[0]
                t.data_length = offsets[1] - offsets[0]
            }
            pos = next
        } else if key == "shape" {
            (int[] shape, int next) = parse_int_array(json, pos)
            t.shape = shape
            pos = next
        } else {
            pos = skip_value(json, pos)
        }
    }
    int nelem = 1
    int i = 0
    for i < len(t.shape) {
        nelem = nelem * t.shape[i]
        i = i + 1
    }
    t.num_elements = nelem
    t
}

func parse_int_array(string json, int start) (int[], int) {
    int[] result = []int{}
    int pos = start
    for pos < len(json) && int(json[pos]) != 91 {
        pos = pos + 1
    }
    if pos >= len(json) {
        return result, pos
    }
    pos = pos + 1
    for pos < len(json) && int(json[pos]) != 93 {
        pos = skip_ws(json, pos)
        if pos >= len(json) || int(json[pos]) == 93 {
            break
        }
        bool neg = false
        if int(json[pos]) == 45 {
            neg = true
            pos = pos + 1
        }
        int val = 0
        bool found = false
        for pos < len(json) && int(json[pos]) >= 48 && int(json[pos]) <= 57 {
            val = val * 10 + int(json[pos]) - 48
            found = true
            pos = pos + 1
        }
        if found {
            if neg {
                val = 0 - val
            }
            result = append(result, val)
        }
        pos = skip_ws(json, pos)
        if pos < len(json) && int(json[pos]) == 44 {
            pos = pos + 1
        }
    }
    if pos < len(json) && int(json[pos]) == 93 {
        pos = pos + 1
    }
    (result, pos)
}

func find_object_end(string json, int start) int {
    int depth = 0
    int pos = start
    for pos < len(json) {
        int ch = int(json[pos])
        if ch == 123 {
            depth = depth + 1
        } else if ch == 125 {
            depth = depth - 1
            if depth == 0 {
                return pos + 1
            }
        }
        pos = pos + 1
    }
    pos
}

func skip_value(string json, int pos) int {
    if pos >= len(json) {
        return pos
    }
    int ch = int(json[pos])
    if ch == 34 {
        (string _, int next) = parse_json_string(json, pos)
        return next
    }
    if ch == 123 {
        return find_object_end(json, pos)
    }
    if ch == 91 {
        int depth = 0
        for pos < len(json) {
            int c = int(json[pos])
            if c == 91 {
                depth = depth + 1
            } else if c == 93 {
                depth = depth - 1
                if depth == 0 {
                    return pos + 1
                }
            }
            pos = pos + 1
        }
        return pos
    }
    for pos < len(json) {
        int c = int(json[pos])
        if c == 44 || c == 125 || c == 93 {
            break
        }
        pos = pos + 1
    }
    pos
}

func find_tensor(safetensors_header hdr, string name) int {
    int i = 0
    for i < hdr.total_tensors {
        if hdr.tensors[i].name == name {
            return i
        }
        i = i + 1
    }
    -1
}

func load_tensor_floats(safetensors_header hdr, string name) []float {
    int idx = find_tensor(hdr, name)
    if idx < 0 {
        return []float{}
    }
    tensor_meta meta = hdr.tensors[idx]
    int byte_offset = hdr.data_start + meta.data_offset
    int byte_count = meta.data_length
    int int_count = byte_count
    int[] raw = __host_read_binary_file_range(hdr.path, byte_offset, int_count)
    float[] result = make(float[], meta.num_elements)
    int dtype_size = 4
    if meta.dtype == "F32" || meta.dtype == "BF16" || meta.dtype == "F16" {
        dtype_size = 4
    }
    int i = 0
    for i < meta.num_elements && i * dtype_size + 3 < len(raw) {
        int b0 = raw[i * dtype_size]
        int b1 = raw[i * dtype_size + 1]
        int b2 = raw[i * dtype_size + 2]
        int b3 = raw[i * dtype_size + 3]
        result[i] = ints_to_float(b0, b1, b2, b3)
        i = i + 1
    }
    result
}

func ints_to_float(int b0, int b1, int b2, int b3) float {
    int bits = b0 + b1 * 256 + b2 * 65536 + b3 * 16777216
    int sign_bit = bits / 2147483648
    int exp_bits = (bits / 8388608) % 256
    int mantissa = bits % 8388608
    float sign = 1.0
    if sign_bit != 0 {
        sign = -1.0
    }
    if exp_bits == 0 {
        if mantissa == 0 {
            return 0.0
        }
        float m = float(mantissa) / 8388608.0
        return sign * m * pow2(-126)
    }
    if exp_bits == 255 {
        return sign * 3.4028235e38
    }
    float exp_val = pow2(exp_bits - 127)
    float mantissa_val = 1.0 + float(mantissa) / 8388608.0
    sign * mantissa_val * exp_val
}

func pow2(int n) float {
    float result = 1.0
    if n > 0 {
        int i = 0
        for i < n {
            result = result * 2.0
            i = i + 1
        }
    } else {
        int i = n
        for i < 0 {
            result = result / 2.0
            i = i + 1
        }
    }
    result
}

func has_tensor(safetensors_header hdr, string name) bool {
    find_tensor(hdr, name) >= 0
}

func tensor_names(safetensors_header hdr) []string {
    string[] names = []string{}
    int i = 0
    for i < hdr.total_tensors {
        names = append(names, hdr.tensors[i].name)
        i = i + 1
    }
    names
}
