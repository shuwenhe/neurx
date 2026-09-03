package neurx.models.formats.hf_config
extern "intrinsic" func __host_read_binary_file(string path) []int
struct hf_model_config {
    bool valid
    int hidden_size
    int intermediate_size
    int attention_heads
    int kv_heads
    int head_dim
    int layers
    int vocabulary_size
    int max_position_embeddings
    float rms_epsilon
    float rope_theta
    string rms_epsilon_text
    string rope_theta_text
    bool attention_bias
    bool mlp_bias
    bool tie_word_embeddings
    string error_code
}

func hf_json_find(string text, string pattern) int {
    int i = 0
    for i + len(pattern) <= len(text) {
        string substr = __host_slice(text, i, i + len(pattern))
        if substr == pattern { return i }
        i = i + 1
    }
    -1
}

func hf_json_number_start(string text, string key) int {
    int position = hf_json_find(text, "\"" + key + "\"")
    if position < 0 { return -1 }
    position = position + len(key) + 2
    for position < len(text) {
        string ch = __host_slice(text, position, position + 1)
        if ch != ":" { position = position + 1 } else { break }
    }
    position = position + 1
    for position < len(text) {
        string ch = __host_slice(text, position, position + 1)
        if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" { position = position + 1 } else { break }
    }
    position
}

func hf_json_int(string text, string key, int fallback) int {
    int position = hf_json_number_start(text, key)
    if position < 0 || position >= len(text) { return fallback }
    int value = 0
    bool found = false
    for position < len(text) {
        string ch = __host_slice(text, position, position + 1)
        if ch >= "0" && ch <= "9" {
            found = true
            int digit = 0
            if ch == "0" { digit = 0 }
            else if ch == "1" { digit = 1 }
            else if ch == "2" { digit = 2 }
            else if ch == "3" { digit = 3 }
            else if ch == "4" { digit = 4 }
            else if ch == "5" { digit = 5 }
            else if ch == "6" { digit = 6 }
            else if ch == "7" { digit = 7 }
            else if ch == "8" { digit = 8 }
            else if ch == "9" { digit = 9 }
            value = value * 10 + digit
            position = position + 1
        } else { position = len(text) }
    }
    if !found { return fallback }
    value
}

func hf_json_float(string text, string key, float fallback) float {
    int position = hf_json_number_start(text, key)
    if position < 0 || position >= len(text) { return fallback }
    float value = 0.0
    float scale = 0.0
    for position < len(text) {
        string ch = __host_slice(text, position, position + 1)
        if ch >= "0" && ch <= "9" {
            int digit = 0
            if ch == "0" { digit = 0 }
            else if ch == "1" { digit = 1 }
            else if ch == "2" { digit = 2 }
            else if ch == "3" { digit = 3 }
            else if ch == "4" { digit = 4 }
            else if ch == "5" { digit = 5 }
            else if ch == "6" { digit = 6 }
            else if ch == "7" { digit = 7 }
            else if ch == "8" { digit = 8 }
            else if ch == "9" { digit = 9 }
            if scale == 0.0 { value = value * 10.0 + (digit * 1.0) } else { scale = scale * 10.0; value = value + (digit * 1.0) / scale }
            position = position + 1
        } else if ch == "." && scale == 0.0 {
            scale = 1.0
            position = position + 1
        } else { position = len(text) }
    }
    value
}

func hf_json_number_text(string text, string key, string fallback) string {
    int position = hf_json_number_start(text, key)
    if position < 0 || position >= len(text) { return fallback }
    string value = ""
    for position < len(text) {
        string ch = __host_slice(text, position, position + 1)
        bool is_valid = (ch >= "0" && ch <= "9")
        if !is_valid { is_valid = ch == "." }
        if !is_valid { is_valid = ch == "+" }
        if !is_valid { is_valid = ch == "-" }
        if !is_valid { is_valid = ch == "E" }
        if !is_valid { is_valid = ch == "e" }
        if is_valid {
            value = value + ch
            position = position + 1
        } else { position = len(text) }
    }
    if value == "" { return fallback }
    value
}

func hf_json_bool(string text, string key, bool fallback) bool {
    int position = hf_json_number_start(text, key)
    if position < 0 || position >= len(text) { return fallback }
    if position + 4 <= len(text) {
        string substr = __host_slice(text, position, position + 4)
        if substr == "true" { return true }
    }
    if position + 5 <= len(text) {
        string substr = __host_slice(text, position, position + 5)
        if substr == "false" { return false }
    }
    fallback
}

func invalid_hf_config(string code) hf_model_config {
    hf_model_config { valid: false, hidden_size: 0, intermediate_size: 0, attention_heads: 0, kv_heads: 0, head_dim: 0, layers: 0, vocabulary_size: 0, max_position_embeddings: 0, rms_epsilon: 0.00001, rope_theta: 10000.0, rms_epsilon_text: "0.00001", rope_theta_text: "10000.0", attention_bias: false, mlp_bias: false, tie_word_embeddings: false, error_code: code }
}

func parse_hf_config(string text) hf_model_config {
    int hidden = hf_json_int(text, "hidden_size", 0)
    int intermediate = hf_json_int(text, "intermediate_size", 0)
    int heads = hf_json_int(text, "num_attention_heads", 0)
    int kv_heads = hf_json_int(text, "num_key_value_heads", heads)
    int layers = hf_json_int(text, "num_hidden_layers", 0)
    int vocabulary = hf_json_int(text, "vocab_size", 0)
    int context = hf_json_int(text, "max_position_embeddings", 0)
    if hidden <= 0 || intermediate <= 0 || heads <= 0 || kv_heads <= 0 || layers <= 0 || vocabulary <= 0 || context <= 0 { return invalid_hf_config("invalid_hf_config") }
    if hidden % heads != 0 || heads % kv_heads != 0 { return invalid_hf_config("unsupported_head_layout") }
    hf_model_config {
        valid: true,
        hidden_size: hidden,
        intermediate_size: intermediate,
        attention_heads: heads,
        kv_heads: kv_heads,
        head_dim: hidden / heads,
        layers: layers,
        vocabulary_size: vocabulary,
        max_position_embeddings: context,
        rms_epsilon: hf_json_float(text, "rms_norm_eps", 0.00001),
        rope_theta: hf_json_float(text, "rope_theta", 10000.0),
        rms_epsilon_text: hf_json_number_text(text, "rms_norm_eps", "0.00001"),
        rope_theta_text: hf_json_number_text(text, "rope_theta", "10000.0"),
        attention_bias: hf_json_bool(text, "attention_bias", true),
        mlp_bias: hf_json_bool(text, "mlp_bias", false),
        tie_word_embeddings: hf_json_bool(text, "tie_word_embeddings", false),
        error_code: "",
    }
}

func load_hf_config(string model_dir) hf_model_config {
    []int bytes = __host_read_binary_file(model_dir + "/config.json")
    if len(bytes) == 0 { return invalid_hf_config("config_not_found") }
    string content = ""
    int i = 0
    for i < len(bytes) { content = content + string(bytes[i]); i = i + 1 }
    parse_hf_config(content)
}
