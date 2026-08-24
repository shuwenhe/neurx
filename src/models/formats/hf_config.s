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
    bool attention_bias
    bool mlp_bias
    bool tie_word_embeddings
    string error_code
}

func hf_json_find(string text, string pattern) int {
    int i = 0
    while i + len(pattern) <= len(text) {
        int j = 0
        bool match = true
        while j < len(pattern) {
            if text[i + j] != pattern[j] { match = false; j = len(pattern) } else { j = j + 1 }
        }
        if match { return i }
        i = i + 1
    }
    -1
}

func hf_json_number_start(string text, string key) int {
    int position = hf_json_find(text, "\"" + key + "\"")
    if position < 0 { return -1 }
    position = position + len(key) + 2
    while position < len(text) && text[position] != 58 { position = position + 1 }
    position = position + 1
    while position < len(text) && (text[position] == 32 || text[position] == 9 || text[position] == 10 || text[position] == 13) { position = position + 1 }
    position
}

func hf_json_int(string text, string key, int fallback) int {
    int position = hf_json_number_start(text, key)
    if position < 0 || position >= len(text) { return fallback }
    int value = 0
    bool found = false
    while position < len(text) {
        int ch = text[position]
        if ch < 48 || ch > 57 { position = len(text) } else { found = true; value = value * 10 + ch - 48; position = position + 1 }
    }
    if !found { return fallback }
    value
}

func hf_json_float(string text, string key, float fallback) float {
    int position = hf_json_number_start(text, key)
    if position < 0 || position >= len(text) { return fallback }
    float value = 0.0
    float scale = 0.0
    while position < len(text) {
        int ch = text[position]
        if ch >= 48 && ch <= 57 {
            if scale == 0.0 { value = value * 10.0 + (ch - 48) * 1.0 } else { scale = scale * 10.0; value = value + (ch - 48) * 1.0 / scale }
            position = position + 1
        } else if ch == 46 && scale == 0.0 {
            scale = 1.0
            position = position + 1
        } else { position = len(text) }
    }
    value
}

func hf_json_bool(string text, string key, bool fallback) bool {
    int position = hf_json_number_start(text, key)
    if position < 0 || position >= len(text) { return fallback }
    if position + 4 <= len(text) && text[position] == 116 && text[position + 1] == 114 && text[position + 2] == 117 && text[position + 3] == 101 { return true }
    if position + 5 <= len(text) && text[position] == 102 && text[position + 1] == 97 && text[position + 2] == 108 && text[position + 3] == 115 && text[position + 4] == 101 { return false }
    fallback
}

func invalid_hf_config(string code) hf_model_config {
    hf_model_config { valid: false, hidden_size: 0, intermediate_size: 0, attention_heads: 0, kv_heads: 0, head_dim: 0, layers: 0, vocabulary_size: 0, max_position_embeddings: 0, rms_epsilon: 0.00001, rope_theta: 10000.0, attention_bias: false, mlp_bias: false, tie_word_embeddings: false, error_code: code }
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
    while i < len(bytes) { content = content + string(bytes[i]); i = i + 1 }
    parse_hf_config(content)
}
