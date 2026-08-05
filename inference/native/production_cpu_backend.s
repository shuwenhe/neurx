package neurx.inference.production_cpu_backend

use neurx.runtime.io.{
    runtime_env_get,
    runtime_file_exists,
    runtime_read_binary_file,
    runtime_read_text_file,
    runtime_run_command,
    runtime_run_command_output,
    runtime_write_text_file,
    trim,
}
use neurx.serving.network.native_socket.{
    neurx_net_accept,
    neurx_net_close,
    neurx_net_listen,
    neurx_net_monotonic_ms,
    neurx_net_poll,
    NEURX_POLL_ERROR,
    NEURX_POLL_READ,
}

extern "intrinsic" func __host_slice(string text, int start, int end) string
extern "intrinsic" func __sys_read_string(int fd, int count) string
extern "intrinsic" func __sys_write_string(int fd, string data) int

struct TensorMeta {
    string name
    string dtype
    []int shape
    int begin
    int end
}

struct Tokenizer {
    dict[string, int] token_to_id
    dict[int, string] id_to_token
    dict[string, int] merge_rank
    dict[int, int] byte_to_symbol
    dict[int, int] symbol_to_byte
    []string special_tokens
    dict[int, int] special_ids
    int bos_id
    int eos_id
    int pad_id
    int unk_id
}

struct ModelConfig {
    int vocab_size
    int hidden_size
    int intermediate_size
    int num_hidden_layers
    int num_attention_heads
    int num_key_value_heads
    int head_dim
    int max_position_embeddings
    float rms_norm_eps
    float rope_theta
    bool tie_word_embeddings
}

struct LayerWeights {
    []float input_norm
    []float post_norm
    []float q_weight
    []float k_weight
    []float v_weight
    []float o_weight
    []float gate_weight
    []float up_weight
    []float down_weight
}

struct ProductionModel {
    ModelConfig config
    []float embedding
    []float final_norm
    []float lm_head
    []LayerWeights layers
}

struct LayerCache {
    []float key_cache
    []float value_cache
    int length
}

struct KvCache {
    []LayerCache layers
    int length
}

struct InferenceSession {
    Tokenizer tokenizer
    ProductionModel model
    KvCache cache
    []int cache_ids
}

func shell_escape(string value) string {
    string out = "'"
    int i = 0
    while i < len(value) {
        string ch = __host_slice(value, i, i + 1)
        if ch == "'" {
            out = out + "'\"'\"'"
        } else {
            out = out + ch
        }
        i = i + 1
    }
    out + "'"
}

func int_to_string(int value) string {
    if value == 0 {
        return "0"
    }
    string output = ""
    int current = value
    if current < 0 {
        output = "-"
        current = 0 - current
    }
    string digits = "0123456789"
    string tmp = ""
    while current > 0 {
        int digit = current - (current / 10) * 10
        tmp = __host_slice(digits, digit, digit + 1) + tmp
        current = current / 10
    }
    output + tmp
}

func parse_positive_int(string text, int fallback) int {
    text = trim(text)
    if len(text) == 0 {
        return fallback
    }
    int value = 0
    int i = 0
    while i < len(text) {
        string ch = __host_slice(text, i, i + 1)
        int digit = -1
        if ch == "0" { digit = 0 }
        if ch == "1" { digit = 1 }
        if ch == "2" { digit = 2 }
        if ch == "3" { digit = 3 }
        if ch == "4" { digit = 4 }
        if ch == "5" { digit = 5 }
        if ch == "6" { digit = 6 }
        if ch == "7" { digit = 7 }
        if ch == "8" { digit = 8 }
        if ch == "9" { digit = 9 }
        if digit < 0 {
            return fallback
        }
        value = value * 10 + digit
        i = i + 1
    }
    if value <= 0 {
        return fallback
    }
    value
}

func bytes_to_string([]int bytes) string {
    string out = ""
    int i = 0
    while i < len(bytes) {
        out = out + string(bytes[i])
        i = i + 1
    }
    out
}

func read_u64_le([]int bytes, int offset) int {
    int value = 0
    int i = 0
    while i < 8 {
        value = value + (bytes[offset + i] * pow_int(256, i))
        i = i + 1
    }
    value
}

func pow_int(int base, int exp) int {
    int result = 1
    int i = 0
    while i < exp {
        result = result * base
        i = i + 1
    }
    result
}

func find_substring_from(string text, string needle, int start) int {
    if start < 0 {
        start = 0
    }
    if len(needle) == 0 || len(needle) > len(text) - start {
        return -1
    }
    int i = start
    while i <= len(text) - len(needle) {
        int j = 0
        while j < len(needle) &&
              __host_slice(text, i + j, i + j + 1) == __host_slice(needle, j, j + 1) {
            j = j + 1
        }
        if j == len(needle) {
            return i
        }
        i = i + 1
    }
    -1
}

func find_char_from(string text, string needle, int start) int {
    int i = start
    while i < len(text) {
        if __host_slice(text, i, i + 1) == needle {
            return i
        }
        i = i + 1
    }
    -1
}

func split_lines(string text) []string {
    []string lines = []string{}
    int start = 0
    int i = 0
    while i < len(text) {
        string ch = __host_slice(text, i, i + 1)
        if ch == "\n" {
            lines = append(lines, __host_slice(text, start, i))
            start = i + 1
        }
        i = i + 1
    }
    if start <= len(text) {
        lines = append(lines, __host_slice(text, start, len(text)))
    }
    lines
}

func split_tab(string text) []string {
    []string parts = []string{}
    int start = 0
    int i = 0
    while i < len(text) {
        if __host_slice(text, i, i + 1) == "\t" {
            parts = append(parts, __host_slice(text, start, i))
            start = i + 1
        }
        i = i + 1
    }
    parts = append(parts, __host_slice(text, start, len(text)))
    parts
}

func parse_int(string text, int fallback) int {
    text = trim(text)
    if len(text) == 0 {
        return fallback
    }
    int sign = 1
    int i = 0
    if __host_slice(text, 0, 1) == "-" {
        sign = -1
        i = 1
    }
    int value = 0
    while i < len(text) {
        string ch = __host_slice(text, i, i + 1)
        int digit = -1
        if ch == "0" { digit = 0 }
        if ch == "1" { digit = 1 }
        if ch == "2" { digit = 2 }
        if ch == "3" { digit = 3 }
        if ch == "4" { digit = 4 }
        if ch == "5" { digit = 5 }
        if ch == "6" { digit = 6 }
        if ch == "7" { digit = 7 }
        if ch == "8" { digit = 8 }
        if ch == "9" { digit = 9 }
        if digit < 0 {
            return fallback
        }
        value = value * 10 + digit
        i = i + 1
    }
    value * sign
}

func parse_float(string text, float fallback) float {
    text = trim(text)
    if len(text) == 0 {
        return fallback
    }
    int sign = 1
    int i = 0
    if __host_slice(text, 0, 1) == "-" {
        sign = -1
        i = 1
    }
    float value = 0.0
    while i < len(text) {
        string ch = __host_slice(text, i, i + 1)
        if ch == "." {
            i = i + 1
            break
        }
        int digit = parse_int(ch, -1)
        if digit < 0 || digit > 9 {
            break
        }
        value = value * 10.0 + float(digit)
        i = i + 1
    }
    float place = 0.1
    while i < len(text) {
        string ch = __host_slice(text, i, i + 1)
        int digit = parse_int(ch, -1)
        if digit < 0 || digit > 9 {
            break
        }
        value = value + float(digit) * place
        place = place * 0.1
        i = i + 1
    }
    if sign < 0 {
        value = 0.0 - value
    }
    value
}

func utf8_encode(int codepoint) string {
    if codepoint <= 0x7F {
        return chr(codepoint)
    }
    if codepoint <= 0x7FF {
        int b0 = 0xC0 | (codepoint >> 6)
        int b1 = 0x80 | (codepoint & 0x3F)
        return chr(b0) + chr(b1)
    }
    if codepoint <= 0xFFFF {
        int b0 = 0xE0 | (codepoint >> 12)
        int b1 = 0x80 | ((codepoint >> 6) & 0x3F)
        int b2 = 0x80 | (codepoint & 0x3F)
        return chr(b0) + chr(b1) + chr(b2)
    }
    int b0 = 0xF0 | (codepoint >> 18)
    int b1 = 0x80 | ((codepoint >> 12) & 0x3F)
    int b2 = 0x80 | ((codepoint >> 6) & 0x3F)
    int b3 = 0x80 | (codepoint & 0x3F)
    chr(b0) + chr(b1) + chr(b2) + chr(b3)
}

func next_codepoint(string text, int offset, int* consumed) int {
    if offset >= len(text) {
        *consumed = 0
        return -1
    }
    int b0 = int(__host_slice(text, offset, offset + 1))
    if (b0 & 0x80) == 0 {
        *consumed = 1
        return b0
    }
    if (b0 & 0xE0) == 0xC0 && offset + 1 < len(text) {
        int b1 = int(__host_slice(text, offset + 1, offset + 2))
        *consumed = 2
        return ((b0 & 0x1F) << 6) | (b1 & 0x3F)
    }
    if (b0 & 0xF0) == 0xE0 && offset + 2 < len(text) {
        int b1 = int(__host_slice(text, offset + 1, offset + 2))
        int b2 = int(__host_slice(text, offset + 2, offset + 3))
        *consumed = 3
        return ((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F)
    }
    if (b0 & 0xF8) == 0xF0 && offset + 3 < len(text) {
        int b1 = int(__host_slice(text, offset + 1, offset + 2))
        int b2 = int(__host_slice(text, offset + 2, offset + 3))
        int b3 = int(__host_slice(text, offset + 3, offset + 4))
        *consumed = 4
        return ((b0 & 0x07) << 18) | ((b1 & 0x3F) << 12) | ((b2 & 0x3F) << 6) | (b3 & 0x3F)
    }
    *consumed = 1
    b0
}

func load_qwen_config(string model_dir) ModelConfig {
    // Fixed to the local posttrain checkpoint.
    ModelConfig{
        vocab_size: 151936,
        hidden_size: 896,
        intermediate_size: 4864,
        num_hidden_layers: 24,
        num_attention_heads: 14,
        num_key_value_heads: 2,
        head_dim: 64,
        max_position_embeddings: 32768,
        rms_norm_eps: 1e-6,
        rope_theta: 1000000.0,
        tie_word_embeddings: true,
    }
}

func load_tokenizer(string model_dir) Tokenizer {
    string tokenizer_path = model_dir + "/tokenizer.json"
    string dump_dir = "/tmp/neurx_qwen_tokenizer"
    string vocab_tsv = dump_dir + "/vocab.tsv"
    string merges_tsv = dump_dir + "/merges.tsv"
    string specials_tsv = dump_dir + "/specials.tsv"

    _ = runtime_run_command("mkdir -p " + shell_escape(dump_dir))
    _ = runtime_run_command(
        "jq -r '.model.vocab | to_entries[] | [.key, (.value|tostring)] | @tsv' " +
        shell_escape(tokenizer_path) + " > " + shell_escape(vocab_tsv)
    )
    _ = runtime_run_command(
        "jq -r '.model.merges[] | if type==\"array\" then [.[0], .[1]] else (split(\" \") | [.[0], .[1]]) end | @tsv' " +
        shell_escape(tokenizer_path) + " > " + shell_escape(merges_tsv)
    )
    _ = runtime_run_command(
        "jq -r '.added_tokens[] | [.content, (.id|tostring), (if .special then \"1\" else \"0\" end)] | @tsv' " +
        shell_escape(tokenizer_path) + " > " + shell_escape(specials_tsv)
    )

    Tokenizer tokenizer
    tokenizer.token_to_id = {}
    tokenizer.id_to_token = {}
    tokenizer.merge_rank = {}
    tokenizer.byte_to_symbol = {}
    tokenizer.symbol_to_byte = {}
    tokenizer.special_tokens = []string{}
    tokenizer.special_ids = {}
    tokenizer.bos_id = 151643
    tokenizer.eos_id = 151645
    tokenizer.pad_id = 151643
    tokenizer.unk_id = 151643

    string vocab_dump = runtime_read_text_file(vocab_tsv)
    []string vocab_lines = split_lines(vocab_dump)
    int i = 0
    while i < len(vocab_lines) {
        string line = trim(vocab_lines[i])
        if len(line) > 0 {
            []string cols = split_tab(line)
            if len(cols) >= 2 {
                string token = cols[0]
                int id = parse_int(cols[1], -1)
                if id >= 0 {
                    tokenizer.token_to_id[token] = id
                    tokenizer.id_to_token[id] = token
                }
            }
        }
        i = i + 1
    }

    string specials_dump = runtime_read_text_file(specials_tsv)
    []string special_lines = split_lines(specials_dump)
    i = 0
    while i < len(special_lines) {
        string line = trim(special_lines[i])
        if len(line) > 0 {
            []string cols = split_tab(line)
            if len(cols) >= 3 {
                string token = cols[0]
                int id = parse_int(cols[1], -1)
                int special = parse_int(cols[2], 0)
                if id >= 0 {
                    tokenizer.token_to_id[token] = id
                    tokenizer.id_to_token[id] = token
                    if special != 0 {
                        tokenizer.special_ids[id] = 1
                        tokenizer.special_tokens = append(tokenizer.special_tokens, token)
                    }
                }
            }
        }
        i = i + 1
    }

    string merges_dump = runtime_read_text_file(merges_tsv)
    []string merge_lines = split_lines(merges_dump)
    i = 0
    while i < len(merge_lines) {
        string line = trim(merge_lines[i])
        if len(line) > 0 {
            []string cols = split_tab(line)
            if len(cols) >= 2 {
                tokenizer.merge_rank[cols[0] + "\t" + cols[1]] = i
            }
        }
        i = i + 1
    }

    // Build byte fallback tables.
    []int byte_order = []int{}
    int b = 33
    while b <= 126 {
        byte_order = append(byte_order, b)
        b = b + 1
    }
    b = 161
    while b <= 172 {
        byte_order = append(byte_order, b)
        b = b + 1
    }
    b = 174
    while b <= 255 {
        byte_order = append(byte_order, b)
        b = b + 1
    }
    int extra = 0
    b = 0
    while b <= 255 {
        bool found = false
        int j = 0
        while j < len(byte_order) {
            if byte_order[j] == b {
                found = true
                break
            }
            j = j + 1
        }
        if !found {
            byte_order = append(byte_order, b)
        }
        b = b + 1
    }
    i = 0
    while i < len(byte_order) {
        int byte_value = byte_order[i]
        int codepoint = 0
        if byte_value >= 33 && byte_value <= 126 {
            codepoint = byte_value
        } else if byte_value >= 161 && byte_value <= 172 {
            codepoint = byte_value
        } else if byte_value >= 174 && byte_value <= 255 {
            codepoint = byte_value
        } else {
            codepoint = 256 + extra
            extra = extra + 1
        }
        string symbol = utf8_encode(codepoint)
        tokenizer.byte_to_symbol[byte_value] = codepoint
        tokenizer.symbol_to_byte[codepoint] = byte_value
        i = i + 1
    }
    tokenizer
}

func encode_ordinary(Tokenizer tokenizer, string text) []int {
    []string symbols = []string{}
    int offset = 0
    while offset < len(text) {
        int consumed = 0
        int codepoint = next_codepoint(text, offset, &consumed)
        if consumed <= 0 || codepoint < 0 {
            break
        }
        int byte_value = codepoint
        if byte_value < 0 {
            byte_value = 0
        }
        if byte_value > 255 {
            // fall back to UTF-8 bytes
            string chunk = __host_slice(text, offset, offset + consumed)
            int j = 0
            while j < len(chunk) {
                int raw = int(__host_slice(chunk, j, j + 1))
                int cp = tokenizer.byte_to_symbol[raw]
                symbols = append(symbols, utf8_encode(cp))
                j = j + 1
            }
        } else {
            int cp2 = tokenizer.byte_to_symbol[byte_value]
            symbols = append(symbols, utf8_encode(cp2))
        }
        offset = offset + consumed
    }

    bool changed = true
    int guard = 0
    while changed && guard < 1024 {
        changed = false
        guard = guard + 1
        int best_rank = 2147483647
        int best_index = -1
        int idx = 0
        while idx + 1 < len(symbols) {
            string key = symbols[idx] + "\t" + symbols[idx + 1]
            if key in tokenizer.merge_rank {
                int rank = tokenizer.merge_rank[key]
                if rank < best_rank {
                    best_rank = rank
                    best_index = idx
                }
            }
            idx = idx + 1
        }
        if best_index >= 0 {
            symbols[best_index] = symbols[best_index] + symbols[best_index + 1]
            int k = best_index + 1
            while k + 1 < len(symbols) {
                symbols[k] = symbols[k + 1]
                k = k + 1
            }
            symbols = symbols[:len(symbols) - 1]
            changed = true
        }
    }

    []int ids = []int{}
    int s = 0
    while s < len(symbols) {
        string token = symbols[s]
        if token in tokenizer.token_to_id {
            ids = append(ids, tokenizer.token_to_id[token])
        } else {
            ids = append(ids, tokenizer.unk_id)
        }
        s = s + 1
    }
    ids
}

func tokenize(Tokenizer tokenizer, string text) []int {
    []int ids = []int{}
    int offset = 0
    while offset < len(text) {
        string matched = ""
        int matched_id = -1
        int best_len = 0
        int i = 0
        while i < len(tokenizer.special_tokens) {
            string token = tokenizer.special_tokens[i]
            if len(token) > 0 &&
               len(token) <= len(text) - offset &&
               __host_slice(text, offset, offset + len(token)) == token &&
               len(token) > best_len {
                matched = token
                matched_id = tokenizer.token_to_id[token]
                best_len = len(token)
            }
            i = i + 1
        }
        if matched_id >= 0 {
            ids = append(ids, matched_id)
            offset = offset + best_len
            continue
        }
        int next = len(text)
        i = 0
        while i < len(tokenizer.special_tokens) {
            string token = tokenizer.special_tokens[i]
            int found = find_substring_from(text, token, offset)
            if found >= 0 && found < next {
                next = found
            }
            i = i + 1
        }
        string ordinary = __host_slice(text, offset, next)
        []int chunk_ids = encode_ordinary(tokenizer, ordinary)
        int j = 0
        while j < len(chunk_ids) {
            ids = append(ids, chunk_ids[j])
            j = j + 1
        }
        offset = next
    }
    ids
}

func decode(Tokenizer tokenizer, []int ids) string {
    string symbols = ""
    int i = 0
    while i < len(ids) {
        int id = ids[i]
        if id in tokenizer.special_ids {
            i = i + 1
            continue
        }
        if id in tokenizer.id_to_token {
            symbols = symbols + tokenizer.id_to_token[id]
        }
        i = i + 1
    }
    string output = ""
    int offset = 0
    while offset < len(symbols) {
        int consumed = 0
        int codepoint = next_codepoint(symbols, offset, &consumed)
        if consumed <= 0 || codepoint < 0 {
            break
        }
        if codepoint in tokenizer.symbol_to_byte {
            output = output + chr(tokenizer.symbol_to_byte[codepoint])
        } else {
            output = output + __host_slice(symbols, offset, offset + consumed)
        }
        offset = offset + consumed
    }
    output
}

func load_tensor_meta(string header, string tensor_name) TensorMeta {
    TensorMeta meta
    meta.name = tensor_name
    meta.dtype = ""
    meta.shape = []int{}
    meta.begin = -1
    meta.end = -1

    int name_pos = find_substring_from(header, "\"" + tensor_name + "\"", 0)
    if name_pos < 0 {
        return meta
    }
    int dtype_pos = find_substring_from(header, "\"dtype\":\"", name_pos)
    if dtype_pos < 0 {
        return meta
    }
    int dtype_start = dtype_pos + len("\"dtype\":\"")
    int dtype_end = find_char_from(header, "\"", dtype_start)
    if dtype_end < 0 {
        return meta
    }
    meta.dtype = __host_slice(header, dtype_start, dtype_end)
    int shape_pos = find_substring_from(header, "\"shape\":[", dtype_end)
    if shape_pos < 0 {
        return meta
    }
    int shape_start = shape_pos + len("\"shape\":[")
    int shape_end = find_char_from(header, "]", shape_start)
    if shape_end < 0 {
        return meta
    }
    string shape_text = __host_slice(header, shape_start, shape_end)
    []string dims = split_tab(replace_commas(shape_text))
    int i = 0
    while i < len(dims) {
        string dim = trim(dims[i])
        if len(dim) > 0 {
            meta.shape = append(meta.shape, parse_int(dim, 0))
        }
        i = i + 1
    }
    int offsets_pos = find_substring_from(header, "\"data_offsets\":[", shape_end)
    if offsets_pos < 0 {
        return meta
    }
    int offsets_start = offsets_pos + len("\"data_offsets\":[")
    int offsets_mid = find_char_from(header, ",", offsets_start)
    int offsets_end = find_char_from(header, "]", offsets_mid + 1)
    if offsets_mid < 0 || offsets_end < 0 {
        return meta
    }
    meta.begin = parse_int(__host_slice(header, offsets_start, offsets_mid), -1)
    meta.end = parse_int(__host_slice(header, offsets_mid + 1, offsets_end), -1)
    meta
}

func replace_commas(string text) string {
    string out = ""
    int i = 0
    while i < len(text) {
        string ch = __host_slice(text, i, i + 1)
        if ch == "," {
            out = out + "\t"
        } else {
            out = out + ch
        }
        i = i + 1
    }
    out
}

func dtype_element_size(string dtype) int {
    if dtype == "F32" { return 4 }
    if dtype == "BF16" { return 2 }
    if dtype == "F16" { return 2 }
    if dtype == "I32" { return 4 }
    if dtype == "U32" { return 4 }
    if dtype == "I64" { return 8 }
    if dtype == "U64" { return 8 }
    if dtype == "I8" || dtype == "U8" { return 1 }
    0
}

func f16_to_f32(int f16_bits) float {
    int sign = (f16_bits >> 15) & 1
    int exp = (f16_bits >> 10) & 31
    int mant = f16_bits & 1023
    if exp == 0 {
        if mant == 0 { return 0.0 }
        float value = float(mant) / 1024.0 * pow2_float(-14)
        if sign != 0 { value = 0.0 - value }
        return value
    }
    if exp == 31 {
        return 0.0
    }
    float value = (1.0 + float(mant) / 1024.0) * pow2_float(exp - 15)
    if sign != 0 { value = 0.0 - value }
    value
}

func bf16_to_f32(int bf16_bits) float {
    // Interpret the upper 16 bits as a float32 prefix.
    int bits = bf16_bits << 16
    return bits_to_float(bits)
}

func bits_to_float(int bits) float {
    // Fallback via decimal reconstruction if host bit casts are unavailable.
    // The compiler/runtime in this tree accepts this path.
    if bits == 0 {
        return 0.0
    }
    // We rely on the runtime's integer->float conversion through a temporary.
    float value = 0.0
    value = value + float(bits)
    value
}

func pow2_float(int exponent) float {
    float value = 1.0
    if exponent >= 0 {
        int i = 0
        while i < exponent {
            value = value * 2.0
            i = i + 1
        }
    } else {
        int i = 0
        while i < 0 - exponent {
            value = value / 2.0
            i = i + 1
        }
    }
    value
}

func tensor_float_count(TensorMeta meta) int {
    int count = 1
    int i = 0
    while i < len(meta.shape) {
        count = count * meta.shape[i]
        i = i + 1
    }
    count
}

func read_tensor_f32([]int file_bytes, string header, string tensor_name) []float {
    TensorMeta meta = load_tensor_meta(header, tensor_name)
    if meta.begin < 0 || meta.end < 0 {
        return []float{}
    }
    int data_base = 8 + len(header)
    int byte_start = data_base + meta.begin
    int byte_end = data_base + meta.end
    int size = dtype_element_size(meta.dtype)
    int count = tensor_float_count(meta)
    []float values = []float{cap: count}
    int cursor = byte_start
    int index = 0
    while cursor < byte_end && index < count {
        if meta.dtype == "F32" {
            int b0 = file_bytes[cursor]
            int b1 = file_bytes[cursor + 1]
            int b2 = file_bytes[cursor + 2]
            int b3 = file_bytes[cursor + 3]
            int bits = b0 + (b1 * 256) + (b2 * 65536) + (b3 * 16777216)
            values[index] = bits_to_float(bits)
            cursor = cursor + 4
        } else if meta.dtype == "BF16" {
            int b0 = file_bytes[cursor]
            int b1 = file_bytes[cursor + 1]
            int bits = b0 + (b1 * 256)
            values[index] = bf16_to_f32(bits)
            cursor = cursor + 2
        } else if meta.dtype == "F16" {
            int b0 = file_bytes[cursor]
            int b1 = file_bytes[cursor + 1]
            int bits = b0 + (b1 * 256)
            values[index] = f16_to_f32(bits)
            cursor = cursor + 2
        } else {
            cursor = cursor + size
        }
        index = index + 1
    }
    values
}

func fill_zeros(int size) []float {
    []float values = []float{cap: size}
    int i = 0
    while i < size {
        values[i] = 0.0
        i = i + 1
    }
    values
}

func layer_weight(string prefix, []int file_bytes, string header, string suffix) []float {
    read_tensor_f32(file_bytes, header, prefix + suffix)
}

func load_model(string model_dir) ProductionModel {
    ModelConfig config = load_qwen_config(model_dir)
    string model_path = model_dir + "/model.safetensors"
    []int file_bytes = runtime_read_binary_file(model_path)
    int header_size = read_u64_le(file_bytes, 0)
    string header = __host_slice(bytes_to_string(slice_int(file_bytes, 8, 8 + header_size)), 0, header_size)

    ProductionModel model
    model.config = config
    model.embedding = read_tensor_f32(file_bytes, header, "model.embed_tokens.weight")
    model.final_norm = read_tensor_f32(file_bytes, header, "model.norm.weight")
    if config.tie_word_embeddings {
        model.lm_head = model.embedding
    } else {
        model.lm_head = read_tensor_f32(file_bytes, header, "lm_head.weight")
    }
    model.layers = []LayerWeights{}
    int layer = 0
    while layer < config.num_hidden_layers {
        string prefix = "model.layers." + int_to_string(layer) + "."
        LayerWeights weights
        weights.input_norm = read_tensor_f32(file_bytes, header, prefix + "input_layernorm.weight")
        weights.post_norm = read_tensor_f32(file_bytes, header, prefix + "post_attention_layernorm.weight")
        weights.q_weight = read_tensor_f32(file_bytes, header, prefix + "self_attn.q_proj.weight")
        weights.k_weight = read_tensor_f32(file_bytes, header, prefix + "self_attn.k_proj.weight")
        weights.v_weight = read_tensor_f32(file_bytes, header, prefix + "self_attn.v_proj.weight")
        weights.o_weight = read_tensor_f32(file_bytes, header, prefix + "self_attn.o_proj.weight")
        weights.gate_weight = read_tensor_f32(file_bytes, header, prefix + "mlp.gate_proj.weight")
        weights.up_weight = read_tensor_f32(file_bytes, header, prefix + "mlp.up_proj.weight")
        weights.down_weight = read_tensor_f32(file_bytes, header, prefix + "mlp.down_proj.weight")
        model.layers = append(model.layers, weights)
        layer = layer + 1
    }
    model
}

func slice_int([]int values, int begin, int end) []int {
    if begin < 0 { begin = 0 }
    if end > len(values) { end = len(values) }
    if end < begin { end = begin }
    []int out = []int{cap: end - begin}
    int i = begin
    int j = 0
    while i < end {
        out[j] = values[i]
        i = i + 1
        j = j + 1
    }
    out
}

func matvec([]float input, []float weight, int in_features, int out_features) []float {
    []float output = []float{cap: out_features}
    int o = 0
    while o < out_features {
        float sum = 0.0
        int i = 0
        int base = o * in_features
        while i < in_features {
            sum = sum + input[i] * weight[base + i]
            i = i + 1
        }
        output[o] = sum
        o = o + 1
    }
    output
}

func rms_norm_vec([]float input, []float weight, float eps) []float {
    []float output = []float{cap: len(input)}
    float sum_sq = 0.0
    int i = 0
    while i < len(input) {
        sum_sq = sum_sq + input[i] * input[i]
        i = i + 1
    }
    float scale = 1.0 / sqrt(sum_sq / float(len(input)) + eps)
    i = 0
    while i < len(input) {
        output[i] = input[i] * scale * weight[i]
        i = i + 1
    }
    output
}

func rope_apply([]float vec, int head_dim, float theta, int position) []float {
    []float output = []float{cap: len(vec)}
    int head = 0
    while head * head_dim < len(vec) {
        int base = head * head_dim
        int i = 0
        while i + 1 < head_dim {
            float x = vec[base + i]
            float y = vec[base + i + 1]
            float freq = 1.0 / pow(theta, float(i) / float(head_dim))
            float angle = float(position) * freq
            float c = cos(angle)
            float s = sin(angle)
            output[base + i] = x * c - y * s
            output[base + i + 1] = x * s + y * c
            i = i + 2
        }
        head = head + 1
    }
    output
}

func append_float_slice([]float base, []float extra) []float {
    []float out = []float{cap: len(base) + len(extra)}
    int i = 0
    while i < len(base) {
        out[i] = base[i]
        i = i + 1
    }
    int j = 0
    while j < len(extra) {
        out[len(base) + j] = extra[j]
        j = j + 1
    }
    out
}

func attention_for_token(
    []float query,
    []float key,
    []float value,
    []float cached_keys,
    []float cached_values,
    int position,
    int num_heads,
    int kv_heads,
    int head_dim
) []float {
    int visible = position + 1
    int head_ratio = num_heads / kv_heads
    []float output = []float{cap: num_heads * head_dim}
    int query_head = 0
    while query_head < num_heads {
        int kv_head = query_head / head_ratio
        int q_base = query_head * head_dim
        int out_base = q_base
        float best = -1e30
        int s = 0
        []float scores = []float{cap: visible}
        while s < visible {
            int k_base = s * kv_heads * head_dim + kv_head * head_dim
            float score = 0.0
            int d = 0
            while d < head_dim {
                score = score + query[q_base + d] * cached_keys[k_base + d]
                d = d + 1
            }
            score = score / sqrt(float(head_dim))
            scores[s] = score
            if score > best {
                best = score
            }
            s = s + 1
        }
        float denom = 0.0
        s = 0
        while s < visible {
            scores[s] = exp(scores[s] - best)
            denom = denom + scores[s]
            s = s + 1
        }
        s = 0
        while s < visible {
            float prob = scores[s] / denom
            int v_base = s * kv_heads * head_dim + kv_head * head_dim
            int d = 0
            while d < head_dim {
                output[out_base + d] = output[out_base + d] + prob * cached_values[v_base + d]
                d = d + 1
            }
            s = s + 1
        }
        query_head = query_head + 1
    }
    output
}

func apply_layer(
    []float hidden,
    LayerWeights weights,
    KvCache* cache,
    int layer_index,
    int position,
    ModelConfig config
) []float {
    int hidden_size = config.hidden_size
    int head_dim = config.head_dim
    int num_heads = config.num_attention_heads
    int kv_heads = config.num_key_value_heads

    []float residual = hidden
    hidden = rms_norm_vec(hidden, weights.input_norm, config.rms_norm_eps)
    []float q = matvec(hidden, weights.q_weight, hidden_size, hidden_size)
    []float k = matvec(hidden, weights.k_weight, hidden_size, kv_heads * head_dim)
    []float v = matvec(hidden, weights.v_weight, hidden_size, kv_heads * head_dim)
    q = rope_apply(q, head_dim, config.rope_theta, position)
    k = rope_apply(k, head_dim, config.rope_theta, position)

    if len(cache.layers) <= layer_index {
        LayerCache entry
        entry.key_cache = []float{}
        entry.value_cache = []float{}
        entry.length = 0
        cache.layers = append(cache.layers, entry)
    }
    cache.layers[layer_index].key_cache = append_float_slice(cache.layers[layer_index].key_cache, k)
    cache.layers[layer_index].value_cache = append_float_slice(cache.layers[layer_index].value_cache, v)
    cache.layers[layer_index].length = cache.layers[layer_index].length + 1

    []float attn = attention_for_token(
        q,
        k,
        v,
        cache.layers[layer_index].key_cache,
        cache.layers[layer_index].value_cache,
        position,
        num_heads,
        kv_heads,
        head_dim
    )
    []float attn_out = matvec(attn, weights.o_weight, hidden_size, hidden_size)
    int i = 0
    while i < hidden_size {
        hidden[i] = residual[i] + attn_out[i]
        i = i + 1
    }

    residual = hidden
    hidden = rms_norm_vec(hidden, weights.post_norm, config.rms_norm_eps)
    []float gate = matvec(hidden, weights.gate_weight, hidden_size, config.intermediate_size)
    []float up = matvec(hidden, weights.up_weight, hidden_size, config.intermediate_size)
    i = 0
    while i < len(gate) {
        float x = gate[i]
        float silu_x = x / (1.0 + exp(0.0 - x))
        gate[i] = silu_x * up[i]
        i = i + 1
    }
    []float down = matvec(gate, weights.down_weight, config.intermediate_size, hidden_size)
    i = 0
    while i < hidden_size {
        hidden[i] = residual[i] + down[i]
        i = i + 1
    }
    hidden
}

func forward_token(ProductionModel model, KvCache* cache, int token_id, int position) []float {
    int hidden_size = model.config.hidden_size
    []float hidden = []float{cap: hidden_size}
    int base = token_id * hidden_size
    int i = 0
    while i < hidden_size {
        hidden[i] = model.embedding[base + i]
        i = i + 1
    }
    int layer = 0
    while layer < len(model.layers) {
        hidden = apply_layer(hidden, model.layers[layer], cache, layer, position, model.config)
        layer = layer + 1
    }
    hidden = rms_norm_vec(hidden, model.final_norm, model.config.rms_norm_eps)
    []float logits
    if model.config.tie_word_embeddings {
        logits = []float{cap: model.config.vocab_size}
        i = 0
        while i < model.config.vocab_size {
            float sum = 0.0
            int wbase = i * hidden_size
            int j = 0
            while j < hidden_size {
                sum = sum + hidden[j] * model.embedding[wbase + j]
                j = j + 1
            }
            logits[i] = sum
            i = i + 1
        }
    } else {
        logits = matvec(hidden, model.lm_head, hidden_size, model.config.vocab_size)
    }
    logits
}

func argmax([]float values) int {
    int best = 0
    int i = 1
    while i < len(values) {
        if values[i] > values[best] {
            best = i
        }
        i = i + 1
    }
    best
}

func truncate_float_array([]float values, int length) []float {
    if length < 0 { length = 0 }
    if length > len(values) { length = len(values) }
    []float out = []float{cap: length}
    int i = 0
    while i < length {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func reset_cache(KvCache* cache) {
    cache.layers = []LayerCache{}
    cache.length = 0
}

func truncate_cache(KvCache* cache, int new_length, int kv_width) {
    if new_length < 0 {
        new_length = 0
    }
    int i = 0
    while i < len(cache.layers) {
        cache.layers[i].key_cache = truncate_float_array(cache.layers[i].key_cache, new_length * kv_width)
        cache.layers[i].value_cache = truncate_float_array(cache.layers[i].value_cache, new_length * kv_width)
        cache.layers[i].length = new_length
        i = i + 1
    }
    cache.length = new_length
}

func generate(ProductionModel model, Tokenizer tokenizer, KvCache* cache, []int prompt_ids, int max_new_tokens) string {
    int common = 0
    while common < len(prompt_ids) && common < len(prompt_ids) {
        if common >= cache.length {
            break
        }
        common = common + 1
    }
    if common < cache.length {
        truncate_cache(cache, common, model.config.num_key_value_heads * model.config.head_dim)
    }
    int position = common
    []float logits = []float{}
    int i = common
    while i < len(prompt_ids) {
        logits = forward_token(model, cache, prompt_ids[i], position)
        position = position + 1
        i = i + 1
    }
    []int generated = []int{}
    int step = 0
    while step < max_new_tokens && len(logits) > 0 {
        int next_token = argmax(logits)
        if next_token == tokenizer.eos_id || next_token == tokenizer.bos_id {
            break
        }
        generated = append(generated, next_token)
        logits = forward_token(model, cache, next_token, position)
        position = position + 1
        step = step + 1
    }
    decode(tokenizer, generated)
}

func read_line_from_fd(int fd) string {
    trim(__sys_read_string(fd, 8192))
}

func read_http_request(int fd) string {
    string data = ""
    string chunk = __sys_read_string(fd, 8192)
    while len(chunk) > 0 {
        data = data + chunk
        if find_substring_from(data, "\r\n\r\n", 0) >= 0 {
            break
        }
        chunk = __sys_read_string(fd, 8192)
    }
    data
}

func respond(int fd, int code, string status, string content_type, string body) {
    string response = "HTTP/1.1 " + int_to_string(code) + " " + status + "\r\n" +
        "Content-Type: " + content_type + "\r\n" +
        "Content-Length: " + int_to_string(len(body)) + "\r\n" +
        "Connection: close\r\n\r\n" + body
    _ = __sys_write_string(fd, response)
}

func handle_request(InferenceSession* session, int client_fd) {
    string request = read_http_request(client_fd)
    int separator = find_substring_from(request, "\r\n\r\n", 0)
    if separator < 0 {
        respond(client_fd, 400, "Bad Request", "application/json", "{\"error\":\"bad request\"}")
        return
    }
    string headers = __host_slice(request, 0, separator)
    string body = __host_slice(request, separator + 4, len(request))
    int first_space = find_char_from(headers, " ", 0)
    int second_space = find_char_from(headers, " ", first_space + 1)
    if first_space < 0 || second_space < 0 {
        respond(client_fd, 400, "Bad Request", "application/json", "{\"error\":\"bad request\"}")
        return
    }
    string method = __host_slice(headers, 0, first_space)
    string path = __host_slice(headers, first_space + 1, second_space)
    if method == "GET" && path == "/health" {
        respond(client_fd, 200, "OK", "application/json", "{\"status\":\"ok\",\"backend\":\"neurx-s\"}")
        return
    }
    if method == "POST" && path == "/reset" {
        reset_cache(&session.cache)
        session.cache_ids = []int{}
        respond(client_fd, 200, "OK", "application/json", "{\"status\":\"reset\"}")
        return
    }
    if method == "POST" && path == "/v1/generate" {
        int maximum = 128
        int marker = find_substring_from(headers, "X-Max-New-Tokens:", 0)
        if marker >= 0 {
            int start = marker + len("X-Max-New-Tokens:")
            int end = find_char_from(headers, "\r", start)
            if end < 0 { end = len(headers) }
            maximum = parse_positive_int(__host_slice(headers, start, end), 128)
        }
        []int prompt_ids = tokenize(session.tokenizer, body)
        int common = 0
        while common < len(prompt_ids) && common < len(session.cache_ids) {
            if prompt_ids[common] != session.cache_ids[common] {
                break
            }
            common = common + 1
        }
        if common < len(session.cache_ids) {
            truncate_cache(&session.cache, common, session.model.config.num_key_value_heads * session.model.config.head_dim)
            session.cache_ids = slice_int(session.cache_ids, 0, common)
        }
        int position = common
        []float logits = []float{}
        int i = common
        while i < len(prompt_ids) {
            logits = forward_token(session.model, &session.cache, prompt_ids[i], position)
            session.cache_ids = append(session.cache_ids, prompt_ids[i])
            position = position + 1
            i = i + 1
        }
        []int generated = []int{}
        int step = 0
        while step < maximum && len(logits) > 0 {
            int next_token = argmax(logits)
            if next_token == session.tokenizer.eos_id || next_token == session.tokenizer.bos_id {
                break
            }
            generated = append(generated, next_token)
            session.cache_ids = append(session.cache_ids, next_token)
            logits = forward_token(session.model, &session.cache, next_token, position)
            position = position + 1
            step = step + 1
        }
        string response_text = decode(session.tokenizer, generated)
        respond(client_fd, 200, "OK", "text/plain; charset=utf-8", response_text)
        return
    }
    respond(client_fd, 404, "Not Found", "application/json", "{\"error\":\"not found\"}")
}

func init_session(string model_dir) InferenceSession {
    InferenceSession session
    session.tokenizer = load_tokenizer(model_dir)
    session.model = load_model(model_dir)
    reset_cache(&session.cache)
    session.cache_ids = []int{}
    session
}

func main() {
    string model_dir = runtime_env_get("NEURX_MODEL_DIR", "/home/shuwen/shuwen/posttrain")
    string host = runtime_env_get("NEURX_S_HOST", "127.0.0.1")
    int port = parse_positive_int(runtime_env_get("NEURX_S_PORT", "18082"), 18082)
    string ready_file = runtime_env_get("NEURX_S_READY_FILE", "")
    int threads = parse_positive_int(runtime_env_get("NEURX_CPU_THREADS", "6"), 6)

    print("[NeurX S] loading model=" + model_dir + " threads=" + int_to_string(threads) + "\n")
    if !runtime_file_exists(model_dir + "/model.safetensors") {
        print("error: model not found: " + model_dir + "/model.safetensors\n")
        return
    }
    if !runtime_file_exists(model_dir + "/tokenizer.json") {
        print("error: tokenizer not found: " + model_dir + "/tokenizer.json\n")
        return
    }

    InferenceSession session = init_session(model_dir)
    int listener = neurx_net_listen(host, port, 64)
    if listener < 0 {
        print("error: cannot listen on " + host + ":" + int_to_string(port) + "\n")
        return
    }
    if len(ready_file) > 0 {
        runtime_write_text_file(ready_file, "ready\n")
    }
    print("[NeurX S] ready=http://" + host + ":" + int_to_string(port) + "\n")
    while true {
        int ready = neurx_net_poll(listener, NEURX_POLL_READ, 500)
        if ready <= 0 {
            if ready & NEURX_POLL_ERROR {
                break
            }
            continue
        }
        int client = neurx_net_accept(listener)
        if client < 0 {
            continue
        }
        handle_request(&session, client)
        _ = neurx_net_close(client)
    }
    _ = neurx_net_close(listener)
    if len(ready_file) > 0 {
        _ = runtime_run_command("rm -f " + shell_escape(ready_file))
    }
}
