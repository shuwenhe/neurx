package neurx.models.formats.safetensors_embedding
import ("neurx.runtime.tensor_builder")
extern "intrinsic" func __std_byte_string(int value) string
extern "intrinsic" func __host_read_binary_file_range(string path, int start, int count) int[]
struct safetensors_embedding {
    bool valid
    string path
    int rows
    int columns
    int data_offset
    int data_bytes
    string dtype
    int element_bytes
    string error_code
}

struct embedding_lookup_result {
    bool ok
    float[] values
    string error_code
}

struct f32_tensor_result {
    bool ok
    safetensors_embedding tensor
    float[] values
    string error_code
}

func st_find(string text, string pattern, int start) int {
    if pattern == "" { return start }
    int i = start
    for i + len(pattern) <= len(text) {
        int j = 0
        bool matches = true
        for j < len(pattern) {
            if text[i + j] != pattern[j] { matches = false; j = len(pattern) } else { j = j + 1 }
        }
        if matches { return i }
        i = i + 1
    }
    -1
}

func st_skip_space(string text, int start) int {
    int i = start
    for i >= 0 && i < len(text) && (text[i] == 32 || text[i] == 9 || text[i] == 10 || text[i] == 13) { i = i + 1 }
    i
}
func st_uint_end(string text, int start) int {
    int i = st_skip_space(text, start)
    int begin = i
    for i >= 0 && i < len(text) && text[i] >= 48 && text[i] <= 57 { i = i + 1 }
    if i == begin { return -1 }
    st_skip_space(text, i)
}
func st_parse_uint(string text, int start) int {
    int value = 0
    int i = st_skip_space(text, start)
    int begin = i
    for i >= 0 && i < len(text) && text[i] >= 48 && text[i] <= 57 {
        int digit = text[i] - 48
        if value > (9223372036854775807 - digit) / 10 { return -1 }
        value = value * 10 + digit
        i = i + 1
    }
    if i == begin { return -1 }
    value
}
func st_field_value(string text, string key, int start, int limit) int {
    string quoted = "\"" + key + "\""
    int position = st_find(text, quoted, start)
    if position < 0 || position >= limit { return -1 }
    position = st_skip_space(text, position + len(quoted))
    if position >= limit || text[position] != 58 { return -1 }
    position = st_skip_space(text, position + 1)
    if position >= limit { return -1 }
    position
}

func st_bytes_to_string(int[] bytes) string { byte_array_string(bytes) }

func st_dtype_code(string dtype) int {
    if dtype == "F32" { return 0 }
    if dtype == "BF16" { return 1 }
    if dtype == "F16" { return 2 }
    -1
}

func st_u64_le(int[] bytes) int {
    if len(bytes) != 8 || bytes[7] >= 128 { return -1 }
    int value = 0
    int scale = 1
    int i = 0
    for i < 8 { value = value + bytes[i] * scale; scale = scale * 256; i = i + 1 }
    value
}

func st_pow2(int exponent) float {
    float value = 1.0
    int i = 0
    if exponent >= 0 {
        for i < exponent { value = value * 2.0; i = i + 1 }
    } else {
        for i > exponent { value = value * 0.5; i = i - 1 }
    }
    value
}

func st_f32_le(int[] bytes, int offset) float {
    int bits = bytes[offset] + bytes[offset + 1] * 256 + bytes[offset + 2] * 65536 + bytes[offset + 3] * 16777216
    int sign = 1
    if bits >= 2147483648 { sign = -1; bits = bits - 2147483648 }
    int exponent = bits / 8388608
    int mantissa = bits % 8388608
    if exponent == 0 { return sign * (mantissa * 1.0 / 8388608.0) * st_pow2(-126) }
    sign * (1.0 + mantissa * 1.0 / 8388608.0) * st_pow2(exponent - 127)
}

func st_bf16_le(int[] bytes, int offset) float {
    int bits = bytes[offset] * 65536 + bytes[offset + 1] * 16777216
    int[] expanded = make(int[], 4)
    expanded[0] = 0
    expanded[1] = 0
    expanded[2] = bits / 65536 % 256
    expanded[3] = bits / 16777216 % 256
    st_f32_le(expanded, 0)
}

func st_f16_le(int[] bytes, int offset) float {
    int bits = bytes[offset] + bytes[offset + 1] * 256
    int sign = 1
    if bits >= 32768 { sign = -1; bits = bits - 32768 }
    int exponent = bits / 1024
    int mantissa = bits % 1024
    if exponent == 0 { return sign * (mantissa * 1.0 / 1024.0) * st_pow2(-14) }
    if exponent == 31 { return sign * 65504.0 }
    sign * (1.0 + mantissa * 1.0 / 1024.0) * st_pow2(exponent - 15)
}

func st_decode(int[] bytes, int offset, string dtype) float {
    if dtype == "BF16" { return st_bf16_le(bytes, offset) }
    if dtype == "F16" { return st_f16_le(bytes, offset) }
    st_f32_le(bytes, offset)
}

func invalid_safetensors_embedding(string path, string code) safetensors_embedding {
    safetensors_embedding { valid: false, path: path, rows: 0, columns: 0, data_offset: 0, data_bytes: 0, dtype: "", element_bytes: 0, error_code: code }
}

func load_f32_tensor(string path, string tensor_name) safetensors_embedding {
    int[] prefix = __host_read_binary_file_range(path, 0, 8)
    int header_size = st_u64_le(prefix)
    if header_size <= 1 || header_size > 1048576 { return invalid_safetensors_embedding(path, "invalid_header_size") }
    int[] header_bytes = __host_read_binary_file_range(path, 8, header_size)
    if len(header_bytes) != header_size { return invalid_safetensors_embedding(path, "truncated_header") }
    string header = st_bytes_to_string(header_bytes)
    int tensor = st_find(header, "\"" + tensor_name + "\"", 0)
    if tensor < 0 { return invalid_safetensors_embedding(path, "tensor_not_found") }
    int object_end = st_find(header, "}", tensor)
    if object_end < 0 { return invalid_safetensors_embedding(path, "invalid_tensor_object") }
    int dtype_start = st_field_value(header, "dtype", tensor, object_end)
    if dtype_start < 0 || header[dtype_start] != 34 { return invalid_safetensors_embedding(path, "missing_dtype") }
    dtype_start = dtype_start + 1
    int dtype_end = st_find(header, "\"", dtype_start)
    if dtype_end < 0 || dtype_end >= object_end { return invalid_safetensors_embedding(path, "missing_dtype") }
    string dtype = ""
    int dtype_cursor = dtype_start
    for dtype_cursor < dtype_end { dtype = dtype + __std_byte_string(header[dtype_cursor]); dtype_cursor = dtype_cursor + 1 }
    int element_bytes = 4
    if dtype == "F16" || dtype == "BF16" { element_bytes = 2 } else if dtype != "F32" { return invalid_safetensors_embedding(path, "unsupported_dtype") }
    int shape = st_field_value(header, "shape", tensor, object_end)
    if shape < 0 || header[shape] != 91 { return invalid_safetensors_embedding(path, "invalid_shape") }
    int rows = 1
    int columns = st_parse_uint(header, shape + 1)
    int cursor = st_uint_end(header, shape + 1)
    if cursor < 0 || cursor >= object_end { return invalid_safetensors_embedding(path, "invalid_shape") }
    if header[cursor] == 44 {
        rows = columns
        columns = st_parse_uint(header, cursor + 1)
        cursor = st_uint_end(header, cursor + 1)
    }
    if cursor < 0 || cursor >= object_end || header[cursor] != 93 || rows <= 0 || columns <= 0 { return invalid_safetensors_embedding(path, "invalid_shape") }
    if rows > 36028797018963967 / columns { return invalid_safetensors_embedding(path, "tensor_size_overflow") }
    int offsets = st_field_value(header, "data_offsets", tensor, object_end)
    if offsets < 0 || header[offsets] != 91 { return invalid_safetensors_embedding(path, "invalid_metadata") }
    int begin = st_parse_uint(header, offsets + 1)
    int offset_comma = st_uint_end(header, offsets + 1)
    if offset_comma < 0 || offset_comma >= object_end || header[offset_comma] != 44 { return invalid_safetensors_embedding(path, "invalid_metadata") }
    int end = st_parse_uint(header, offset_comma + 1)
    int offsets_end = st_uint_end(header, offset_comma + 1)
    if offsets_end < 0 || offsets_end >= object_end || header[offsets_end] != 93 { return invalid_safetensors_embedding(path, "invalid_metadata") }
    if begin < 0 || end <= begin || end > 9223372036854775807 - 8 - header_size || end - begin != rows * columns * element_bytes { return invalid_safetensors_embedding(path, "invalid_tensor_range") }
    safetensors_embedding { valid: true, path: path, rows: rows, columns: columns, data_offset: 8 + header_size + begin, data_bytes: end - begin, dtype: dtype, element_bytes: element_bytes, error_code: "" }
}

func load_f32_embedding(string path, string tensor_name) safetensors_embedding {
    load_f32_tensor(path, tensor_name)
}

func st_read_error(int error) string {
    if error == -61 { return "truncated_tensor" }
    if error == -2 { return "tensor_file_not_found" }
    if error == -75 { return "tensor_size_overflow" }
    if error == -12 { return "tensor_allocation_failed" }
    if error == -22 { return "invalid_tensor_read" }
    "tensor_io_error"
}

func lookup_f32_embedding(safetensors_embedding embedding, int token_id) embedding_lookup_result {
    if !embedding.valid { return embedding_lookup_result { ok: false, values: [], error_code: embedding.error_code } }
    if token_id < 0 || token_id >= embedding.rows { return embedding_lookup_result { ok: false, values: [], error_code: "token_out_of_range" } }
    float_construction_result decoded = read_float_tensor_range(embedding.path, embedding.data_offset + token_id * embedding.columns * embedding.element_bytes, embedding.columns, st_dtype_code(embedding.dtype))
    if !decoded.ok { return embedding_lookup_result { ok: false, values: [], error_code: st_read_error(decoded.error) } }
    embedding_lookup_result { ok: true, values: decoded.values, error_code: "" }
}

func read_f32_tensor(safetensors_embedding tensor) f32_tensor_result {
    if !tensor.valid { return f32_tensor_result { ok: false, tensor: tensor, values: [], error_code: tensor.error_code } }
    if tensor.rows <= 0 || tensor.columns <= 0 || tensor.rows > 36028797018963967 / tensor.columns { return f32_tensor_result { ok: false, tensor: tensor, values: [], error_code: "invalid_tensor_shape" } }
    int count = tensor.rows * tensor.columns
    float_construction_result decoded = read_float_tensor_range(tensor.path, tensor.data_offset, count, st_dtype_code(tensor.dtype))
    if !decoded.ok { return f32_tensor_result { ok: false, tensor: tensor, values: [], error_code: st_read_error(decoded.error) } }
    f32_tensor_result { ok: true, tensor: tensor, values: decoded.values, error_code: "" }
}
