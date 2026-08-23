package neurx.models.formats.safetensors_embedding

extern "intrinsic" func __host_read_binary_file_range(string path, int start, int count) []int

struct safetensors_embedding {
    bool valid
    string path
    int rows
    int columns
    int data_offset
    int data_bytes
    string error_code
}

struct embedding_lookup_result {
    bool ok
    []float values
    string error_code
}

struct f32_tensor_result {
    bool ok
    safetensors_embedding tensor
    []float values
    string error_code
}

func st_find(string text, string pattern, int start) int {
    if pattern == "" { return start }
    int i = start
    while i + len(pattern) <= len(text) {
        int j = 0
        bool matches = true
        while j < len(pattern) {
            if text[i + j] != pattern[j] { matches = false; j = len(pattern) } else { j = j + 1 }
        }
        if matches { return i }
        i = i + 1
    }
    -1
}

func st_parse_uint(string text, int start) int {
    int value = 0
    int i = start
    bool found = false
    while i < len(text) {
        int ch = int(text[i])
        if ch >= 48 && ch <= 57 { found = true; value = value * 10 + ch - 48; i = i + 1 } else { i = len(text) }
    }
    if !found { return -1 }
    value
}

func st_bytes_to_string([]int bytes) string {
    string text = ""
    int i = 0
    while i < len(bytes) { text = text + string(bytes[i]); i = i + 1 }
    text
}

func st_u64_le([]int bytes) int {
    if len(bytes) != 8 { return -1 }
    int value = 0
    int scale = 1
    int i = 0
    while i < 8 { value = value + bytes[i] * scale; scale = scale * 256; i = i + 1 }
    value
}

func st_pow2(int exponent) float {
    float value = 1.0
    int i = 0
    if exponent >= 0 {
        while i < exponent { value = value * 2.0; i = i + 1 }
    } else {
        while i > exponent { value = value * 0.5; i = i - 1 }
    }
    value
}

func st_f32_le([]int bytes, int offset) float {
    int bits = bytes[offset] + bytes[offset + 1] * 256 + bytes[offset + 2] * 65536 + bytes[offset + 3] * 16777216
    int sign = 1
    if bits >= 2147483648 { sign = -1; bits = bits - 2147483648 }
    int exponent = bits / 8388608
    int mantissa = bits % 8388608
    if exponent == 0 { return sign * (mantissa * 1.0 / 8388608.0) * st_pow2(-126) }
    sign * (1.0 + mantissa * 1.0 / 8388608.0) * st_pow2(exponent - 127)
}

func invalid_safetensors_embedding(string path, string code) safetensors_embedding {
    safetensors_embedding { valid: false, path: path, rows: 0, columns: 0, data_offset: 0, data_bytes: 0, error_code: code }
}

func load_f32_tensor(string path, string tensor_name) safetensors_embedding {
    []int prefix = __host_read_binary_file_range(path, 0, 8)
    int header_size = st_u64_le(prefix)
    if header_size <= 1 || header_size > 1048576 { return invalid_safetensors_embedding(path, "invalid_header_size") }
    []int header_bytes = __host_read_binary_file_range(path, 8, header_size)
    if len(header_bytes) != header_size { return invalid_safetensors_embedding(path, "truncated_header") }
    string header = st_bytes_to_string(header_bytes)
    int tensor = st_find(header, "\"" + tensor_name + "\"", 0)
    if tensor < 0 { return invalid_safetensors_embedding(path, "tensor_not_found") }
    int dtype = st_find(header, "\"dtype\":\"F32\"", tensor)
    if dtype < 0 { return invalid_safetensors_embedding(path, "unsupported_dtype") }
    int shape = st_find(header, "\"shape\":[", dtype)
    int comma = st_find(header, ",", shape + 9)
    int shape_end = st_find(header, "]", shape + 9)
    if shape < 0 || shape_end < 0 { return invalid_safetensors_embedding(path, "invalid_shape") }
    int rows = 1
    int columns = st_parse_uint(header, shape + 9)
    if comma >= 0 && comma < shape_end { rows = columns; columns = st_parse_uint(header, comma + 1) }
    int offsets = st_find(header, "\"data_offsets\":[", shape_end)
    int offset_comma = st_find(header, ",", offsets + 16)
    int offsets_end = st_find(header, "]", offset_comma + 1)
    if rows <= 0 || columns <= 0 || offsets < 0 || offset_comma < 0 || offsets_end < 0 { return invalid_safetensors_embedding(path, "invalid_metadata") }
    int begin = st_parse_uint(header, offsets + 16)
    int end = st_parse_uint(header, offset_comma + 1)
    if begin < 0 || end <= begin || end - begin != rows * columns * 4 { return invalid_safetensors_embedding(path, "invalid_tensor_range") }
    safetensors_embedding { valid: true, path: path, rows: rows, columns: columns, data_offset: 8 + header_size + begin, data_bytes: end - begin, error_code: "" }
}

func load_f32_embedding(string path, string tensor_name) safetensors_embedding {
    load_f32_tensor(path, tensor_name)
}

func lookup_f32_embedding(safetensors_embedding embedding, int token_id) embedding_lookup_result {
    if !embedding.valid { return embedding_lookup_result { ok: false, values: [], error_code: embedding.error_code } }
    if token_id < 0 || token_id >= embedding.rows { return embedding_lookup_result { ok: false, values: [], error_code: "token_out_of_range" } }
    []int bytes = __host_read_binary_file_range(embedding.path, embedding.data_offset + token_id * embedding.columns * 4, embedding.columns * 4)
    if len(bytes) != embedding.columns * 4 { return embedding_lookup_result { ok: false, values: [], error_code: "truncated_tensor" } }
    []float values = []float{cap: embedding.columns}
    int i = 0
    while i < embedding.columns { values[i] = st_f32_le(bytes, i * 4); i = i + 1 }
    embedding_lookup_result { ok: true, values: values, error_code: "" }
}

func read_f32_tensor(safetensors_embedding tensor) f32_tensor_result {
    if !tensor.valid { return f32_tensor_result { ok: false, tensor: tensor, values: [], error_code: tensor.error_code } }
    []int bytes = __host_read_binary_file_range(tensor.path, tensor.data_offset, tensor.data_bytes)
    if len(bytes) != tensor.data_bytes { return f32_tensor_result { ok: false, tensor: tensor, values: [], error_code: "truncated_tensor" } }
    int count = tensor.rows * tensor.columns
    []float values = []float{cap: count}
    int i = 0
    while i < count { values[i] = st_f32_le(bytes, i * 4); i = i + 1 }
    f32_tensor_result { ok: true, tensor: tensor, values: values, error_code: "" }
}
