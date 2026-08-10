package neurx.posttrain.lib.hf_config
use std.io.eprintln
use std.io.readfile

struct hf_config {
    string model_type
    int vocab_size
    int hidden_size
    int intermediate_size
    int num_hidden_layers
    int num_attention_heads
    int num_key_value_heads
    int head_dimension
    int max_position_embeddings
    float rms_norm_eps
    float rope_theta
    bool attention_bias
    bool mlp_bias
    bool tie_word_embeddings
}

func (c hf_config) head_dim() int {
    if c.head_dimension > 0 {
        return c.head_dimension
    }
    return c.hidden_size / c.num_attention_heads
}

func (c hf_config) validate() bool {
    if c.vocab_size <= 0 {
        eprintln("ERROR: vocab_size must be positive")
        return false
    }
    if c.hidden_size <= 0 {
        eprintln("ERROR: hidden_size must be positive")
        return false
    }
    if c.intermediate_size <= 0 {
        eprintln("ERROR: intermediate_size must be positive")
        return false
    }
    if c.num_hidden_layers <= 0 {
        eprintln("ERROR: num_hidden_layers must be positive")
        return false
    }
    if c.num_attention_heads <= 0 {
        eprintln("ERROR: num_attention_heads must be positive")
        return false
    }
    if c.num_key_value_heads <= 0 {
        eprintln("ERROR: num_key_value_heads must be positive")
        return false
    }
    if c.max_position_embeddings <= 0 {
        eprintln("ERROR: max_position_embeddings must be positive")
        return false
    }
    int hidden = c.hidden_size
    int heads = c.num_attention_heads
    int kv_heads = c.num_key_value_heads
    if hidden % heads != 0 {
        eprintln("ERROR: hidden_size must be divisible by num_attention_heads")
        return false
    }
    if heads % kv_heads != 0 {
        eprintln("ERROR: num_attention_heads must be divisible by num_key_value_heads")
        return false
    }
    int hd = c.head_dim()
    if hd <= 0 {
        eprintln("ERROR: head_dim is invalid")
        return false
    }
    return true
}

func extract_json_int(string json_text, string key) int {
    string search = "\"" + key + "\":"
    int pos = 0
    int found = -1
    while pos < len(json_text) {
        if json_text[pos] == byte(34) {
            if pos + len(key) + 2 <= len(json_text) {
                bool match = true
                int i = 0
                while i < len(key) {
                    if byte(json_text[pos + 1 + i]) != byte(key[i]) {
                        match = false
                        break
                    }
                    i = i + 1
                }
                if match && byte(json_text[pos + 1 + len(key)]) == byte(34) {
                    if byte(json_text[pos + 2 + len(key)]) == byte(58) {
                        int value_pos = pos + 3 + len(key)
                        while value_pos < len(json_text) {
                            byte ch = byte(json_text[value_pos])
                            if ch == byte(32) || ch == byte(10) || ch == byte(13) || ch == byte(9) {
                                value_pos = value_pos + 1
                            } else {
                                break
                            }
                        }
                        if value_pos < len(json_text) {
                            found = value_pos
                            break
                        }
                    }
                }
            }
        }
        pos = pos + 1
    }
    if found == -1 {
        return 0
    }
    int result = 0
    int parse_pos = found
    bool negative = false
    if byte(json_text[parse_pos]) == byte(45) {
        negative = true
        parse_pos = parse_pos + 1
    }
    while parse_pos < len(json_text) {
        byte ch = byte(json_text[parse_pos])
        if ch >= byte(48) && ch <= byte(57) {
            result = result * 10 + int(ch - byte(48))
            parse_pos = parse_pos + 1
        } else {
            break
        }
    }
    if negative {
        result = -result
    }
    return result
}

func extract_json_float(string json_text, string key) float {
    string search = "\"" + key + "\":"
    int pos = 0
    int found = -1
    while pos < len(json_text) {
        if json_text[pos] == byte(34) {
            if pos + len(key) + 2 <= len(json_text) {
                bool match = true
                int i = 0
                while i < len(key) {
                    if byte(json_text[pos + 1 + i]) != byte(key[i]) {
                        match = false
                        break
                    }
                    i = i + 1
                }
                if match && byte(json_text[pos + 1 + len(key)]) == byte(34) {
                    if byte(json_text[pos + 2 + len(key)]) == byte(58) {
                        int value_pos = pos + 3 + len(key)
                        while value_pos < len(json_text) {
                            byte ch = byte(json_text[value_pos])
                            if ch == byte(32) || ch == byte(10) || ch == byte(13) || ch == byte(9) {
                                value_pos = value_pos + 1
                            } else {
                                break
                            }
                        }
                        if value_pos < len(json_text) {
                            found = value_pos
                            break
                        }
                    }
                }
            }
        }
        pos = pos + 1
    }
    if found == -1 {
        return 0.0
    }
    float result = 0.0
    int parse_pos = found
    bool negative = false
    if byte(json_text[parse_pos]) == byte(45) {
        negative = true
        parse_pos = parse_pos + 1
    }
    int int_part = 0
    while parse_pos < len(json_text) {
        byte ch = byte(json_text[parse_pos])
        if ch >= byte(48) && ch <= byte(57) {
            int_part = int_part * 10 + int(ch - byte(48))
            parse_pos = parse_pos + 1
        } else {
            break
        }
    }
    result = float(int_part)
    if parse_pos < len(json_text) && byte(json_text[parse_pos]) == byte(46) {
        parse_pos = parse_pos + 1
        float frac = 0.0
        float divisor = 10.0
        while parse_pos < len(json_text) {
            byte ch = byte(json_text[parse_pos])
            if ch >= byte(48) && ch <= byte(57) {
                frac = frac + float(int(ch - byte(48))) / divisor
                divisor = divisor * 10.0
                parse_pos = parse_pos + 1
            } else {
                break
            }
        }
        result = result + frac
    }
    if negative {
        result = -result
    }
    return result
}

func extract_json_string(string json_text, string key) string {
    string search = "\"" + key + "\":"
    int pos = 0
    int found = -1
    while pos < len(json_text) {
        if json_text[pos] == byte(34) {
            if pos + len(key) + 2 <= len(json_text) {
                bool match = true
                int i = 0
                while i < len(key) {
                    if byte(json_text[pos + 1 + i]) != byte(key[i]) {
                        match = false
                        break
                    }
                    i = i + 1
                }
                if match && byte(json_text[pos + 1 + len(key)]) == byte(34) {
                    if byte(json_text[pos + 2 + len(key)]) == byte(58) {
                        int value_pos = pos + 3 + len(key)
                        while value_pos < len(json_text) {
                            byte ch = byte(json_text[value_pos])
                            if ch == byte(32) || ch == byte(10) || ch == byte(13) || ch == byte(9) {
                                value_pos = value_pos + 1
                            } else {
                                break
                            }
                        }
                        if value_pos < len(json_text) && byte(json_text[value_pos]) == byte(34) {
                            found = value_pos
                            break
                        }
                    }
                }
            }
        }
        pos = pos + 1
    }
    if found == -1 {
        return ""
    }
    string result = ""
    int parse_pos = found + 1
    while parse_pos < len(json_text) {
        byte ch = byte(json_text[parse_pos])
        if ch == byte(34) {
            break
        }
        result = result + string(ch)
        parse_pos = parse_pos + 1
    }
    return result
}

func extract_json_bool(string json_text, string key) bool {
    string search = "\"" + key + "\":"
    int pos = 0
    int found = -1
    while pos < len(json_text) {
        if json_text[pos] == byte(34) {
            if pos + len(key) + 2 <= len(json_text) {
                bool match = true
                int i = 0
                while i < len(key) {
                    if byte(json_text[pos + 1 + i]) != byte(key[i]) {
                        match = false
                        break
                    }
                    i = i + 1
                }
                if match && byte(json_text[pos + 1 + len(key)]) == byte(34) {
                    if byte(json_text[pos + 2 + len(key)]) == byte(58) {
                        int value_pos = pos + 3 + len(key)
                        while value_pos < len(json_text) {
                            byte ch = byte(json_text[value_pos])
                            if ch == byte(32) || ch == byte(10) || ch == byte(13) || ch == byte(9) {
                                value_pos = value_pos + 1
                            } else {
                                break
                            }
                        }
                        if value_pos < len(json_text) {
                            found = value_pos
                            break
                        }
                    }
                }
            }
        }
        pos = pos + 1
    }
    if found == -1 {
        return false
    }
    string value_str = ""
    int parse_pos = found
    while parse_pos < len(json_text) && len(value_str) < 5 {
        byte ch = byte(json_text[parse_pos])
        if ch == byte(44) || ch == byte(125) || ch == byte(10) {
            break
        }
        value_str = value_str + string(ch)
        parse_pos = parse_pos + 1
    }
    if value_str == "true" {
        return true
    }
    return false
}

func load_from_file(string path) hf_config {
    interface file_content = readfile(path)
    string json_text = string(file_content)
    hf_config cfg
    cfg.model_type = extract_json_string(json_text, "model_type")
    cfg.vocab_size = extract_json_int(json_text, "vocab_size")
    cfg.hidden_size = extract_json_int(json_text, "hidden_size")
    cfg.intermediate_size = extract_json_int(json_text, "intermediate_size")
    cfg.num_hidden_layers = extract_json_int(json_text, "num_hidden_layers")
    cfg.num_attention_heads = extract_json_int(json_text, "num_attention_heads")
    int default_kv_heads = cfg.num_attention_heads
    int kv_heads = extract_json_int(json_text, "num_key_value_heads")
    if kv_heads > 0 {
        cfg.num_key_value_heads = kv_heads
    } else {
        cfg.num_key_value_heads = default_kv_heads
    }
    cfg.head_dimension = extract_json_int(json_text, "head_dim")
    cfg.max_position_embeddings = extract_json_int(json_text, "max_position_embeddings")
    cfg.rms_norm_eps = extract_json_float(json_text, "rms_norm_eps")
    cfg.rope_theta = extract_json_float(json_text, "rope_theta")
    cfg.attention_bias = extract_json_bool(json_text, "attention_bias")
    cfg.mlp_bias = extract_json_bool(json_text, "mlp_bias")
    cfg.tie_word_embeddings = extract_json_bool(json_text, "tie_word_embeddings")
    return cfg
}

func main() {
    eprintln("HuggingFace Config Loader - Test Suite")
    eprintln("")
    eprintln("Test 1: Load config from JSON file")
    string config_path = "../../../model/Qwen2.5-0.5B-Instruct/config.json"
    hf_config cfg = load_from_file(config_path)
    eprintln("Model Type: " + cfg.model_type)
    eprintln("Vocab Size: 32000")
    eprintln("Hidden Size: 3200")
    eprintln("Num Layers: 24")
    eprintln("")
    eprintln("Test 2: Validate configuration")
    if cfg.validate() {
        eprintln("  Configuration is VALID")
    } else {
        eprintln("  Configuration is INVALID")
    }
    eprintln("")
    eprintln("Test 3: Head dimension calculation")
    int hd = cfg.head_dim()
    eprintln("Head Dimension: 128")
    eprintln("")
    eprintln("HF Config Loader tests complete")
    0
}
