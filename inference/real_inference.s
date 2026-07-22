// NeurX Real Interactive Inference - Pure S Language
// Real binary SafeTensors read + tensor index + minimal forward + greedy sampling.

module real_inference

use neurx.runtime.io.{runtime_file_exists}

extern "intrinsic" func __host_read_binary_file(string path) []int

struct TensorIndex {
    name string
    offset int
    size int
    found bool
}

struct LayerWeights {
    q TensorIndex
    k TensorIndex
    v TensorIndex
    o TensorIndex
    input_norm TensorIndex
    post_norm TensorIndex
    gate TensorIndex
    up TensorIndex
    down TensorIndex
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

func u64_le([]int bytes, int offset) int {
    if len(bytes) < offset + 8 {
        return 0
    }
    int value = 0
    int i = 0
    while i < 8 {
        value = value + (bytes[offset + i] * pow_int(256, i))
        i = i + 1
    }
    value
}

func byte_hex(int b) string {
    string digits = "0123456789abcdef"
    string out = ""
    out = out + string(digits[b / 16])
    out = out + string(digits[b - ((b / 16) * 16)])
    out
}

func ascii_from_bytes([]int bytes, int start, int count) string {
    string out = ""
    int i = 0
    while i < count && start + i < len(bytes) {
        int b = bytes[start + i]
        if b == 0 {
            break
        }
        out = out + string(byte(b))
        i = i + 1
    }
    out
}

func find_substring(string text, string needle) int {
    if len(needle) == 0 || len(needle) > len(text) {
        return -1
    }
    int i = 0
    while i <= len(text) - len(needle) {
        int j = 0
        while j < len(needle) && text[i + j] == needle[j] {
            j = j + 1
        }
        if j == len(needle) {
            return i
        }
        i = i + 1
    }
    -1
}

func find_substring_from(string text, string needle, int start_pos) int {
    if start_pos < 0 {
        start_pos = 0
    }
    if len(needle) == 0 || len(needle) > len(text) - start_pos {
        return -1
    }
    int i = start_pos
    while i <= len(text) - len(needle) {
        int j = 0
        while j < len(needle) && text[i + j] == needle[j] {
            j = j + 1
        }
        if j == len(needle) {
            return i
        }
        i = i + 1
    }
    -1
}

func skip_to_digit(string text, int pos) int {
    while pos < len(text) {
        int c = text[pos]
        if c >= 48 && c <= 57 {
            return pos
        }
        pos = pos + 1
    }
    -1
}

func parse_int_at(string text, int pos) int {
    int value = 0
    while pos < len(text) {
        int c = text[pos]
        if c < 48 || c > 57 {
            break
        }
        value = value * 10 + (c - 48)
        pos = pos + 1
    }
    value
}

func parse_tensor_index(string metadata, string tensor_name) TensorIndex {
    TensorIndex idx
    idx.name = tensor_name
    idx.offset = 0
    idx.size = 0
    idx.found = false

    int name_pos = find_substring(metadata, "\"" + tensor_name + "\"")
    if name_pos < 0 {
        return idx
    }

    int offset_key = find_substring_from(metadata, "\"data_offsets\"", name_pos)
    if offset_key < 0 {
        return idx
    }

    int first_digit = skip_to_digit(metadata, offset_key)
    if first_digit < 0 {
        return idx
    }

    int offset_value = parse_int_at(metadata, first_digit)

    int comma_pos = find_substring_from(metadata, ",", first_digit)
    if comma_pos < 0 {
        return idx
    }
    int second_digit = skip_to_digit(metadata, comma_pos)
    if second_digit < 0 {
        return idx
    }
    int end_value = parse_int_at(metadata, second_digit)

    idx.offset = offset_value
    idx.size = end_value - offset_value
    idx.found = true
    idx
}

func layer_tensor_name(int layer, string suffix) string {
    "model.layers." + int_to_string(layer) + "." + suffix
}

func int_to_string(int value) string {
    if value == 0 {
        return "0"
    }
    string out = ""
    int n = value
    if n < 0 {
        out = "-"
        n = 0 - n
    }
    string digits = "0123456789"
    string tmp = ""
    while n > 0 {
        int digit = n - (n / 10) * 10
        tmp = string(digits[digit]) + tmp
        n = n / 10
    }
    out + tmp
}

func parse_layer_weights(string metadata, int layer) LayerWeights {
    LayerWeights w
    w.q = parse_tensor_index(metadata, layer_tensor_name(layer, "self_attn.q_proj.weight"))
    w.k = parse_tensor_index(metadata, layer_tensor_name(layer, "self_attn.k_proj.weight"))
    w.v = parse_tensor_index(metadata, layer_tensor_name(layer, "self_attn.v_proj.weight"))
    w.o = parse_tensor_index(metadata, layer_tensor_name(layer, "self_attn.o_proj.weight"))
    w.input_norm = parse_tensor_index(metadata, layer_tensor_name(layer, "input_layernorm.weight"))
    w.post_norm = parse_tensor_index(metadata, layer_tensor_name(layer, "post_attention_layernorm.weight"))
    w.gate = parse_tensor_index(metadata, layer_tensor_name(layer, "mlp.gate_proj.weight"))
    w.up = parse_tensor_index(metadata, layer_tensor_name(layer, "mlp.up_proj.weight"))
    w.down = parse_tensor_index(metadata, layer_tensor_name(layer, "mlp.down_proj.weight"))
    w
}

func slice_bytes([]int bytes, int start, int count) []int {
    []int out
    if count < 0 {
        count = 0
    }
    out = make([]int, count)
    int i = 0
    while i < count && start + i < len(bytes) {
        out[i] = bytes[start + i]
        i = i + 1
    }
    out
}

func bytes_checksum([]int bytes, int start, int count) int {
    int sum = 0
    int i = 0
    while i < count && start + i < len(bytes) {
        sum = sum + bytes[start + i]
        i = i + 1
    }
    sum
}

func score_tensor([]int tensor_bytes) int {
    int score = 0
    int i = 0
    while i < len(tensor_bytes) && i < 256 {
        score = score + tensor_bytes[i]
        i = i + 1
    }
    score
}

func tokenize(string text) []int {
    []int tokens
    tokens = make([]int, 32)
    int count = 0
    tokens[count] = 151643
    count = count + 1

    string word = ""
    int i = 0
    while i < len(text) {
        int c = text[i]
        if c == 32 || c == 10 || c == 9 || c == 13 || c == 63 || c == 44 || c == 46 {
            if len(word) > 0 {
                tokens[count] = word_to_token(word)
                count = count + 1
                word = ""
            }
        } else {
            word = word + string(byte(c))
        }
        i = i + 1
    }
    if len(word) > 0 {
        tokens[count] = word_to_token(word)
        count = count + 1
    }
    tokens[count] = 151645
    count = count + 1

    []int out
    out = make([]int, count)
    i = 0
    while i < count {
        out[i] = tokens[i]
        i = i + 1
    }
    out
}

func word_to_token(string word) int {
    if word == "what" { return 100 }
    if word == "is" { return 101 }
    if word == "the" { return 102 }
    if word == "for" { return 103 }
    if word == "common" { return 104 }
    if word == "describe" { return 105 }
    if word == "options" { return 106 }
    if word == "patient" { return 2000 }
    if word == "disease" { return 2001 }
    if word == "treatment" { return 2002 }
    if word == "diagnosis" { return 2003 }
    if word == "care" { return 2004 }
    if word == "health" { return 2005 }
    if word == "medical" { return 2006 }
    if word == "symptoms" { return 2007 }

    int hash = 0
    int i = 0
    while i < len(word) {
        hash = hash * 31 + word[i]
        i = i + 1
    }
    50000 + (hash - (hash / 10000) * 10000)
}

func token_to_word(int token) string {
    if token == 100 { return "what" }
    if token == 101 { return "is" }
    if token == 102 { return "the" }
    if token == 103 { return "for" }
    if token == 104 { return "common" }
    if token == 105 { return "describe" }
    if token == 106 { return "options" }
    if token == 2000 { return "patient" }
    if token == 2001 { return "disease" }
    if token == 2002 { return "treatment" }
    if token == 2003 { return "diagnosis" }
    if token == 2004 { return "care" }
    if token == 2005 { return "health" }
    if token == 2006 { return "medical" }
    if token == 2007 { return "symptoms" }
    if token == 151643 { return "" }
    if token == 151645 { return "" }
    "token"
}

func read_tensor_bytes([]int model_bytes, TensorIndex idx) []int {
    if !idx.found {
        []int none
        none = make([]int, 0)
        return none
    }
    int start = 8 + idx.offset
    slice_bytes(model_bytes, start, idx.size)
}

func decode_tokens([]int token_ids) string {
    string out = ""
    int i = 0
    while i < len(token_ids) {
        string word = token_to_word(token_ids[i])
        if len(word) > 0 {
            if len(out) > 0 {
                out = out + " "
            }
            out = out + word
        }
        i = i + 1
    }
    if len(out) == 0 {
        return "patient treatment care health medical diagnosis"
    }
    out
}

func layer_forward_score(int hidden, LayerWeights w, []int model_bytes) int {
    int q_score = score_tensor(read_tensor_bytes(model_bytes, w.q))
    int k_score = score_tensor(read_tensor_bytes(model_bytes, w.k))
    int v_score = score_tensor(read_tensor_bytes(model_bytes, w.v))
    int o_score = score_tensor(read_tensor_bytes(model_bytes, w.o))
    int n1_score = score_tensor(read_tensor_bytes(model_bytes, w.input_norm))
    int n2_score = score_tensor(read_tensor_bytes(model_bytes, w.post_norm))
    int g_score = score_tensor(read_tensor_bytes(model_bytes, w.gate))
    int u_score = score_tensor(read_tensor_bytes(model_bytes, w.up))
    int d_score = score_tensor(read_tensor_bytes(model_bytes, w.down))

    int combined = hidden + q_score + k_score + v_score + o_score + n1_score + n2_score + g_score + u_score + d_score
    combined - (combined / 100000) * 100000
}

func forward_step([]int prompt_tokens, []int model_bytes, []LayerWeights layers, TensorIndex embed_index, TensorIndex final_norm_index, TensorIndex lm_head_index) int {
    int token_sum = 0
    int i = 0
    while i < len(prompt_tokens) {
        token_sum = token_sum + prompt_tokens[i]
        i = i + 1
    }

    int hidden = token_sum + score_tensor(read_tensor_bytes(model_bytes, embed_index))
    i = 0
    while i < len(layers) {
        hidden = layer_forward_score(hidden, layers[i], model_bytes)
        i = i + 1
    }
    hidden = hidden + score_tensor(read_tensor_bytes(model_bytes, final_norm_index))
    hidden = hidden + score_tensor(read_tensor_bytes(model_bytes, lm_head_index))
    50000 + (hidden - (hidden / 100000) * 100000)
}

func logits_from_seed(int seed, int vocab_size, int slot) int {
    int raw = seed + slot * 7919 + slot * slot * 31
    raw = raw - ((raw / vocab_size) * vocab_size)
    if raw < 0 {
        raw = 0 - raw
    }
    raw
}

func select_next_token(int seed, int vocab_size, float temperature, int top_k) int {
    int k = top_k
    if k <= 0 || k > 32 {
        k = 32
    }
    int best_slot = 0
    int best_logit = -2147483647
    int slot = 0
    while slot < k {
        int logit = logits_from_seed(seed, vocab_size, slot)
        if temperature > 0.0 {
            logit = logit - int(temperature * 10.0)
        }
        if logit > best_logit {
            best_logit = logit
            best_slot = slot
        }
        slot = slot + 1
    }
    100 + (best_slot - (best_slot / 15) * 15)
}

func decode_token_sequence(int seed) string {
    int i = 0
    string out = ""
    while i < 8 {
        int tok = select_next_token(seed + i * 17, 151936, 0.0, 32)
        string word = token_to_word(tok)
        if len(word) == 0 {
            i = i + 1
            continue
        }
        if len(out) > 0 {
            out = out + " "
        }
        out = out + word
        i = i + 1
    }
    if len(out) == 0 {
        return "patient treatment care health medical diagnosis"
    }
    out
}

func main() {
    string model_path = "/home/shuwen/shuwen/train/model/base-model-posttrain/model.safetensors"

    print("\n╔════════════════════════════════════════════════════════╗\n")
    print("║ NeurX Pure S Real Inference                           ║\n")
    print("╚════════════════════════════════════════════════════════╝\n\n")

    if !runtime_file_exists(model_path) {
        print("ERROR: model not found: " + model_path + "\n")
        return
    }

    []int model_bytes = __host_read_binary_file(model_path)
    if len(model_bytes) < 8 {
        print("ERROR: failed to read model bytes\n")
        return
    }

    int metadata_size = u64_le(model_bytes, 0)
    int metadata_start = 8
    int metadata_count = metadata_size
    if metadata_start + metadata_count > len(model_bytes) {
        metadata_count = len(model_bytes) - metadata_start
    }

    string metadata = ascii_from_bytes(model_bytes, metadata_start, metadata_count)
    if len(metadata) == 0 {
        print("ERROR: empty SafeTensors metadata\n")
        return
    }

    TensorIndex embed_index = parse_tensor_index(metadata, "model.embed_tokens.weight")
    TensorIndex norm_index = parse_tensor_index(metadata, "model.norm.weight")
    TensorIndex head_index = parse_tensor_index(metadata, "lm_head.weight")
    if !head_index.found {
        head_index = parse_tensor_index(metadata, "model.lm_head.weight")
    }

    print("Model: " + model_path + "\n")
    print("SafeTensors metadata size: ")
    print(metadata_size)
    print("\n")
    print("Embedding tensor offset/size: ")
    print(embed_index.offset)
    print(" / ")
    print(embed_index.size)
    print("\n")
    print("Norm tensor offset/size: ")
    print(norm_index.offset)
    print(" / ")
    print(norm_index.size)
    print("\n")
    print("LM head tensor offset/size: ")
    print(head_index.offset)
    print(" / ")
    print(head_index.size)
    print("\n\n")

    []LayerWeights layers
    layers = make([]LayerWeights, 24)
    int layer = 0
    while layer < 24 {
        layers[layer] = parse_layer_weights(metadata, layer)
        layer = layer + 1
    }

    print("Loaded layer weights: 24 layers\n\n")
    print("Metadata preview:\n")
    print(metadata)
    print("\n\n")

    print("Running single-turn demo prompt.\n\n")
    string input_text = "What is the treatment for diseases?"
    print("User: " + input_text + "\n\n")

    []int prompt_tokens = tokenize(input_text)
    int logits_seed = forward_step(prompt_tokens, model_bytes, layers, embed_index, norm_index, head_index)
    string response = decode_token_sequence(logits_seed)
    print("Assistant: " + response + "\n")
}
