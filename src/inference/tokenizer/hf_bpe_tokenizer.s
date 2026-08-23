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
    bool bert_pre_tokenizer
    bool metaspace_pre_tokenizer
    bool normalizer_lowercase
    bool normalizer_strip
    string metaspace_replacement
    int unknown_id
    string error_code
}

struct hf_bpe_result {
    bool ok
    []int token_ids
    string error_code
}

struct hf_bpe_decode_result {
    bool ok
    string text
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

func bpe_json_true(string json, string key, int start) bool {
    int position = bpe_find(json, key, start)
    if position < 0 { return false }
    int colon = bpe_find(json, ":", position)
    int value = bpe_skip_space(json, colon + 1)
    value + 4 <= len(json) && json[value] == 116 && json[value + 1] == 114 && json[value + 2] == 117 && json[value + 3] == 101
}

func bpe_utf8_width(int byte) int {
    if byte < 128 { return 1 }
    if byte < 224 { return 2 }
    if byte < 240 { return 3 }
    4
}

func bpe_substring(string text, int start, int end) string {
    string output = ""
    int i = start
    while i < end { output = output + string(text[i]); i = i + 1 }
    output
}

func bpe_is_space(int byte) bool { byte == 32 || byte == 9 || byte == 10 || byte == 13 }

func bpe_is_bert_punctuation(int byte) bool {
    if byte >= 33 && byte <= 47 { return true }
    if byte >= 58 && byte <= 64 { return true }
    if byte >= 91 && byte <= 96 { return true }
    byte >= 123 && byte <= 126
}

func bpe_normalize(hf_bpe_tokenizer tokenizer, string text) string {
    int start = 0
    int end = len(text)
    if tokenizer.normalizer_strip {
        while start < end && bpe_is_space(text[start]) { start = start + 1 }
        while end > start && bpe_is_space(text[end - 1]) { end = end - 1 }
    }
    string output = ""
    int i = start
    while i < end {
        int byte = text[i]
        if tokenizer.normalizer_lowercase && byte >= 65 && byte <= 90 { byte = byte + 32 }
        output = output + string(byte)
        i = i + 1
    }
    output
}

func bpe_added_id(hf_bpe_tokenizer tokenizer, string token) int {
    int i = 0
    while i < tokenizer.added_count {
        if tokenizer.added_tokens[i] == token { return tokenizer.added_ids[i] }
        i = i + 1
    }
    -1
}

func bpe_id_token(hf_bpe_tokenizer tokenizer, int id) string {
    int i = 0
    while i < tokenizer.added_count {
        if tokenizer.added_ids[i] == id { return tokenizer.added_tokens[i] }
        i = i + 1
    }
    i = 0
    while i < tokenizer.vocab_count {
        if tokenizer.vocab_ids[i] == id { return tokenizer.vocab_tokens[i] }
        i = i + 1
    }
    ""
}

func load_hf_bpe_tokenizer(string model_dir) hf_bpe_tokenizer {
    []int bytes = __host_read_binary_file(model_dir + "/tokenizer.json")
    if len(bytes) == 0 { return hf_bpe_tokenizer { valid: false, vocab_tokens: [], vocab_ids: [], vocab_count: 0, merge_left: [], merge_right: [], merge_count: 0, added_tokens: [], added_ids: [], added_count: 0, byte_level: false, bert_pre_tokenizer: false, metaspace_pre_tokenizer: false, normalizer_lowercase: false, normalizer_strip: false, metaspace_replacement: "", unknown_id: 0, error_code: "tokenizer_not_found" } }
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
    string metaspace_replacement = bpe_utf8(9601)
    int replacement_key = bpe_find(json, "\"replacement\"", 0)
    if replacement_key >= 0 {
        int replacement_quote = bpe_find(json, "\"", bpe_find(json, ":", replacement_key) + 1)
        bpe_string_result replacement = bpe_json_string(json, replacement_quote)
        if replacement.value != "" { metaspace_replacement = replacement.value }
    }
    hf_bpe_tokenizer tokenizer = hf_bpe_tokenizer { valid: vocab_count > 0, vocab_tokens: vocab_tokens, vocab_ids: vocab_ids, vocab_count: vocab_count, merge_left: merge_left, merge_right: merge_right, merge_count: merge_count, added_tokens: added_tokens, added_ids: added_ids, added_count: added_count, byte_level: bpe_find(json, "\"ByteLevel\"", 0) >= 0, bert_pre_tokenizer: bpe_find(json, "\"BertPreTokenizer\"", 0) >= 0, metaspace_pre_tokenizer: bpe_find(json, "\"Metaspace\"", 0) >= 0, normalizer_lowercase: bpe_find(json, "\"Lowercase\"", 0) >= 0 || bpe_json_true(json, "\"lowercase\"", 0), normalizer_strip: bpe_find(json, "\"Strip\"", 0) >= 0, metaspace_replacement: metaspace_replacement, unknown_id: 0, error_code: "" }
    tokenizer.unknown_id = bpe_vocab_id(tokenizer, "<unk>")
    tokenizer
}

func bpe_encode_piece(hf_bpe_tokenizer tokenizer, string text, int maximum_tokens) hf_bpe_result {
    if text == "" { return hf_bpe_result { ok: true, token_ids: [], error_code: "" } }
    []string symbols = []string{cap: len(text) + 4}
    int count = 0
    int i = 0
    while i < len(text) {
        if tokenizer.byte_level {
            symbols[count] = bpe_byte_symbol(int(text[i]))
            i = i + 1
        } else {
            int width = bpe_utf8_width(text[i])
            if i + width > len(text) { width = 1 }
            symbols[count] = bpe_substring(text, i, i + width)
            i = i + width
        }
        count = count + 1
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

func bpe_encode_normal(hf_bpe_tokenizer tokenizer, string source, int maximum_tokens) hf_bpe_result {
    string text = bpe_normalize(tokenizer, source)
    if tokenizer.metaspace_pre_tokenizer {
        string replaced = tokenizer.metaspace_replacement
        int i = 0
        while i < len(text) {
            if bpe_is_space(text[i]) {
                replaced = replaced + tokenizer.metaspace_replacement
                while i < len(text) && bpe_is_space(text[i]) { i = i + 1 }
            } else { replaced = replaced + string(text[i]); i = i + 1 }
        }
        return bpe_encode_piece(tokenizer, replaced, maximum_tokens)
    }
    if tokenizer.bert_pre_tokenizer {
        int start = 0
        int i = 0
        []int ids = []int{cap: maximum_tokens}
        int output_count = 0
        while i <= len(text) && output_count < maximum_tokens {
            bool boundary = i == len(text)
            if i < len(text) && (bpe_is_space(text[i]) || bpe_is_bert_punctuation(text[i])) { boundary = true }
            if boundary && start < i {
                hf_bpe_result piece = bpe_encode_piece(tokenizer, bpe_substring(text, start, i), maximum_tokens - output_count)
                int p = 0
                while p < len(piece.token_ids) { ids[output_count] = piece.token_ids[p]; output_count = output_count + 1; p = p + 1 }
            }
            if i < len(text) && bpe_is_bert_punctuation(text[i]) {
                hf_bpe_result punctuation = bpe_encode_piece(tokenizer, string(text[i]), maximum_tokens - output_count)
                int p = 0
                while p < len(punctuation.token_ids) { ids[output_count] = punctuation.token_ids[p]; output_count = output_count + 1; p = p + 1 }
            }
            if boundary { start = i + 1 }
            i = i + 1
        }
        []int result_ids = []int{cap: output_count}
        i = 0
        while i < output_count { result_ids[i] = ids[i]; i = i + 1 }
        return hf_bpe_result { ok: true, token_ids: result_ids, error_code: "" }
    }
    bpe_encode_piece(tokenizer, text, maximum_tokens)
}

func hf_bpe_encode(hf_bpe_tokenizer tokenizer, string text, int maximum_tokens) hf_bpe_result {
    if !tokenizer.valid || text == "" || maximum_tokens <= 0 { return hf_bpe_result { ok: false, token_ids: [], error_code: "invalid_bpe_input" } }
    []int ids = []int{cap: maximum_tokens}
    int output_count = 0
    int position = 0
    int plain_start = 0
    while position < len(text) && output_count < maximum_tokens {
        int best = -1
        int best_length = 0
        int special = 0
        while special < tokenizer.added_count {
            string token = tokenizer.added_tokens[special]
            if len(token) > best_length && position + len(token) <= len(text) && bpe_substring(text, position, position + len(token)) == token { best = special; best_length = len(token) }
            special = special + 1
        }
        if best >= 0 {
            hf_bpe_result plain = bpe_encode_normal(tokenizer, bpe_substring(text, plain_start, position), maximum_tokens - output_count)
            int p = 0
            while p < len(plain.token_ids) { ids[output_count] = plain.token_ids[p]; output_count = output_count + 1; p = p + 1 }
            if output_count < maximum_tokens { ids[output_count] = tokenizer.added_ids[best]; output_count = output_count + 1 }
            position = position + best_length
            plain_start = position
        } else { position = position + 1 }
    }
    if output_count < maximum_tokens {
        hf_bpe_result trailing = bpe_encode_normal(tokenizer, bpe_substring(text, plain_start, len(text)), maximum_tokens - output_count)
        int p = 0
        while p < len(trailing.token_ids) { ids[output_count] = trailing.token_ids[p]; output_count = output_count + 1; p = p + 1 }
    }
    []int result_ids = []int{cap: output_count}
    int i = 0
    while i < output_count { result_ids[i] = ids[i]; i = i + 1 }
    hf_bpe_result { ok: true, token_ids: result_ids, error_code: "" }
}

func bpe_decode_byte_symbol(string symbol) int {
    int byte = 0
    while byte < 256 {
        if bpe_byte_symbol(byte) == symbol { return byte }
        byte = byte + 1
    }
    -1
}

func hf_bpe_decode(hf_bpe_tokenizer tokenizer, []int token_ids) hf_bpe_decode_result {
    if !tokenizer.valid { return hf_bpe_decode_result { ok: false, text: "", error_code: "invalid_bpe_tokenizer" } }
    string output = ""
    int i = 0
    while i < len(token_ids) {
        string token = bpe_id_token(tokenizer, token_ids[i])
        if token == "" { return hf_bpe_decode_result { ok: false, text: output, error_code: "unknown_token_id" } }
        if bpe_added_id(tokenizer, token) >= 0 { output = output + token } else if tokenizer.byte_level {
            int position = 0
            while position < len(token) {
                int width = bpe_utf8_width(token[position])
                string symbol = bpe_substring(token, position, position + width)
                int byte = bpe_decode_byte_symbol(symbol)
                if byte < 0 { return hf_bpe_decode_result { ok: false, text: output, error_code: "invalid_bytelevel_symbol" } }
                output = output + string(byte)
                position = position + width
            }
        } else if tokenizer.metaspace_pre_tokenizer {
            int position = 0
            while position < len(token) {
                if position + len(tokenizer.metaspace_replacement) <= len(token) && bpe_substring(token, position, position + len(tokenizer.metaspace_replacement)) == tokenizer.metaspace_replacement { output = output + " "; position = position + len(tokenizer.metaspace_replacement) } else { output = output + string(token[position]); position = position + 1 }
            }
        } else { output = output + token }
        i = i + 1
    }
    if tokenizer.metaspace_pre_tokenizer && len(output) > 0 && output[0] == 32 { output = bpe_substring(output, 1, len(output)) }
    hf_bpe_decode_result { ok: true, text: output, error_code: "" }
}
