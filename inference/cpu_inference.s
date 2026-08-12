package neurx.inference.model_cpu_inference
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
extern "intrinsic" func __host_read_binary_file_range(string path, int start, int count) []int
extern "intrinsic" func __host_slice(string text, int start, int end) string
struct tensor_location {
    int offset
    int byte_size
    bool found
}


struct safetensors_model {
    string path
    []int metadata
    int data_offset
}


func int_to_string(int value) string {
    if value == 0 { return "0" }
    string sign = ""
    int current = value
    if current < 0 {
        sign = "-"
        current = 0 - current
    }
    string out = ""
    string digits = "0123456789"
    while current > 0 {
        int digit = current - (current / 10) * 10
        out = __host_slice(digits, digit, digit + 1) + out
        current = current / 10
    }
    sign + out
}


func pow_int(int base, int exponent) int {
    int value = 1
    int i = 0
    while i < exponent {
        value = value * base
        i = i + 1
    }
    value
}


func u64_le([]int bytes, int offset) int {
    if offset < 0 || offset + 8 > len(bytes) { return 0 }
    int value = 0
    int i = 0
    while i < 8 {
        int part = bytes[offset + i]
        if part < 0 { part = part + 256 }
        value = value + part * pow_int(256, i)
        i = i + 1
    }
    value
}


func find_bytes([]int bytes, string needle, int start) int {
    if len(needle) == 0 { return start }
    int i = start
    if i < 0 { i = 0 }
    while i + len(needle) <= len(bytes) {
        int j = 0
        while j < len(needle) && bytes[i + j] == needle[j] {
            j = j + 1
        }
        if j == len(needle) { return i }
        i = i + 1
    }
    -1
}


func skip_to_digit([]int bytes, int start) int {
    int i = start
    while i < len(bytes) {
        if bytes[i] >= 48 && bytes[i] <= 57 { return i }
        i = i + 1
    }
    -1
}


func parse_uint([]int bytes, int start) int {
    int i = start
    int value = 0
    while i < len(bytes) && bytes[i] >= 48 && bytes[i] <= 57 {
        value = value * 10 + bytes[i] - 48
        i = i + 1
    }
    value
}


func open_model(string path) safetensors_model {
    []int prefix = __host_read_binary_file_range(path, 0, 8)
    int header_size = u64_le(prefix, 0)
    return safetensors_model{
        path: path,
        metadata: __host_read_binary_file_range(path, 8, header_size),
        data_offset: 8 + header_size
    }
}


func find_tensor(safetensors_model model, string name) tensor_location {
    tensor_location location = tensor_location{
        offset: 0,
        byte_size: 0,
        found: false
    }
    int name_pos = find_bytes(model.metadata, "\"" + name + "\"", 0)
    if name_pos < 0 { return location }
    int offsets_pos = find_bytes(model.metadata, "\"data_offsets\"", name_pos)
    if offsets_pos < 0 { return location }
    int first_pos = skip_to_digit(model.metadata, offsets_pos)
    if first_pos < 0 { return location }
    int relative_start = parse_uint(model.metadata, first_pos)
    int comma_pos = find_bytes(model.metadata, ",", first_pos)
    if comma_pos < 0 { return location }
    int second_pos = skip_to_digit(model.metadata, comma_pos + 1)
    if second_pos < 0 { return location }
    int relative_end = parse_uint(model.metadata, second_pos)
    if relative_end <= relative_start { return location }
    location.offset = model.data_offset + relative_start
    location.byte_size = relative_end - relative_start
    location.found = true
    location
}


func read_tensor(safetensors_model model, string name) []int {
    tensor_location location = find_tensor(model, name)
    if !location.found { return []int{} }
    __host_read_binary_file_range(model.path, location.offset, location.byte_size)
}


func read_tensor_elements(safetensors_model model, string name, int start, int count) []int {
    tensor_location location = find_tensor(model, name)
    if !location.found || start < 0 || count < 0 || (start + count) * 2 > location.byte_size {
        return []int{}
    }
    __host_read_binary_file_range(model.path, location.offset + start * 2, count * 2)
}


func pow2(int exponent) float {
    float value = 1.0
    int i = 0
    if exponent >= 0 {
        while i < exponent {
            value = value * 2.0
            i = i + 1
        }
    } else {
        int count = 0 - exponent
        while i < count {
            value = value * 0.5
            i = i + 1
        }
    }
    value
}


func bf16_at([]int bytes, int element) float {
    int offset = element * 2
    if offset < 0 || offset + 1 >= len(bytes) { return 0.0 }
    int low = bytes[offset]
    int high = bytes[offset + 1]
    if low < 0 { low = low + 256 }
    if high < 0 { high = high + 256 }
    int bits = low + high * 256
    int sign = bits / 32768
    int exponent = (bits / 128) - (bits / 32768) * 256
    int fraction = bits - (bits / 128) * 128
    if exponent == 0 { return 0.0 }
    if exponent == 255 { return 0.0 }
    float value = (1.0 + float(fraction) / 128.0) * pow2(exponent - 127)
    if sign == 1 { value = 0.0 - value }
    value
}


func load_vector(safetensors_model model, string name, int size) []float {
    []int raw = read_tensor(model, name)
    []float out = []float{cap: size}
    int i = 0
    while i < size {
        out[i] = bf16_at(raw, i)
        i = i + 1
    }
    out
}


func matvec_bf16([]int matrix, int rows, int columns, []float input) []float {
    []float output = []float{cap: rows}
    int row = 0
    while row < rows {
        float sum = 0.0
        int column = 0
        int base = row * columns
        while column < columns {
            sum = sum + bf16_at(matrix, base + column) * input[column]
            column = column + 1
        }
        output[row] = sum
        row = row + 1
    }
    output
}


func add_in_place([]float output, []float bias) {
    int i = 0
    while i < len(output) && i < len(bias) {
        output[i] = output[i] + bias[i]
        i = i + 1
    }
}


func matvec_named(safetensors_model model, string name, int rows, int columns, []float input) []float {
    []int matrix = read_tensor(model, name)
    if len(matrix) != rows * columns * 2 {
        print("error: tensor has wrong byte size: " + name + "\n")
        return []float{}
    }
    matvec_bf16(matrix, rows, columns, input)
}


func sqrt_newton(float value) float {
    if value <= 0.0 { return 0.0 }
    float estimate = value
    if estimate < 1.0 { estimate = 1.0 }
    int i = 0
    while i < 12 {
        estimate = 0.5 * (estimate + value / estimate)
        i = i + 1
    }
    estimate
}


func rms_norm([]float input, []float weight) []float {
    int size = len(input)
    []float output = []float{cap: size}
    float sum = 0.0
    int i = 0
    while i < size {
        sum = sum + input[i] * input[i]
        i = i + 1
    }
    float scale = 1.0 / sqrt_newton(sum / float(size) + 0.000001)
    i = 0
    while i < size {
        output[i] = input[i] * scale * weight[i]
        i = i + 1
    }
    output
}


func layer_name(int layer, string suffix) string {
    "model.layers." + int_to_string(layer) + "." + suffix
}


func validate_model(safetensors_model model) bool {
    []string required = []string{
        "model.embed_tokens.weight",
        "model.layers.0.self_attn.q_proj.weight",
        "model.layers.23.mlp.down_proj.weight",
        "model.norm.weight"
    }
    int i = 0
    while i < 4 {
        tensor_location location = find_tensor(model, required[i])
        if !location.found {
            print("error: required tensor missing: " + required[i] + "\n")
            return false
        }
        i = i + 1
    }
    true
}


func run_probe(safetensors_model model) int {
    tensor_location embedding = find_tensor(model, "model.embed_tokens.weight")
    tensor_location q_proj = find_tensor(model, "model.layers.0.self_attn.q_proj.weight")
    print("[Model S] safetensors header bytes=" + int_to_string(model.data_offset - 8) + "\n")
    print("[Model S] embedding absolute offset=" + int_to_string(embedding.offset) + " bytes=" + int_to_string(embedding.byte_size) + "\n")
    print("[Model S] layer0 q_proj absolute offset=" + int_to_string(q_proj.offset) + " bytes=" + int_to_string(q_proj.byte_size) + "\n")
    []int first_embedding = __host_read_binary_file_range(model.path, embedding.offset, 16)
    if len(first_embedding) != 16 {
        print("error: failed to read embedding bytes\n")
        return 1
    }
    float first_value = bf16_at(first_embedding, 0)
    if first_value < -100.0 || first_value > 100.0 {
        print("error: invalid BF16 embedding value\n")
        return 1
    }
    print("[Model S] embedding[0] BF16 bytes=" + int_to_string(first_embedding[0]) + "," + int_to_string(first_embedding[1]) + "\n")
    print("[Model S] real BF16 weight probe passed\n")
    0
}


func run_projection_probe(safetensors_model model) int {
    int hidden = 896
    []int embedding_raw = read_tensor_elements(model, "model.embed_tokens.weight", 151644 * hidden, hidden)
    if len(embedding_raw) != hidden * 2 {
        print("error: failed to read embedding row\n")
        return 1
    }
    []float hidden_state = []float{cap: hidden}
    int i = 0
    while i < hidden {
        hidden_state[i] = bf16_at(embedding_raw, i)
        i = i + 1
    }
    []float norm_weight = load_vector(model, "model.layers.0.input_layernorm.weight", hidden)
    []float normalized = rms_norm(hidden_state, norm_weight)
    []float q = matvec_named(model, "model.layers.0.self_attn.q_proj.weight", hidden, hidden, normalized)
    []float bias = load_vector(model, "model.layers.0.self_attn.q_proj.bias", hidden)
    add_in_place(q, bias)
    bool nonzero = false
    i = 0
    while i < len(q) {
        if q[i] > 0.0000001 || q[i] < -0.0000001 { nonzero = true }
        i = i + 1
    }
    if !nonzero {
        print("error: real q_proj produced an all-zero vector\n")
        return 1
    }
    print("[Model S] real embedding + RMSNorm + q_proj passed\n")
    0
}


func main() {
    string model_dir = runtime_env_get("NEURX_CHAT_MODEL_PATH", "/app/shuwen/posttrain")
    string model_path = model_dir + "/model.safetensors"
    if !runtime_file_exists(model_path) {
        print("error: model not found: " + model_path + "\n")
        return 1
    }
    safetensors_model model = open_model(model_path)
    if len(model.metadata) == 0 || !validate_model(model) {
        print("error: invalid model safetensors format\n")
        return 1
    }
    string mode = runtime_env_get("NEURX_MODEL_MODE", "probe")
    if mode == "probe" { return run_probe(model) }
    if mode == "projection-probe" { return run_projection_probe(model) }
    print("error: generation path is not enabled until tokenizer and Transformer validation pass\n")
    1
}

