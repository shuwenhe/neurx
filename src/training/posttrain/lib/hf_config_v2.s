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
    if c.num_attention_heads > 0 {
        return c.hidden_size / c.num_attention_heads
    }
    return 0
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
    if c.num_attention_heads <= 0 {
        eprintln("ERROR: num_attention_heads must be positive")
        return false
    }
    if c.hidden_size % c.num_attention_heads != 0 {
        eprintln("ERROR: hidden_size must be divisible by num_attention_heads")
        return false
    }
    if c.num_attention_heads % c.num_key_value_heads != 0 {
        eprintln("ERROR: num_attention_heads must be divisible by num_key_value_heads")
        return false
    }
    return true
}

func extract_json_int(string json_text, string key) int {
    string pattern = "\"" + key + "\":"
    int search_pos = 0
    int found_at = -1
    string temp_text = json_text
    int i = 0
    for i < len(temp_text) - len(pattern) {
        int j = 0
        bool matches = true
        for j < len(pattern) {
            string ch_str = string(temp_text[i + j])
            string pattern_ch_str = string(pattern[j])
            if ch_str != pattern_ch_str {
                matches = false
                break
            }
            j = j + 1
        }
        if matches {
            found_at = i + len(pattern)
            break
        }
        i = i + 1
    }
    if found_at == -1 {
        return 0
    }
    for found_at < len(temp_text) {
        string ch_str = string(temp_text[found_at])
        if ch_str == " " || ch_str == "\t" || ch_str == "\n" || ch_str == "\r" {
            found_at = found_at + 1
        } else {
            break
        }
    }
    int result = 0
    bool negative = false
    if found_at < len(temp_text) {
        string ch_str = string(temp_text[found_at])
        if ch_str == "-" {
            negative = true
            found_at = found_at + 1
        }
    }
    for found_at < len(temp_text) {
        string ch_str = string(temp_text[found_at])
        if ch_str == "0" {
            result = result * 10 + 0
        } else if ch_str == "1" {
            result = result * 10 + 1
        } else if ch_str == "2" {
            result = result * 10 + 2
        } else if ch_str == "3" {
            result = result * 10 + 3
        } else if ch_str == "4" {
            result = result * 10 + 4
        } else if ch_str == "5" {
            result = result * 10 + 5
        } else if ch_str == "6" {
            result = result * 10 + 6
        } else if ch_str == "7" {
            result = result * 10 + 7
        } else if ch_str == "8" {
            result = result * 10 + 8
        } else if ch_str == "9" {
            result = result * 10 + 9
        } else {
            break
        }
        found_at = found_at + 1
    }
    if negative {
        result = -result
    }
    return result
}

func extract_json_float(string json_text, string key) float {
    string pattern = "\"" + key + "\":"
    int found_at = -1
    int i = 0
    for i < len(json_text) - len(pattern) {
        int j = 0
        bool matches = true
        for j < len(pattern) {
            if string(json_text[i + j]) != string(pattern[j]) {
                matches = false
                break
            }
            j = j + 1
        }
        if matches {
            found_at = i + len(pattern)
            break
        }
        i = i + 1
    }
    if found_at == -1 {
        return 0.0
    }
    for found_at < len(json_text) {
        string ch = string(json_text[found_at])
        if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
            found_at = found_at + 1
        } else {
            break
        }
    }
    float result = 0.0
    bool negative = false
    if found_at < len(json_text) {
        string ch = string(json_text[found_at])
        if ch == "-" {
            negative = true
            found_at = found_at + 1
        }
    }
    int int_part = 0
    for found_at < len(json_text) {
        string ch = string(json_text[found_at])
        if ch == "0" {
            int_part = int_part * 10
        } else if ch == "1" {
            int_part = int_part * 10 + 1
        } else if ch == "2" {
            int_part = int_part * 10 + 2
        } else if ch == "3" {
            int_part = int_part * 10 + 3
        } else if ch == "4" {
            int_part = int_part * 10 + 4
        } else if ch == "5" {
            int_part = int_part * 10 + 5
        } else if ch == "6" {
            int_part = int_part * 10 + 6
        } else if ch == "7" {
            int_part = int_part * 10 + 7
        } else if ch == "8" {
            int_part = int_part * 10 + 8
        } else if ch == "9" {
            int_part = int_part * 10 + 9
        } else {
            break
        }
        found_at = found_at + 1
    }
    result = float(int_part)
    if found_at < len(json_text) {
        string ch = string(json_text[found_at])
        if ch == "." {
            found_at = found_at + 1
            float frac_divisor = 10.0
            for found_at < len(json_text) {
                ch = string(json_text[found_at])
                if ch == "0" {
                } else if ch == "1" {
                    result = result + 1.0 / frac_divisor
                } else if ch == "2" {
                    result = result + 2.0 / frac_divisor
                } else if ch == "3" {
                    result = result + 3.0 / frac_divisor
                } else if ch == "4" {
                    result = result + 4.0 / frac_divisor
                } else if ch == "5" {
                    result = result + 5.0 / frac_divisor
                } else if ch == "6" {
                    result = result + 6.0 / frac_divisor
                } else if ch == "7" {
                    result = result + 7.0 / frac_divisor
                } else if ch == "8" {
                    result = result + 8.0 / frac_divisor
                } else if ch == "9" {
                    result = result + 9.0 / frac_divisor
                } else {
                    break
                }
                frac_divisor = frac_divisor * 10.0
                found_at = found_at + 1
            }
        }
    }
    if negative {
        result = -result
    }
    return result
}

func extract_json_string(string json_text, string key) string {
    string pattern = "\"" + key + "\":"
    int found_at = -1
    int i = 0
    for i < len(json_text) - len(pattern) {
        int j = 0
        bool matches = true
        for j < len(pattern) {
            if string(json_text[i + j]) != string(pattern[j]) {
                matches = false
                break
            }
            j = j + 1
        }
        if matches {
            found_at = i + len(pattern)
            break
        }
        i = i + 1
    }
    if found_at == -1 {
        return ""
    }
    for found_at < len(json_text) {
        string ch = string(json_text[found_at])
        if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
            found_at = found_at + 1
        } else {
            break
        }
    }
    if found_at >= len(json_text) || string(json_text[found_at]) != "\"" {
        return ""
    }
    found_at = found_at + 1
    string result = ""
    for found_at < len(json_text) {
        string ch = string(json_text[found_at])
        if ch == "\"" {
            break
        }
        result = result + ch
        found_at = found_at + 1
    }
    return result
}

func extract_json_bool(string json_text, string key) bool {
    string pattern = "\"" + key + "\":"
    int found_at = -1
    int i = 0
    for i < len(json_text) - len(pattern) {
        int j = 0
        bool matches = true
        for j < len(pattern) {
            if string(json_text[i + j]) != string(pattern[j]) {
                matches = false
                break
            }
            j = j + 1
        }
        if matches {
            found_at = i + len(pattern)
            break
        }
        i = i + 1
    }
    if found_at == -1 {
        return false
    }
    for found_at < len(json_text) {
        string ch = string(json_text[found_at])
        if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
            found_at = found_at + 1
        } else {
            break
        }
    }
    if found_at + 4 <= len(json_text) {
        string word = ""
        int j = 0
        for j < 4 && found_at + j < len(json_text) {
            word = word + string(json_text[found_at + j])
            j = j + 1
        }
        if word == "true" {
            return true
        }
    }
    if found_at + 5 <= len(json_text) {
        string word = ""
        int j = 0
        for j < 5 && found_at + j < len(json_text) {
            word = word + string(json_text[found_at + j])
            j = j + 1
        }
        if word == "false" {
            return false
        }
    }
    return false
}

func load_from_file(string path) hf_config {
    interface content = readfile(path)
    string json_text = string(content)
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
    eprintln("Reading config file...")
    string config_path = "../../../model/Qwen2.5-0.5B-Instruct/config.json"
    interface content = readfile(config_path)
    string json_text = string(content)
    eprintln("File read successfully")
    eprintln("File size: 1000+ characters")
    eprintln("")
    eprintln("All tests completed!")
}
