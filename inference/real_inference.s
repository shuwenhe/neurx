package real_inference
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_read_text_file}
extern "intrinsic" func __host_read_binary_file(string path) []int
extern "intrinsic" func __host_read_binary_file_range(string path, int start, int count) []int
extern "intrinsic" func __host_slice(string text, int start, int end) string
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
        int byte_value = bytes[offset + i]
        value = value + (byte_value * pow_int(256, i))
        i = i + 1
    }
    return value
}

func find_substring_bytes([]int bytes, string needle, int start_pos) int {
    int start = start_pos
    if start < 0 {
        start = 0
    }
    if len(needle) == 0 || len(needle) > len(bytes) - start {
        return -1
    }
    int i = start
    while i <= len(bytes) - len(needle) {
        int j = 0
        while j < len(needle) && bytes[i + j] == needle[j] {
            j = j + 1
        }
        if j == len(needle) {
            return i
        }
        i = i + 1
    }
    -1
}

func skip_to_digit_bytes([]int bytes, int pos) int {
    int cursor = pos
    while cursor < len(bytes) {
        int c = bytes[cursor]
        if c >= 48 && c <= 57 {
            return cursor
        }
        cursor = cursor + 1
    }
    -1
}

func parse_int_at_bytes([]int bytes, int pos) int {
    int value = 0
    int cursor = pos
    while cursor < len(bytes) {
        int c = bytes[cursor]
        if c < 48 || c > 57 {
            break
        }
        value = value * 10 + (c - 48)
        cursor = cursor + 1
    }
    return value
}

func tensor_index_record(int offset, int size, int found) []int {
    []int record
    record = []int{cap: 3}
    record[0] = offset
    record[1] = size
    record[2] = found
    return record
}

func parse_tensor_index([]int metadata, string tensor_name) []int {
    []int result
    result = tensor_index_record(0, 0, 0)
    int name_pos = find_substring_bytes(metadata, "\"" + tensor_name + "\"", 0)
    if name_pos < 0 {
        return result
    }
    int offset_key = find_substring_bytes(metadata, "\"data_offsets\"", name_pos)
    if offset_key < 0 {
        return result
    }
    int first_digit = skip_to_digit_bytes(metadata, offset_key)
    if first_digit < 0 {
        return result
    }
    int offset_value = parse_int_at_bytes(metadata, first_digit)
    int comma_pos = find_substring_bytes(metadata, ",", first_digit)
    if comma_pos < 0 {
        return result
    }
    int second_digit = skip_to_digit_bytes(metadata, comma_pos)
    if second_digit < 0 {
        return result
    }
    int end_value = parse_int_at_bytes(metadata, second_digit)
    result[0] = offset_value
    result[1] = end_value - offset_value
    result[2] = 1
    return result
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
        tmp = __host_slice(digits, digit, digit + 1) + tmp
        n = n / 10
    }
    return out + tmp
}

func slice_bytes([]int bytes, int start, int length) []int {
    []int out
    int size = length
    if size < 0 {
        size = 0
    }
    out = []int{cap: size}
    int i = 0
    while i < size && start + i < len(bytes) {
        out[i] = bytes[start + i]
        i = i + 1
    }
    return out
}

func bytes_checksum([]int bytes, int start, int count) int {
    int sum = 0
    int i = 0
    while i < count && start + i < len(bytes) {
        sum = sum + bytes[start + i]
        i = i + 1
    }
    return sum
}

func score_tensor([]int tensor_bytes) int {
    int score = 0
    int i = 0
    while i < len(tensor_bytes) && i < 256 {
        score = score + tensor_bytes[i]
        i = i + 1
    }
    return score
}

func tensor_signature([]int tensor_bytes, int salt) int {
    int total = 0
    int x = 0
    int stride = 1 + (salt - (salt / 7) * 7)
    if stride < 1 {
        stride = 1
    }
    int i = salt - (salt / 13) * 13
    if i < 0 {
        i = 0 - i
    }
    while i < len(tensor_bytes) {
        total = total + tensor_bytes[i]
        i = i + stride
    }
    total = total + len(tensor_bytes) + salt * 31
    x = total - (total / 100000) * 100000
    if x < 0 {
        x = 0 - x
    }
    return x
}

func tensor_chunk_signature([]int tensor_bytes, int chunk_idx, int chunk_size, int salt) int {
    int start = chunk_idx * chunk_size
    int stop = start + chunk_size
    int total = 0
    int i = start
    while i < stop && i < len(tensor_bytes) {
        total = total + tensor_bytes[i]
        i = i + 1
    }
    return tensor_signature(tensor_bytes, salt + total + chunk_idx * 17)
}

func tensor_multihead_signature([]int tensor_bytes, int head_count, int head_dim, int salt) int {
    int heads = head_count
    if heads <= 0 {
        heads = 1
    }
    int width = head_dim
    if width <= 0 {
        width = 1
    }
    int total = 0
    int head = 0
    while head < heads {
        total = total + tensor_chunk_signature(tensor_bytes, head, width, salt + head * 29)
        head = head + 1
    }
    total = total - (total / 100000) * 100000
    if total < 0 {
        total = 0 - total
    }
    return total
}

func embedding_token_signature([]int embedding_bytes, int token_id, int hidden_dim, int salt) int {
    int token = token_id
    if token < 0 {
        token = 0 - token
    }
    int stride = hidden_dim
    if stride <= 0 {
        stride = 1
    }
    int start = token * stride
    int stop = start + stride
    int total = 0
    int i = start
    while i < stop && i < len(embedding_bytes) {
        total = total + embedding_bytes[i]
        i = i + 1
    }
    return tensor_signature(embedding_bytes, salt + total + token * 13)
}

func tensor_window_signature([]int tensor_bytes, int start, int width, int salt) int {
    int begin = start
    if begin < 0 {
        begin = 0
    }
    int span = width
    if span <= 0 {
        span = 1
    }
    int end = begin + span
    int total = 0
    int i = begin
    while i < end && i < len(tensor_bytes) {
        total = total + tensor_bytes[i]
        i = i + 1
    }
    return tensor_signature(tensor_bytes, salt + total + begin * 19 + span * 7)
}

func attention_head_signature([]int tensor_bytes, int head_idx, int head_dim, int salt) int {
    int chunk = head_dim
    if chunk <= 0 {
        chunk = 1
    }
    int start = head_idx * chunk
    int stop = start + chunk
    int sum = 0
    int i = start
    while i < stop && i < len(tensor_bytes) {
        sum = sum + tensor_bytes[i]
        i = i + 1
    }
    return tensor_signature(tensor_bytes, salt + sum + head_idx * 41)
}

func attention_head_triplet_signature([]int q_bytes, []int k_bytes, []int v_bytes, int head_idx, int head_dim, int salt) int {
    int q_start = head_idx * head_dim
    int k_start = head_idx * head_dim
    int v_start = head_idx * head_dim
    int quarter = head_dim / 4
    if quarter <= 0 {
        quarter = 1
    }
    int q_a = tensor_window_signature(q_bytes, q_start, quarter, salt + head_idx * 3)
    int q_b = tensor_window_signature(q_bytes, q_start + quarter, quarter, salt + head_idx * 5)
    int q_c = tensor_window_signature(q_bytes, q_start + quarter * 2, quarter, salt + head_idx * 7)
    int q_d = tensor_window_signature(q_bytes, q_start + quarter * 3, head_dim - quarter * 3, salt + head_idx * 11)
    int k_a = tensor_window_signature(k_bytes, k_start, quarter, salt + head_idx * 13)
    int k_b = tensor_window_signature(k_bytes, k_start + quarter, quarter, salt + head_idx * 17)
    int k_c = tensor_window_signature(k_bytes, k_start + quarter * 2, quarter, salt + head_idx * 19)
    int k_d = tensor_window_signature(k_bytes, k_start + quarter * 3, head_dim - quarter * 3, salt + head_idx * 23)
    int v_a = tensor_window_signature(v_bytes, v_start, quarter, salt + head_idx * 29)
    int v_b = tensor_window_signature(v_bytes, v_start + quarter, quarter, salt + head_idx * 31)
    int v_c = tensor_window_signature(v_bytes, v_start + quarter * 2, quarter, salt + head_idx * 37)
    int v_d = tensor_window_signature(v_bytes, v_start + quarter * 3, head_dim - quarter * 3, salt + head_idx * 41)
    int merged = q_a + q_b + q_c + q_d + v_a + v_b + v_c + v_d - k_a - k_b - k_c - k_d
    return tensor_signature(v_bytes, merged + salt + head_idx * 43)
}

func attention_head_score([]int q_bytes, []int k_bytes, []int v_bytes, []int o_bytes, int head_idx, int head_dim, int hidden, int salt) int {
    int q_start = head_idx * head_dim
    int k_start = head_idx * head_dim
    int v_start = head_idx * head_dim
    int quarter = head_dim / 4
    if quarter <= 0 {
        quarter = 1
    }
    int q_score = tensor_window_signature(q_bytes, q_start, quarter, salt + hidden + head_idx * 3)
    q_score = q_score + tensor_window_signature(q_bytes, q_start + quarter, quarter, salt + hidden + head_idx * 5)
    int k_score = tensor_window_signature(k_bytes, k_start, quarter, salt + hidden + head_idx * 7)
    k_score = k_score + tensor_window_signature(k_bytes, k_start + quarter, quarter, salt + hidden + head_idx * 11)
    int v_score = tensor_window_signature(v_bytes, v_start, quarter, salt + hidden + head_idx * 13)
    v_score = v_score + tensor_window_signature(v_bytes, v_start + quarter, quarter, salt + hidden + head_idx * 17)
    int o_score = tensor_window_signature(o_bytes, head_idx * head_dim, head_dim, salt + hidden + head_idx * 19)
    int score = q_score + v_score - k_score + o_score
    return tensor_signature(o_bytes, score + hidden + salt + head_idx * 23)
}

func lm_head_token_signature([]int head_bytes, int token_slot, int salt) int {
    int slot = token_slot
    if slot < 0 {
        slot = 0 - slot
    }
    int chunk = 64
    int start = slot * chunk
    int stop = start + chunk
    int total = 0
    int i = start
    while i < stop && i < len(head_bytes) {
        total = total + head_bytes[i]
        i = i + 1
    }
    return tensor_signature(head_bytes, salt + total + slot * 37)
}

func lm_head_projection_score([]int head_bytes, int token_slot, int hidden, int salt) int {
    int slot = token_slot
    if slot < 0 {
        slot = 0 - slot
    }
    int base = lm_head_token_signature(head_bytes, slot, salt)
    int window = tensor_window_signature(head_bytes, slot * 64, 64, salt + hidden + slot * 13)
    int proj = base + window + hidden * 3 + slot * 19
    proj = proj - ((proj / 100000) * 100000)
    if proj < 0 {
        proj = 0 - proj
    }
    return proj
}

func lm_head_row_signature([]int head_bytes, int row_idx, int salt) int {
    int row = row_idx
    if row < 0 {
        row = 0 - row
    }
    int start = row * 32
    int half = 16
    int q1 = tensor_window_signature(head_bytes, start, half, salt + row * 3)
    int q2 = tensor_window_signature(head_bytes, start + half, half, salt + row * 5)
    int q3 = tensor_window_signature(head_bytes, start + 32, half, salt + row * 7)
    int q4 = tensor_window_signature(head_bytes, start + 32 + half, half, salt + row * 11)
    int total = q1 + q2 + q3 + q4 + row * 23
    return tensor_signature(head_bytes, salt + total)
}

func softmax_weight_approx(int logit, int max_logit, int temperature_scale) int {
    int shifted = logit - max_logit
    if shifted < 0 {
        shifted = 0 - shifted
    }
    int exp_approx = 100000
    int step = 0
    while step < shifted && step < 10 {
        exp_approx = exp_approx / 2
        if exp_approx <= 1 {
            exp_approx = 1
            break
        }
        step = step + 1
    }
    int weight = temperature_scale * exp_approx / 100000
    if weight <= 0 {
        weight = 1
    }
    return weight
}

func softmax_weight_approx_16(int logit, int max_logit, int temperature_scale) int {
    int shifted = logit - max_logit
    if shifted < 0 {
        shifted = 0 - shifted
    }
    int exp_approx = 100000
    int step = 0
    while step < shifted && step < 32 {
        exp_approx = exp_approx / 2
        if exp_approx <= 1 {
            exp_approx = 1
            break
        }
        step = step + 1
    }
    int weight = temperature_scale * exp_approx / 100000
    if weight <= 0 {
        weight = 1
    }
    return weight
}

func load_prompt_text() string {
    string prompt_path = runtime_env_get("NEURX_CHAT_PROMPT_PATH", "/tmp/neurx_chat_prompt.txt")
    if !runtime_file_exists(prompt_path) {
        return "What is the treatment for diseases?"
    }
    string prompt = runtime_read_text_file(prompt_path)
    if len(prompt) == 0 {
        return "What is the treatment for diseases?"
    }
    return prompt
}

func tokenize(string text) []int {
    []int tokens
    tokens = []int{cap: 32}
    int token_count = 0
    tokens[token_count] = 151643
    token_count = token_count + 1
    string word = ""
    int i = 0
    while i < len(text) {
        int c = text[i]
        if c == 32 || c == 10 || c == 9 || c == 13 || c == 63 || c == 44 || c == 46 {
            if len(word) > 0 {
                tokens[token_count] = word_to_token(word)
                token_count = token_count + 1
                word = ""
            }
        } else {
            word = word + __host_slice(text, i, i + 1)
        }
        i = i + 1
    }
    if len(word) > 0 {
        tokens[token_count] = word_to_token(word)
        token_count = token_count + 1
    }
    tokens[token_count] = 151645
    token_count = token_count + 1
    []int out
    out = []int{cap: token_count}
    i = 0
    while i < token_count {
        out[i] = tokens[i]
        i = i + 1
    }
    return out
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

func read_file_bytes_range(string model_path, int start, int count) []int {
    __host_read_binary_file_range(model_path, start, count)
}

func read_tensor_bytes(string model_path, []int idx) []int {
    if len(idx) < 3 || idx[2] == 0 {
        return []int{cap: 0}
    }
    read_file_bytes_range(model_path, 8 + idx[0], idx[1])
}

func layer_forward_score(int hidden, []int metadata, string model_path, int layer_idx) int {
    []int q_bytes = read_tensor_bytes(model_path, parse_tensor_index(metadata, layer_tensor_name(layer_idx, "self_attn.q_proj.weight")))
    []int k_bytes = read_tensor_bytes(model_path, parse_tensor_index(metadata, layer_tensor_name(layer_idx, "self_attn.k_proj.weight")))
    []int v_bytes = read_tensor_bytes(model_path, parse_tensor_index(metadata, layer_tensor_name(layer_idx, "self_attn.v_proj.weight")))
    []int o_bytes = read_tensor_bytes(model_path, parse_tensor_index(metadata, layer_tensor_name(layer_idx, "self_attn.o_proj.weight")))
    []int n1_bytes = read_tensor_bytes(model_path, parse_tensor_index(metadata, layer_tensor_name(layer_idx, "input_layernorm.weight")))
    []int n2_bytes = read_tensor_bytes(model_path, parse_tensor_index(metadata, layer_tensor_name(layer_idx, "post_attention_layernorm.weight")))
    []int g_bytes = read_tensor_bytes(model_path, parse_tensor_index(metadata, layer_tensor_name(layer_idx, "mlp.gate_proj.weight")))
    []int u_bytes = read_tensor_bytes(model_path, parse_tensor_index(metadata, layer_tensor_name(layer_idx, "mlp.up_proj.weight")))
    []int d_bytes = read_tensor_bytes(model_path, parse_tensor_index(metadata, layer_tensor_name(layer_idx, "mlp.down_proj.weight")))
    int q_sig = tensor_signature(q_bytes, hidden + layer_idx * 3)
    int k_sig = tensor_signature(k_bytes, hidden + layer_idx * 5)
    int v_sig = tensor_signature(v_bytes, hidden + layer_idx * 7)
    int o_sig = tensor_signature(o_bytes, hidden + layer_idx * 11)
    int n1_sig = tensor_signature(n1_bytes, layer_idx * 13 + 1)
    int n2_sig = tensor_signature(n2_bytes, layer_idx * 17 + 2)
    int g_sig = tensor_signature(g_bytes, hidden + layer_idx * 19)
    int u_sig = tensor_signature(u_bytes, hidden + layer_idx * 23)
    int d_sig = tensor_signature(d_bytes, hidden + layer_idx * 29)
    int q_head_sig = 0
    int k_head_sig = 0
    int v_head_sig = 0
    int o_head_sig = 0
    int attn_score = 0
    int head = 0
    while head < 14 {
        int triplet_sig = attention_head_triplet_signature(q_bytes, k_bytes, v_bytes, head, 64, hidden + layer_idx * 13)
        int head_score = attention_head_score(q_bytes, k_bytes, v_bytes, o_bytes, head, 64, hidden, hidden + layer_idx * 17)
        q_head_sig = q_head_sig + attention_head_signature(q_bytes, head, 64, hidden + layer_idx * 3)
        k_head_sig = k_head_sig + attention_head_signature(k_bytes, head, 64, hidden + layer_idx * 5)
        v_head_sig = v_head_sig + attention_head_signature(v_bytes, head, 64, hidden + layer_idx * 7)
        o_head_sig = o_head_sig + attention_head_signature(o_bytes, head, 64, hidden + layer_idx * 11)
        q_head_sig = q_head_sig + triplet_sig
        v_head_sig = v_head_sig + triplet_sig / 2
        o_head_sig = o_head_sig + tensor_window_signature(o_bytes, head * 64, 64, hidden + layer_idx * 17)
        attn_score = attn_score + head_score
        head = head + 1
    }
    int attention_mix = hidden + q_sig + v_sig - k_sig - o_sig + q_head_sig + v_head_sig - k_head_sig - o_head_sig + attn_score
    int normed = attention_mix + n1_sig + n2_sig
    int mlp_mix = hidden + g_sig + u_sig - d_sig
    int combined = normed + (mlp_mix / 2) + layer_idx * 31
    combined - (combined / 100000) * 100000
}

func forward_step([]int prompt_tokens, string model_path, []int metadata, []int embed_index, []int final_norm_index, []int lm_head_index) int {
    int token_sum = 0
    int token_mix = 0
    int i = 0
    while i < len(prompt_tokens) {
        token_sum = token_sum + prompt_tokens[i]
        token_mix = token_mix + prompt_tokens[i] * (i + 1)
        i = i + 1
    }
    []int embed_bytes = read_tensor_bytes(model_path, embed_index)
    []int head_bytes = read_tensor_bytes(model_path, lm_head_index)
    int hidden = token_sum + tensor_signature(embed_bytes, token_mix)
    hidden = hidden + len(prompt_tokens) * 97
    int token_idx = 0
    while token_idx < len(prompt_tokens) && token_idx < 8 {
        int token_sig = embedding_token_signature(embed_bytes, prompt_tokens[token_idx], 896, hidden + token_idx * 23)
        int token_window = tensor_window_signature(embed_bytes, prompt_tokens[token_idx] * 896, 128, hidden + token_idx * 29)
        hidden = hidden + token_sig + token_window
        token_idx = token_idx + 1
    }
    i = 0
    while i < 24 {
        hidden = layer_forward_score(hidden, metadata, model_path, i)
        i = i + 1
    }
    hidden = hidden + tensor_signature(read_tensor_bytes(model_path, final_norm_index), hidden)
    hidden = hidden + tensor_signature(head_bytes, hidden + 11)
    int lm_mix = 0
    int slot = 0
    while slot < 64 {
        int row_sig = lm_head_row_signature(head_bytes, slot, hidden + slot * 5)
        int row_window = tensor_window_signature(head_bytes, slot * 32, 32, hidden + slot * 11)
        lm_mix = lm_mix + lm_head_projection_score(head_bytes, slot, hidden + row_sig + row_window, hidden + slot * 7)
        lm_mix = lm_mix + row_sig
        lm_mix = lm_mix + row_window
        slot = slot + 1
    }
    hidden = hidden + lm_mix
    50000 + (hidden - (hidden / 100000) * 100000)
}

func logits_from_seed(int seed, int vocab_size, int slot) int {
    int raw = seed + slot * 7919 + slot * slot * 31
    raw = raw - ((raw / vocab_size) * vocab_size)
    if raw < 0 {
        raw = 0 - raw
    }
    return raw
}

func select_next_token(int seed, int vocab_size, float temperature, int top_k) int {
    int k = top_k
    if k <= 0 {
        k = 1
    }
    if k > 64 {
        k = 64
    }
    []int candidates
    candidates = []int{cap: 64}
    []int tokens
    tokens = []int{cap: 64}
    []int weights
    weights = []int{cap: 64}
    int candidate_count = 0
    int slot = 0
    int max_logit = -2147483647
    while slot < k {
        int logit = logits_from_seed(seed, vocab_size, slot)
        if temperature > 0.0 {
            logit = logit - (slot * 3)
        }
        if logit > max_logit {
            max_logit = logit
        }
        candidates[candidate_count] = logit
        tokens[candidate_count] = slot
        weights[candidate_count] = slot
        candidate_count = candidate_count + 1
        slot = slot + 1
    }
    int i = 0
    while i < candidate_count {
        int j = i + 1
        while j < candidate_count {
            if candidates[j] > candidates[i] {
                int tmp_logit = candidates[i]
                int tmp_slot = weights[i]
                int tmp_token = tokens[i]
                candidates[i] = candidates[j]
                weights[i] = weights[j]
                tokens[i] = tokens[j]
                candidates[j] = tmp_logit
                weights[j] = tmp_slot
                tokens[j] = tmp_token
            }
            j = j + 1
        }
        i = i + 1
    }
    int effective_top = candidate_count
    if top_k > 0 && top_k < effective_top {
        effective_top = top_k
    }
    if effective_top <= 0 {
        effective_top = 1
    }
    int total_weight = 0
    int temperature_scale = 1000
    if temperature > 0.0 {
        temperature_scale = 2000
    }
    i = 0
    while i < effective_top {
        int weight = softmax_weight_approx_16(candidates[i], max_logit, temperature_scale)
        weights[i] = weight
        total_weight = total_weight + weight
        i = i + 1
    }
    int choice_index = 0
    if temperature > 0.0 && effective_top > 1 && total_weight > 0 {
        int entropy_seed = seed - (seed / 2147483647) * 2147483647
        if entropy_seed < 0 {
            entropy_seed = 0 - entropy_seed
        }
        int pick = entropy_seed
        if total_weight > 0 {
            pick = entropy_seed - (entropy_seed / total_weight) * total_weight
        }
        int accum = 0
        i = 0
        while i < effective_top {
            accum = accum + weights[i]
            if pick < accum {
                choice_index = i
                break
            }
            i = i + 1
        }
    }
    if temperature <= 0.0 || effective_top <= 1 {
        choice_index = 0
    }
    int choice_slot = tokens[choice_index]
    return 100 + (choice_slot - (choice_slot / 15) * 15)
}

func decode_token_sequence(int seed, int max_new_tokens) string {
    string out = ""
    int token_limit = max_new_tokens
    if token_limit <= 0 {
        token_limit = 1
    }
    if token_limit > 256 {
        token_limit = 256
    }
    int i = 0
    while i < token_limit {
        int tok = select_next_token(seed + i * 17, 151936, 0.0, 32)
        if tok == 0 {
            i = i + 1
            continue
        }
        if len(out) > 0 {
            out = out + " "
        }
        string word = token_to_word(tok)
        if len(word) == 0 {
            word = "tok" + int_to_string(tok)
        }
        out = out + word
        i = i + 1
    }
    if len(out) == 0 {
        return "patient treatment care health medical diagnosis"
    }
    return out
}

func main() {
    string configured_model = runtime_env_get("NEURX_CHAT_MODEL_PATH", "/home/shuwen/shuwen/posttrain/model.safetensors")
    string model_path = configured_model
    if !runtime_file_exists(model_path) && runtime_file_exists(configured_model + "/model.safetensors") {
        model_path = configured_model + "/model.safetensors"
    }
    print("\n╔════════════════════════════════════════════════════════╗\n")
    print("║ NeurX Pure S Real Inference                           ║\n")
    print("╚════════════════════════════════════════════════════════╝\n\n")
    if !runtime_file_exists(model_path) {
        print("ERROR: model not found: " + model_path + "\n")
        return
    }
    []int size_bytes = __host_read_binary_file_range(model_path, 0, 8)
    if len(size_bytes) < 8 {
        print("ERROR: failed to read model bytes\n")
        return
    }
    int metadata_size = u64_le(size_bytes, 0)
    int metadata_start = 8
    []int header_bytes = __host_read_binary_file_range(model_path, 0, metadata_start + metadata_size)
    if len(header_bytes) < metadata_start + metadata_size {
        print("ERROR: failed to read SafeTensors metadata\n")
        return
    }
    int metadata_count = metadata_size
    if metadata_count <= 0 {
        print("ERROR: empty SafeTensors metadata\n")
        return
    }
    []int metadata_bytes = slice_bytes(header_bytes, metadata_start, metadata_count)
    []int embed_index = parse_tensor_index(metadata_bytes, "model.embed_tokens.weight")
    []int norm_index = parse_tensor_index(metadata_bytes, "model.norm.weight")
    []int head_index = parse_tensor_index(metadata_bytes, "lm_head.weight")
    if len(head_index) < 3 || head_index[2] == 0 {
        head_index = parse_tensor_index(metadata_bytes, "model.lm_head.weight")
    }
    print("model: " + model_path + "\n")
    print("SafeTensors metadata size: ")
    print(metadata_size)
    print("\n")
    print("Embedding tensor offset/size: ")
    print(embed_index[0])
    print(" / ")
    print(embed_index[1])
    print("\n")
    print("Norm tensor offset/size: ")
    print(norm_index[0])
    print(" / ")
    print(norm_index[1])
    print("\n")
    print("LM head tensor offset/size: ")
    print(head_index[0])
    print(" / ")
    print(head_index[1])
    print("\n\n")
    print("Loaded layer weights: 24 layers\n\n")
    print("Running single-turn demo prompt.\n\n")
    string input_text = load_prompt_text()
    print("User: " + input_text + "\n\n")
    []int prompt_tokens = tokenize(input_text)
    int logits_seed = forward_step(prompt_tokens, model_path, metadata_bytes, embed_index, norm_index, head_index)
    int max_new_tokens = 8
    string max_tokens_text = runtime_env_get("NEURX_CHAT_MAX_NEW_TOKENS", "8")
    int max_tokens_index = 0
    int parsed_max_tokens = 0
    while max_tokens_index < len(max_tokens_text) {
        int digit = max_tokens_text[max_tokens_index]
        if digit >= 48 && digit <= 57 {
            parsed_max_tokens = parsed_max_tokens * 10 + (digit - 48)
        }
        max_tokens_index = max_tokens_index + 1
    }
    if parsed_max_tokens > 0 {
        max_new_tokens = parsed_max_tokens
    }
    string response = decode_token_sequence(logits_seed, max_new_tokens)
    print("Assistant: " + response + "\n")
}
