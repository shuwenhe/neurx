package neurx.inference.tokenizer.hf_bpe_tokenizer
extern "intrinsic" func __host_read_binary_file(string path) []int

struct hf_bpe_tokenizer {
    bool valid
    []string vocab_tokens
    []int vocab_ids
    int vocab_count
    []string merge_left
    []string merge_right
    int merge_count
    []string added_tokens
    []int added_ids
    int added_count
    bool byte_level
    int unknown_id
    string error_code
}

struct hf_bpe_result {
    bool ok
    []int token_ids
    string error_code
}

struct bpe_string_result {
    string value
    int next
}

struct bpe_int_result {
    int value
    int next
}

func bpe_hex(int ch) int {
    if ch >= 48 && ch <= 57 { return ch - 48 }
    if ch >= 65 && ch <= 70 { return ch - 55 }
    if ch >= 97 && ch <= 102 { return ch - 87 }
    -1
}

func bpe_utf8(int codepoint) string {
    if codepoint < 128 { return string(codepoint) }
    string output = ""
    if codepoint < 2048 {
        output = output + string(192 + codepoint / 64)
        output = output + string(128 + codepoint % 64)
        return output
    }
    output = output + string(224 + codepoint / 4096)
    output = output + string(128 + codepoint / 64 % 64)
    output = output + string(128 + codepoint % 64)
    output
}

func bpe_bytes_string([]int bytes) string {
    string output = ""
    int i = 0
    while i < len(bytes) { output = output + string(bytes[i]); i = i + 1 }
    output
}

func bpe_find(string text, string pattern, int start) int {
    int i = start
    while i + len(pattern) <= len(text) {
        int j = 0
        bool match = true
        while j < len(pattern) { if text[i + j] != pattern[j] { match = false; j = len(pattern) } else { j = j + 1 } }
        if match { return i }
        i = i + 1
    }
    -1
}

func bpe_skip_space(string text, int position) int {
    int i = position
    while i < len(text) && (text[i] == 32 || text[i] == 9 || text[i] == 10 || text[i] == 13) { i = i + 1 }
    i
}

func bpe_json_string(string text, int quote) bpe_string_result {
    if quote < 0 || quote >= len(text) || text[quote] != 34 { return bpe_string_result { value: "", next: quote } }
    string output = ""
    int i = quote + 1
    while i < len(text) && text[i] != 34 {
        if text[i] == 92 && i + 1 < len(text) {
            i = i + 1
            if text[i] == 110 { output = output + "\n" } else if text[i] == 116 { output = output + "\t" } else if text[i] == 117 && i + 4 < len(text) {
                int codepoint = 0
                int j = 1
                while j <= 4 {
                    int digit = bpe_hex(text[i + j])
                    if digit < 0 { digit = 0 }
                    codepoint = codepoint * 16 + digit
                    j = j + 1
                }
                output = output + bpe_utf8(codepoint)
                i = i + 4
            } else { output = output + string(text[i]) }
        } else { output = output + string(text[i]) }
        i = i + 1
    }
    bpe_string_result { value: output, next: i + 1 }
}

func bpe_parse_int(string text, int position) bpe_int_result {
    int i = bpe_skip_space(text, position)
    int value = 0
    while i < len(text) && text[i] >= 48 && text[i] <= 57 { value = value * 10 + text[i] - 48; i = i + 1 }
    bpe_int_result { value: value, next: i }
}

func bpe_vocab_id(hf_bpe_tokenizer tokenizer, string token) int {
    int i = 0
    while i < tokenizer.vocab_count {
        if tokenizer.vocab_tokens[i] == token { return tokenizer.vocab_ids[i] }
        i = i + 1
    }
    tokenizer.unknown_id
}

func bpe_merge_rank(hf_bpe_tokenizer tokenizer, string left, string right) int {
    int i = 0
    while i < tokenizer.merge_count {
        if tokenizer.merge_left[i] == left && tokenizer.merge_right[i] == right { return i }
        i = i + 1
    }
    -1
}

func bpe_direct_byte(int value) bool {
    if value >= 33 && value <= 126 { return true }
    if value >= 161 && value <= 172 { return true }
    if value >= 174 && value <= 255 { return true }
    false
}

func bpe_byte_symbol(int value) string {
    if bpe_direct_byte(value) { return bpe_utf8(value) }
    int codepoint = 256
    int byte = 0
    while byte < value {
        if !bpe_direct_byte(byte) { codepoint = codepoint + 1 }
        byte = byte + 1
    }
    bpe_utf8(codepoint)
}

func load_hf_bpe_tokenizer(string model_dir) hf_bpe_tokenizer {
    []int bytes = __host_read_binary_file(model_dir + "/tokenizer.json")
    if len(bytes) == 0 { return hf_bpe_tokenizer { valid: false, vocab_tokens: [], vocab_ids: [], vocab_count: 0, merge_left: [], merge_right: [], merge_count: 0, added_tokens: [], added_ids: [], added_count: 0, byte_level: false, unknown_id: 0, error_code: "tokenizer_not_found" } }
    string json = bpe_bytes_string(bytes)
    []string vocab_tokens = []string{cap: 200000}
    []int vocab_ids = []int{cap: 200000}
    int vocab_count = 0
    int vocab = bpe_find(json, "\"vocab\"", 0)
    int position = bpe_find(json, "{", vocab)
    position = position + 1
    while position > 0 && position < len(json) && json[position] != 125 {
        position = bpe_skip_space(json, position)
        if json[position] == 44 { position = position + 1 } else if json[position] == 34 {
            bpe_string_result token = bpe_json_string(json, position)
            int colon = bpe_find(json, ":", token.next)
            bpe_int_result id = bpe_parse_int(json, colon + 1)
            vocab_tokens[vocab_count] = token.value
            vocab_ids[vocab_count] = id.value
            vocab_count = vocab_count + 1
            position = id.next
        } else { position = position + 1 }
    }
    []string merge_left = []string{cap: 200000}
    []string merge_right = []string{cap: 200000}
    int merge_count = 0
    int merges = bpe_find(json, "\"merges\"", position)
    position = bpe_find(json, "[", merges) + 1
    while position > 0 && position < len(json) && json[position] != 93 {
        position = bpe_skip_space(json, position)
        if json[position] == 44 { position = position + 1 } else if json[position] == 34 {
            bpe_string_result merge = bpe_json_string(json, position)
            int space = bpe_find(merge.value, " ", 0)
            if space > 0 {
                string left = ""
                string right = ""
                int i = 0
                while i < space { left = left + string(merge.value[i]); i = i + 1 }
                i = space + 1
                while i < len(merge.value) { right = right + string(merge.value[i]); i = i + 1 }
                merge_left[merge_count] = left
                merge_right[merge_count] = right
                merge_count = merge_count + 1
            }
            position = merge.next
        } else { position = position + 1 }
    }
    []string added_tokens = []string{cap: 1024}
    []int added_ids = []int{cap: 1024}
    int added_count = 0
    int added = bpe_find(json, "\"added_tokens\"", 0)
    position = bpe_find(json, "[", added) + 1
    while position > 0 && position < len(json) && json[position] != 93 {
        int object = bpe_find(json, "{", position)
        if object < 0 || object > bpe_find(json, "]", position) { position = len(json) } else {
            int object_end = bpe_find(json, "}", object)
            int content_key = bpe_find(json, "\"content\"", object)
            int content_quote = bpe_find(json, "\"", bpe_find(json, ":", content_key) + 1)
            bpe_string_result content = bpe_json_string(json, content_quote)
            int id_key = bpe_find(json, "\"id\"", object)
            bpe_int_result id = bpe_parse_int(json, bpe_find(json, ":", id_key) + 1)
            if content_key < object_end && id_key < object_end { added_tokens[added_count] = content.value; added_ids[added_count] = id.value; added_count = added_count + 1 }
            position = object_end + 1
        }
    }
    hf_bpe_tokenizer tokenizer = hf_bpe_tokenizer { valid: vocab_count > 0, vocab_tokens: vocab_tokens, vocab_ids: vocab_ids, vocab_count: vocab_count, merge_left: merge_left, merge_right: merge_right, merge_count: merge_count, added_tokens: added_tokens, added_ids: added_ids, added_count: added_count, byte_level: bpe_find(json, "\"ByteLevel\"", 0) >= 0, unknown_id: 0, error_code: "" }
    tokenizer.unknown_id = bpe_vocab_id(tokenizer, "<unk>")
    tokenizer
}

func hf_bpe_encode(hf_bpe_tokenizer tokenizer, string text, int maximum_tokens) hf_bpe_result {
    if !tokenizer.valid || text == "" || maximum_tokens <= 0 { return hf_bpe_result { ok: false, token_ids: [], error_code: "invalid_bpe_input" } }
    int special = 0
    while special < tokenizer.added_count {
        if text == tokenizer.added_tokens[special] {
            []int special_ids = []int{cap: 1}
            special_ids[0] = tokenizer.added_ids[special]
            return hf_bpe_result { ok: true, token_ids: special_ids, error_code: "" }
        }
        special = special + 1
    }
    []string symbols = []string{cap: len(text) + 1}
    int count = len(text)
    int i = 0
    while i < count {
        if tokenizer.byte_level { symbols[i] = bpe_byte_symbol(int(text[i])) } else { symbols[i] = string(text[i]) }
        i = i + 1
    }
    while count > 1 {
        int best = -1
        int best_rank = 2147483647
        i = 0
        while i + 1 < count {
            int rank = bpe_merge_rank(tokenizer, symbols[i], symbols[i + 1])
            if rank >= 0 && rank < best_rank { best = i; best_rank = rank }
            i = i + 1
        }
        if best < 0 { break }
        symbols[best] = symbols[best] + symbols[best + 1]
        i = best + 1
        while i + 1 < count { symbols[i] = symbols[i + 1]; i = i + 1 }
        count = count - 1
    }
    int output_count = count
    if output_count > maximum_tokens { output_count = maximum_tokens }
    []int ids = []int{cap: output_count}
    i = 0
    while i < output_count { ids[i] = bpe_vocab_id(tokenizer, symbols[i]); i = i + 1 }
    hf_bpe_result { ok: true, token_ids: ids, error_code: "" }
}
