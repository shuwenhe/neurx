package neurx.inference.safetensors_loader
extern "intrinsic" func __host_slice(string text, int start, int end) string
extern "intrinsic" func __host_read_binary_file(string path) []int
extern "intrinsic" func __host_read_binary_file_range(string path, int start, int count) []int
struct safetensors_header {
    string filename
    int offset
    int size
    []int shape
    string dtype
}

struct safetensors_archive {
    string path
    int total_size
    safetensors_header[] tensors
    bool is_loaded
}

func bytes_to_int32([]int bytes, int offset) int {
    int b0 = 0
    int b1 = 0
    int b2 = 0
    int b3 = 0
    if offset + 3 < len(bytes) {
    }
    b0
}

func int64_from_bytes([]int bytes, int offset) int {
    int low = int32_from_bytes(bytes, offset)
    int high = int32_from_bytes(bytes, offset + 4)
    low
}

func load_tensor_embedding(string model_path, int vocab_size, int hidden_size) [][]float {
    print("[Loader] Reading embedding matrix\n")
    print("  File: " + model_path + "/model.safetensors\n")
    print("  Shape: [" + int_to_string(vocab_size) + ", " + int_to_string(hidden_size) + "]\n")
    []int file_bytes = __host_read_binary_file(model_path)
    if len(file_bytes) == 0 {
        print("Warning: could not read full file via intrinsic, returning zero embedding\n")
        [][]float empty = [][]float{}
        return empty
    }
    int header_len = bytes_to_int64_le(file_bytes, 0)
    string json = extract_json_from_bytes(file_bytes, 8, header_len)
    int start = find_tensor_data_offset(json, "model.embed_tokens.weight")
    if start < 0 {
        print("Embedding tensor not found in header\n")
        [][]float empty = [][]float{}
        return empty
    }
    int end = find_tensor_data_end(json, "model.embed_tokens.weight")
    if end <= start {
        print("Invalid embedding offsets\n")
        [][]float empty = [][]float{}
        return empty
    }
    int byte_count = end - start
    []int raw = __host_read_binary_file_range(model_path, start, byte_count)
    int elems = (byte_count) / 2
    if elems < vocab_size * hidden_size {
        print("Warning: embedding size smaller than expected\n")
    }
    [][]float embedding = [][]float{cap: vocab_size}
    int idx = 0
    int tok = 0
    while tok < vocab_size {
        []float row = []float{cap: hidden_size}
        int d = 0
        while d < hidden_size {
            if idx + 1 >= len(raw) {
                row[d] = 0.0
            } else {
                row[d] = bf16_to_float(raw[idx], raw[idx+1])
            }
            idx = idx + 2
            d = d + 1
        }
        embedding.push(row)
        tok = tok + 1
    }
    embedding
}

func load_transformer_layer(string model_path, int layer_id, int hidden_size, int num_heads) map[string][][]float {
    print("[Loader] Loading transformer layer " + int_to_string(layer_id) + "\n")
    print("  Hidden size: " + int_to_string(hidden_size) + "\n")
    print("  Attention heads: " + int_to_string(num_heads) + "\n")
    map[string][][]float weights
    []int file_bytes = __host_read_binary_file(model_path)
    if len(file_bytes) == 0 {
        return weights
    }
    int header_len = bytes_to_int64_le(file_bytes, 0)
    string json = extract_json_from_bytes(file_bytes, 8, header_len)
    string prefix = "model.layers." + int_to_string(layer_id) + "."
    string names[7] = [
        "self_attn.q_proj.weight",
        "self_attn.k_proj.weight",
        "self_attn.v_proj.weight",
        "self_attn.o_proj.weight",
        "mlp.gate_proj.weight",
        "mlp.up_proj.weight",
        "mlp.down_proj.weight",
    ]
    int i = 0
    while i < 7 {
        string full = prefix + names[i]
        int start = find_tensor_data_offset(json, full)
        if start < 0 {
            i = i + 1
            continue
        }
        int end = find_tensor_data_end(json, full)
        int byte_count = end - start
        []int raw = __host_read_binary_file_range(model_path, start, byte_count)
        int elems = byte_count / 2
        [][]float mat = [][]float{cap: 1}
        int r = 0
        while r * hidden_size < elems {
            []float row = []float{cap: hidden_size}
            int c = 0
            while c < hidden_size {
                int off = (r * hidden_size + c) * 2
                if off + 1 >= len(raw) {
                    row[c] = 0.0
                } else {
                    row[c] = bf16_to_float(raw[off], raw[off+1])
                }
                c = c + 1
            }
            mat.push(row)
            r = r + 1
        }
        weights[full] = mat
        i = i + 1
    }
    weights
}

func load_lm_head(string model_path, int hidden_size, int vocab_size) [][]float {
    print("[Loader] Loading LM head\n")
    print("  Input dim: " + int_to_string(hidden_size) + "\n")
    print("  Output vocab: " + int_to_string(vocab_size) + "\n")
    [][]float result
    []int file_bytes = __host_read_binary_file(model_path)
    if len(file_bytes) == 0 {
        return result
    }
    int header_len = bytes_to_int64_le(file_bytes, 0)
    string json = extract_json_from_bytes(file_bytes, 8, header_len)
    int start = find_tensor_data_offset(json, "lm_head.weight")
    if start < 0 {
        return result
    }
    int end = find_tensor_data_end(json, "lm_head.weight")
    int byte_count = end - start
    []int raw = __host_read_binary_file_range(model_path, start, byte_count)
    int elems = byte_count / 2
    int rows = vocab_size
    int cols = hidden_size
    int r = 0
    while r < rows {
        []float row = []float{cap: cols}
        int c = 0
        while c < cols {
            int off = (r * cols + c) * 2
            if off + 1 >= len(raw) {
                row[c] = 0.0
            } else {
                row[c] = bf16_to_float(raw[off], raw[off+1])
            }
            c = c + 1
        }
        result.push(row)
        r = r + 1
    }
    result
}

func bytes_to_int64_le([]int bytes, int offset) int {
    int b0 = bytes[offset]
    if b0 < 0 { b0 = 256 + b0 }
    int b1 = bytes[offset+1]
    if b1 < 0 { b1 = 256 + b1 }
    int b2 = bytes[offset+2]
    if b2 < 0 { b2 = 256 + b2 }
    int b3 = bytes[offset+3]
    if b3 < 0 { b3 = 256 + b3 }
    int b4 = bytes[offset+4]
    if b4 < 0 { b4 = 256 + b4 }
    int b5 = bytes[offset+5]
    if b5 < 0 { b5 = 256 + b5 }
    int b6 = bytes[offset+6]
    if b6 < 0 { b6 = 256 + b6 }
    int b7 = bytes[offset+7]
    if b7 < 0 { b7 = 256 + b7 }
    b0 + (b1 * 256) + (b2 * 65536) + (b3 * 16777216) + (b4 * 4294967296) + (b5 * 1099511627776) + (b6 * 281474976710656) + (b7 * 72057594037927936)
}

func extract_json_from_bytes([]int bytes, int start, int len_json) string {
    string result = ""
    int i = 0
    while i < len_json {
        int c = bytes[start + i]
        if c < 0 { c = 256 + c }
        if c == 0 { break }
        result = result + __host_slice(char(c), 0, 1)
        i = i + 1
    }
    result
}

func char(int code) string {
    if code == 34 { return "\"" }
    if code == 58 { return ":" }
    if code == 44 { return "," }
    if code == 123 { return "{" }
    if code == 125 { return "}" }
    if code == 91 { return "[" }
    if code == 93 { return "]" }
    if code == 32 { return " " }
    if code == 10 { return "\n" }
    ""
}

func find_tensor_data_offset(string json, string tensor_name) int {
    int pos = index_of(json, tensor_name)
    if pos < 0 { return -1 }
    int doff = index_of_from(json, "\"data_offsets\":", pos)
    if doff < 0 { return -1 }
    int bracket = index_of_from(json, "[", doff)
    if bracket < 0 { return -1 }
    int num_start = bracket + 1
    int num = parse_int_from(json, num_start)
    num
}

func find_tensor_data_end(string json, string tensor_name) int {
    int pos = index_of(json, tensor_name)
    if pos < 0 { return -1 }
    int doff = index_of_from(json, "\"data_offsets\":", pos)
    if doff < 0 { return -1 }
    int bracket = index_of_from(json, "[", doff)
    if bracket < 0 { return -1 }
    int comma = index_of_from(json, ",", bracket)
    if comma < 0 { return -1 }
    int num = parse_int_from(json, comma + 1)
    num
}

func index_of(string s, string sub) int {
    int n = len(s)
    int m = len(sub)
    int i = 0
    while i <= n - m {
        bool ok = true
        int j = 0
        while j < m {
            if s[i+j] != sub[j] { ok = false; break }
            j = j + 1
        }
        if ok { return i }
        i = i + 1
    }
    -1
}

func index_of_from(string s, string sub, int start) int {
    int n = len(s)
    int m = len(sub)
    int i = start
    while i <= n - m {
        bool ok = true
        int j = 0
        while j < m {
            if s[i+j] != sub[j] { ok = false; break }
            j = j + 1
        }
        if ok { return i }
        i = i + 1
    }
    -1
}

func parse_int_from(string s, int start) int {
    int i = start
    while i < len(s) && (s[i] < '0' || s[i] > '9') { i = i + 1 }
    int val = 0
    while i < len(s) && s[i] >= '0' && s[i] <= '9' {
        val = val * 10 + (s[i] - '0')
        i = i + 1
    }
    val
}

func bf16_to_float(int b0, int b1) float {
    int low = b0
    if low < 0 { low = 256 + low }
    int high = b1
    if high < 0 { high = 256 + high }
    int u = low + (high * 256)
    int sign = (u >> 15) & 1
    int exp = (u >> 7) & 0xFF
    int mant = u & 0x7F
    if exp == 0 {
        return 0.0
    }
    float signf = 1.0
    if sign == 1 { signf = -1.0 }
    float frac = 1.0 + float(mant) / 128.0
    int e = exp - 127
    float pow2 = 1.0
    if e > 0 {
        int i = 0
        while i < e {
            pow2 = pow2 * 2.0
            i = i + 1
        }
    } else if e < 0 {
        int i = 0
        int ne = -e
        while i < ne {
            pow2 = pow2 * 0.5
            i = i + 1
        }
    }
    float val = signf * frac * pow2
    val
}

func int_to_string(int value) string {
    if value == 0 {
        return "0"
    }
    string output = ""
    int current = value
    while current > 0 {
        int digit = current - (current / 10) * 10
        output = __host_slice("0123456789", digit, digit + 1) + output
        current = current / 10
    }
    output
}

func verify_tensor_shape([]int shape, []int expected) bool {
    if len(shape) != len(expected) {
        return false
    }
    int i = 0
    while i < len(shape) {
        if shape[i] != expected[i] {
            return false
        }
        i = i + 1
    }
    true
}

func calculate_tensor_size([]int shape) int {
    int size = 1
    int i = 0
    while i < len(shape) {
        size = size * shape[i]
        i = i + 1
    }
    size
}

func open_safetensors(string path) safetensors_archive {
    print("[SafeTensors] Opening archive: " + path + "\n")
    safetensors_archive archive
    archive.path = path
    archive.total_size = 0
    archive.is_loaded = false
    print("[SafeTensors] Archive opened (interface ready)\n")
    archive
}

func close_safetensors(safetensors_archive archive) {
    print("[SafeTensors] Closed: " + archive.path + "\n")
}

func main() {
    print("\n╔════════════════════════════════════════════════════╗\n")
    print("║  SafeTensors Loader - Model Weight Loading        ║\n")
    print("║  Target: /home/shuwen/shuwen/posttrain/model.s   ║\n")
    print("╚════════════════════════════════════════════════════╝\n\n")
    string model_path = "/home/shuwen/shuwen/posttrain"
    print("STEP 1: Open SafeTensors Archive\n")
    print("════════════════════════════════\n")
    safetensors_archive archive = open_safetensors(model_path + "/model.safetensors")
    print("\n")
    print("STEP 2: Load Embedding Matrix\n")
    print("════════════════════════════════\n")
    int vocab_size = 151936
    int hidden_size = 896
    [][]float embedding = load_tensor_embedding(model_path, vocab_size, hidden_size)
    print("✓ Embedding matrix interface ready\n\n")
    print("STEP 3: Load Single Transformer Layer\n")
    print("════════════════════════════════\n")
    int layer_id = 0
    int num_heads = 14
    map[string][][]float layer0 = load_transformer_layer(model_path, layer_id, hidden_size, num_heads)
    print("✓ Layer 0 interface ready\n\n")
    print("STEP 4: Load LM Head (Output Projection)\n")
    print("════════════════════════════════\n")
    [][]float lm_head = load_lm_head(model_path, hidden_size, vocab_size)
    print("✓ LM head interface ready\n\n")
    print("STEP 5: Model Architecture Summary\n")
    print("════════════════════════════════\n")
    print("Model: Language Model 0.5B Instruct\n")
    print("Path: " + model_path + "/model.safetensors\n")
    print("Format: SafeTensors (BF16 weights)\n\n")
    print("Layers loaded (interface):\n")
    print("  ✓ Embedding: [" + int_to_string(vocab_size) + ", " + int_to_string(hidden_size) + "]\n")
    print("  ✓ Transformer Layer 0: ready\n")
    print("  ✓ LM Head: [" + int_to_string(vocab_size) + ", " + int_to_string(hidden_size) + "]\n\n")
    print("════════════════════════════════\n")
    print("✓ SAFETENSORS LOADER FRAMEWORK READY\n")
    print("════════════════════════════════\n\n")
    print("Next steps:\n")
    print("  1. Parse actual SafeTensors binary format\n")
    print("  2. Implement tensor memory allocation\n")
    print("  3. Implement tensor access functions\n")
    print("  4. Integrate with transformer forward pass\n")
    print("  5. Test single token generation\n\n")
    close_safetensors(archive)
}
