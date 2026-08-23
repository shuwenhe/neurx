package neurx.posttrain.lib.hf_config
use std.io.eprintln
use std.io.readfile

func find_json_key(string json_text, string key) int {
    string pattern = "\"" + key + "\":"
    int i = 0
    while i <= len(json_text) - len(pattern) {
        int j = 0
        bool match = true
        while j < len(pattern) {
            if string(json_text[i + j]) != string(pattern[j]) {
                match = false
                break
            }
            j = j + 1
        }
        if match {
            int pos = i + len(pattern)
            while pos < len(json_text) {
                string ch = string(json_text[pos])
                if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
                    pos = pos + 1
                } else {
                    return pos
                }
            }
            return pos
        }
        i = i + 1
    }
    return -1
}

func extract_int(string json_text, string key) int {
    int pos = find_json_key(json_text, key)
    if pos == -1 {
        return 0
    }
    bool negative = false
    if pos < len(json_text) && string(json_text[pos]) == "-" {
        negative = true
        pos = pos + 1
    }
    int result = 0
    while pos < len(json_text) {
        string ch = string(json_text[pos])
        if ch == "0" {
            result = result * 10
        } else if ch == "1" {
            result = result * 10 + 1
        } else if ch == "2" {
            result = result * 10 + 2
        } else if ch == "3" {
            result = result * 10 + 3
        } else if ch == "4" {
            result = result * 10 + 4
        } else if ch == "5" {
            result = result * 10 + 5
        } else if ch == "6" {
            result = result * 10 + 6
        } else if ch == "7" {
            result = result * 10 + 7
        } else if ch == "8" {
            result = result * 10 + 8
        } else if ch == "9" {
            result = result * 10 + 9
        } else {
            break
        }
        pos = pos + 1
    }
    if negative {
        result = -result
    }
    return result
}

func extract_string(string json_text, string key) string {
    int pos = find_json_key(json_text, key)
    if pos == -1 {
        return ""
    }
    if pos >= len(json_text) || string(json_text[pos]) != "\"" {
        return ""
    }
    pos = pos + 1
    string result = ""
    while pos < len(json_text) {
        string ch = string(json_text[pos])
        if ch == "\"" {
            return result
        }
        result = result + ch
        pos = pos + 1
    }
    return result
}

func extract_float(string json_text, string key) float {
    int pos = find_json_key(json_text, key)
    if pos == -1 {
        return 0.0
    }
    bool negative = false
    if pos < len(json_text) && string(json_text[pos]) == "-" {
        negative = true
        pos = pos + 1
    }
    int int_part = 0
    while pos < len(json_text) {
        string ch = string(json_text[pos])
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
        } else if ch == "." {
            break
        } else {
            break
        }
        pos = pos + 1
    }
    float result = float(int_part)
    if negative {
        result = -result
    }
    return result
}

func extract_bool(string json_text, string key) bool {
    int pos = find_json_key(json_text, key)
    if pos == -1 {
        return false
    }
    if pos + 4 <= len(json_text) {
        string word = ""
        int i = 0
        while i < 4 {
            word = word + string(json_text[pos + i])
            i = i + 1
        }
        if word == "true" {
            return true
        }
    }
    if pos + 5 <= len(json_text) {
        word = ""
        i = 0
        while i < 5 {
            word = word + string(json_text[pos + i])
            i = i + 1
        }
        if word == "false" {
            return false
        }
    }
    return false
}

func main() {
    eprintln("testing hugging_face config parser")
    eprintln("")
    string json_text = "{\"model_type\":\"llama\",\"vocab_size\":32000,\"hidden_size\":3200,\"attention_bias\":false,\"rms_norm_eps\":0.000001}"
    eprintln("[Test: Extract Integer Values]")
    int vocab_size = extract_int(json_text, "vocab_size")
    eprintln("vocab_size extracted")
    int hidden_size = extract_int(json_text, "hidden_size")
    eprintln("hidden_size extracted")
    eprintln("")
    eprintln("[Test: Extract String Values]")
    string model_type = extract_string(json_text, "model_type")
    eprintln("model_type: " + model_type)
    eprintln("")
    eprintln("[Test: Extract Float Values]")
    float eps = extract_float(json_text, "rms_norm_eps")
    eprintln("rms_norm_eps extracted")
    eprintln("")
    eprintln("[Test: Extract Boolean Values]")
    bool attention_bias = extract_bool(json_text, "attention_bias")
    eprintln("attention_bias extracted")
    eprintln("")
    eprintln("✓ Tests completed!")
}
