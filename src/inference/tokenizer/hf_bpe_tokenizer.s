package neurx.inference.tokenizer.hf_bpe_tokenizer
use neurx.core.unicode.normalization.{unicode_database, empty_unicode_database, load_unicode_database, unicode_nfc, unicode_nfkc}
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
    bool bert_clean_text
    bool bert_strip_accents
    bool byte_level_trim_offsets
    string unicode_normalizer
    unicode_database unicode_db
    string metaspace_replacement
    int bos_id
    int eos_id
    int pad_id
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

struct hf_bpe_offset_result {
    bool ok
    []int token_ids
    []int start_offsets
    []int end_offsets
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
    if codepoint >= 65536 {
        output = output + string(240 + codepoint / 262144)
        output = output + string(128 + codepoint / 4096 % 64)
        output = output + string(128 + codepoint / 64 % 64)
        return output + string(128 + codepoint % 64)
    }
    output = output + string(224 + codepoint / 4096)
    output = output + string(128 + codepoint / 64 % 64)
    output = output + string(128 + codepoint % 64)
    output
}

func bpe_bytes_string([]int bytes) string {
    string output = ""
    int i = 0
    for i < len(bytes) { output = output + string(bytes[i]); i = i + 1 }
    output
}

func bpe_find(string text, string pattern, int start) int {
    int i = start
    for i + len(pattern) <= len(text) {
        int j = 0
        bool match = true
        for j < len(pattern) { if text[i + j] != pattern[j] { match = false; j = len(pattern) } else { j = j + 1 } }
        if match { return i }
        i = i + 1
    }
    -1
}

func bpe_skip_space(string text, int position) int {
    int i = position
    for i < len(text) && (text[i] == 32 || text[i] == 9 || text[i] == 10 || text[i] == 13) { i = i + 1 }
    i
}

func bpe_json_string(string text, int quote) bpe_string_result {
    if quote < 0 || quote >= len(text) || text[quote] != 34 { return bpe_string_result { value: "", next: quote } }
    string output = ""
    int i = quote + 1
    for i < len(text) && text[i] != 34 {
        if text[i] == 92 && i + 1 < len(text) {
            i = i + 1
            if text[i] == 110 { output = output + "\n" } else if text[i] == 116 { output = output + "\t" } else if text[i] == 117 && i + 4 < len(text) {
                int codepoint = 0
                int j = 1
                for j <= 4 {
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
    for i < len(text) && text[i] >= 48 && text[i] <= 57 { value = value * 10 + text[i] - 48; i = i + 1 }
    bpe_int_result { value: value, next: i }
}

func bpe_vocab_id(hf_bpe_tokenizer tokenizer, string token) int {
    int i = 0
    for i < tokenizer.vocab_count {
        if tokenizer.vocab_tokens[i] == token { return tokenizer.vocab_ids[i] }
        i = i + 1
    }
    tokenizer.unknown_id
}

func bpe_merge_rank(hf_bpe_tokenizer tokenizer, string left, string right) int {
    int i = 0
    for i < tokenizer.merge_count {
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
    for byte < value {
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
    for i < end { output = output + string(text[i]); i = i + 1 }
    output
}

func bpe_is_space(int byte) bool { byte == 32 || byte == 9 || byte == 10 || byte == 13 }

func bpe_is_bert_punctuation(int byte) bool {
    if byte >= 33 && byte <= 47 { return true }
    if byte >= 58 && byte <= 64 { return true }
    if byte >= 91 && byte <= 96 { return true }
    byte >= 123 && byte <= 126
}

func bpe_latin_accent(int lead, int tail) int {
    if lead != 195 { return -1 }
    if tail >= 128 && tail <= 133 { return 65 }
    if tail == 135 { return 67 }
    if tail >= 136 && tail <= 139 { return 69 }
    if tail >= 140 && tail <= 143 { return 73 }
    if tail == 145 { return 78 }
    if tail >= 146 && tail <= 150 { return 79 }
    if tail >= 153 && tail <= 156 { return 85 }
    if tail == 157 { return 89 }
    if tail >= 160 && tail <= 165 { return 97 }
    if tail == 167 { return 99 }
    if tail >= 168 && tail <= 171 { return 101 }
    if tail >= 172 && tail <= 175 { return 105 }
    if tail == 177 { return 110 }
    if tail >= 178 && tail <= 182 { return 111 }
    if tail >= 185 && tail <= 188 { return 117 }
    if tail == 189 || tail == 191 { return 121 }
    -1
}

func bpe_normalize(hf_bpe_tokenizer tokenizer, string text) string {
    string normalized = text
    if tokenizer.unicode_normalizer != "" {
        if tokenizer.unicode_normalizer == "NFKC" { normalized = unicode_nfkc(tokenizer.unicode_db, normalized) } else { normalized = unicode_nfc(tokenizer.unicode_db, normalized) }
    }
    int start = 0
    int end = len(normalized)
    if tokenizer.normalizer_strip {
        for start < end && bpe_is_space(normalized[start]) { start = start + 1 }
        for end > start && bpe_is_space(normalized[end - 1]) { end = end - 1 }
    }
    string output = ""
    int i = start
    for i < end {
        int byte = normalized[i]
        if tokenizer.bert_strip_accents && i + 1 < end {
            int accent = bpe_latin_accent(byte, normalized[i + 1])
            if accent >= 0 { byte = accent; i = i + 1 }
        }
        if tokenizer.bert_clean_text && (byte == 0 || byte == 127 || byte < 32) { byte = 32 }
        if tokenizer.normalizer_lowercase && byte >= 65 && byte <= 90 { byte = byte + 32 }
        output = output + string(byte)
        i = i + 1
    }
    output
}

func bpe_added_id(hf_bpe_tokenizer tokenizer, string token) int {
    int i = 0
    for i < tokenizer.added_count {
        if tokenizer.added_tokens[i] == token { return tokenizer.added_ids[i] }
        i = i + 1
    }
    -1
}

func bpe_first_token_id(hf_bpe_tokenizer tokenizer, string first, string second, string third) int {
    int id = bpe_added_id(tokenizer, first)
    if id < 0 { id = bpe_vocab_id(tokenizer, first) }
    if id == tokenizer.unknown_id && first != "<unk>" { id = -1 }
    if id < 0 {
        id = bpe_added_id(tokenizer, second)
        if id < 0 { id = bpe_vocab_id(tokenizer, second) }
        if id == tokenizer.unknown_id && second != "<unk>" { id = -1 }
    }
    if id < 0 {
        id = bpe_added_id(tokenizer, third)
        if id < 0 { id = bpe_vocab_id(tokenizer, third) }
        if id == tokenizer.unknown_id && third != "<unk>" { id = -1 }
    }
    id
}

func bpe_id_token(hf_bpe_tokenizer tokenizer, int id) string {
    int i = 0
    for i < tokenizer.added_count {
        if tokenizer.added_ids[i] == id { return tokenizer.added_tokens[i] }
        i = i + 1
    }
    i = 0
    for i < tokenizer.vocab_count {
        if tokenizer.vocab_ids[i] == id { return tokenizer.vocab_tokens[i] }
        i = i + 1
    }
    ""
}

func load_hf_bpe_tokenizer(string model_dir) hf_bpe_tokenizer {
    []int bytes = __host_read_binary_file(model_dir + "/tokenizer.json")
    if len(bytes) == 0 { return hf_bpe_tokenizer { valid: false, vocab_tokens: [], vocab_ids: [], vocab_count: 0, merge_left: [], merge_right: [], merge_count: 0, added_tokens: [], added_ids: [], added_count: 0, byte_level: false, bert_pre_tokenizer: false, metaspace_pre_tokenizer: false, normalizer_lowercase: false, normalizer_strip: false, bert_clean_text: false, bert_strip_accents: false, byte_level_trim_offsets: false, unicode_normalizer: "", unicode_db: empty_unicode_database(), metaspace_replacement: "", bos_id: -1, eos_id: -1, pad_id: -1, unknown_id: 0, error_code: "tokenizer_not_found" } }
    string json = bpe_bytes_string(bytes)
    []string vocab_tokens = make([]string, 200000)
    []int vocab_ids = make([]int, 200000)
    int vocab_count = 0
    int vocab = bpe_find(json, "\"vocab\"", 0)
    int position = bpe_find(json, "{", vocab)
    position = position + 1
    for position > 0 && position < len(json) && json[position] != 125 {
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
    []string merge_left = make([]string, 200000)
    []string merge_right = make([]string, 200000)
    int merge_count = 0
    int merges = bpe_find(json, "\"merges\"", position)
    position = bpe_find(json, "[", merges) + 1
    for position > 0 && position < len(json) && json[position] != 93 {
        position = bpe_skip_space(json, position)
        if json[position] == 44 { position = position + 1 } else if json[position] == 34 {
            bpe_string_result merge = bpe_json_string(json, position)
            int space = bpe_find(merge.value, " ", 0)
            if space > 0 {
                string left = ""
                string right = ""
                int i = 0
                for i < space { left = left + string(merge.value[i]); i = i + 1 }
                i = space + 1
                for i < len(merge.value) { right = right + string(merge.value[i]); i = i + 1 }
                merge_left[merge_count] = left
                merge_right[merge_count] = right
                merge_count = merge_count + 1
            }
            position = merge.next
        } else { position = position + 1 }
    }
    []string added_tokens = make([]string, 1024)
    []int added_ids = make([]int, 1024)
    int added_count = 0
    int added = bpe_find(json, "\"added_tokens\"", 0)
    position = bpe_find(json, "[", added) + 1
    for position > 0 && position < len(json) && json[position] != 93 {
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
    string unicode_normalizer = ""
    if bpe_find(json, "\"NFKC\"", 0) >= 0 { unicode_normalizer = "NFKC" } else if bpe_find(json, "\"NFC\"", 0) >= 0 { unicode_normalizer = "NFC" }
    unicode_database unicode_db = empty_unicode_database()
    if unicode_normalizer != "" { unicode_db = load_unicode_database("config/unicode") }
    hf_bpe_tokenizer tokenizer = hf_bpe_tokenizer { valid: vocab_count > 0 && (unicode_normalizer == "" || unicode_db.valid), vocab_tokens: vocab_tokens, vocab_ids: vocab_ids, vocab_count: vocab_count, merge_left: merge_left, merge_right: merge_right, merge_count: merge_count, added_tokens: added_tokens, added_ids: added_ids, added_count: added_count, byte_level: bpe_find(json, "\"ByteLevel\"", 0) >= 0, bert_pre_tokenizer: bpe_find(json, "\"BertPreTokenizer\"", 0) >= 0, metaspace_pre_tokenizer: bpe_find(json, "\"Metaspace\"", 0) >= 0, normalizer_lowercase: bpe_find(json, "\"Lowercase\"", 0) >= 0 || bpe_json_true(json, "\"lowercase\"", 0) || bpe_json_true(json, "\"lower_case\"", 0), normalizer_strip: bpe_find(json, "\"Strip\"", 0) >= 0, bert_clean_text: bpe_json_true(json, "\"clean_text\"", 0), bert_strip_accents: bpe_json_true(json, "\"strip_accents\"", 0), byte_level_trim_offsets: bpe_json_true(json, "\"trim_offsets\"", 0), unicode_normalizer: unicode_normalizer, unicode_db: unicode_db, metaspace_replacement: metaspace_replacement, bos_id: -1, eos_id: -1, pad_id: -1, unknown_id: 0, error_code: "" }
    tokenizer.unknown_id = bpe_vocab_id(tokenizer, "<unk>")
    tokenizer.bos_id = bpe_first_token_id(tokenizer, "<s>", "[CLS]", "<|begin_of_text|>")
    tokenizer.eos_id = bpe_first_token_id(tokenizer, "</s>", "[SEP]", "<|endoftext|>")
    if tokenizer.eos_id < 0 { tokenizer.eos_id = bpe_first_token_id(tokenizer, "<|eot_id|>", "<|end_of_text|>", "<eos>") }
    tokenizer.pad_id = bpe_first_token_id(tokenizer, "<pad>", "[PAD]", "<|pad|>")
    tokenizer
}

func bpe_encode_piece(hf_bpe_tokenizer tokenizer, string text, int maximum_tokens) hf_bpe_result {
    if text == "" { return hf_bpe_result { ok: true, token_ids: [], error_code: "" } }
    []string symbols = make([]string, len(text) + 4)
    int count = 0
    int i = 0
    for i < len(text) {
        if tokenizer.byte_level {
            symbols[count] = bpe_byte_symbol(text[i])
            i = i + 1
        } else {
            int width = bpe_utf8_width(text[i])
            if i + width > len(text) { width = 1 }
            symbols[count] = bpe_substring(text, i, i + width)
            i = i + width
        }
        count = count + 1
    }
    for count > 1 {
        int best = -1
        int best_rank = 2147483647
        i = 0
        for i + 1 < count {
            int rank = bpe_merge_rank(tokenizer, symbols[i], symbols[i + 1])
            if rank >= 0 && rank < best_rank { best = i; best_rank = rank }
            i = i + 1
        }
        if best < 0 { break }
        symbols[best] = symbols[best] + symbols[best + 1]
        i = best + 1
        for i + 1 < count { symbols[i] = symbols[i + 1]; i = i + 1 }
        count = count - 1
    }
    int output_count = count
    if output_count > maximum_tokens { output_count = maximum_tokens }
    []int ids = make([]int, output_count)
    i = 0
    for i < output_count { ids[i] = bpe_vocab_id(tokenizer, symbols[i]); i = i + 1 }
    hf_bpe_result { ok: true, token_ids: ids, error_code: "" }
}

func bpe_encode_normal(hf_bpe_tokenizer tokenizer, string source, int maximum_tokens) hf_bpe_result {
    string text = bpe_normalize(tokenizer, source)
    if tokenizer.metaspace_pre_tokenizer {
        string replaced = tokenizer.metaspace_replacement
        int i = 0
        for i < len(text) {
            if bpe_is_space(text[i]) {
                replaced = replaced + tokenizer.metaspace_replacement
                for i < len(text) && bpe_is_space(text[i]) { i = i + 1 }
            } else { replaced = replaced + string(text[i]); i = i + 1 }
        }
        return bpe_encode_piece(tokenizer, replaced, maximum_tokens)
    }
    if tokenizer.bert_pre_tokenizer {
        int start = 0
        int i = 0
        []int ids = make([]int, maximum_tokens)
        int output_count = 0
        for i <= len(text) && output_count < maximum_tokens {
            bool boundary = i == len(text)
            if i < len(text) && (bpe_is_space(text[i]) || bpe_is_bert_punctuation(text[i])) { boundary = true }
            if boundary && start < i {
                hf_bpe_result piece = bpe_encode_piece(tokenizer, bpe_substring(text, start, i), maximum_tokens - output_count)
                int p = 0
                for p < len(piece.token_ids) { ids[output_count] = piece.token_ids[p]; output_count = output_count + 1; p = p + 1 }
            }
            if i < len(text) && bpe_is_bert_punctuation(text[i]) {
                hf_bpe_result punctuation = bpe_encode_piece(tokenizer, string(text[i]), maximum_tokens - output_count)
                int p = 0
                for p < len(punctuation.token_ids) { ids[output_count] = punctuation.token_ids[p]; output_count = output_count + 1; p = p + 1 }
            }
            if boundary { start = i + 1 }
            i = i + 1
        }
        []int result_ids = make([]int, output_count)
        i = 0
        for i < output_count { result_ids[i] = ids[i]; i = i + 1 }
        return hf_bpe_result { ok: true, token_ids: result_ids, error_code: "" }
    }
    bpe_encode_piece(tokenizer, text, maximum_tokens)
}

func hf_bpe_encode(hf_bpe_tokenizer tokenizer, string text, int maximum_tokens) hf_bpe_result {
    if !tokenizer.valid || text == "" || maximum_tokens <= 0 { return hf_bpe_result { ok: false, token_ids: [], error_code: "invalid_bpe_input" } }
    []int ids = make([]int, maximum_tokens)
    int output_count = 0
    int position = 0
    int plain_start = 0
    for position < len(text) && output_count < maximum_tokens {
        int best = -1
        int best_length = 0
        int special = 0
        for special < tokenizer.added_count {
            string token = tokenizer.added_tokens[special]
            if len(token) > best_length && position + len(token) <= len(text) && bpe_substring(text, position, position + len(token)) == token { best = special; best_length = len(token) }
            special = special + 1
        }
        if best >= 0 {
            hf_bpe_result plain = bpe_encode_normal(tokenizer, bpe_substring(text, plain_start, position), maximum_tokens - output_count)
            int p = 0
            for p < len(plain.token_ids) { ids[output_count] = plain.token_ids[p]; output_count = output_count + 1; p = p + 1 }
            if output_count < maximum_tokens { ids[output_count] = tokenizer.added_ids[best]; output_count = output_count + 1 }
            position = position + best_length
            plain_start = position
        } else { position = position + 1 }
    }
    if output_count < maximum_tokens {
        hf_bpe_result trailing = bpe_encode_normal(tokenizer, bpe_substring(text, plain_start, len(text)), maximum_tokens - output_count)
        int p = 0
        for p < len(trailing.token_ids) { ids[output_count] = trailing.token_ids[p]; output_count = output_count + 1; p = p + 1 }
    }
    []int result_ids = make([]int, output_count)
    int i = 0
    for i < output_count { result_ids[i] = ids[i]; i = i + 1 }
    hf_bpe_result { ok: true, token_ids: result_ids, error_code: "" }
}

func hf_bpe_encode_bytelevel_offsets(hf_bpe_tokenizer tokenizer, string text, int maximum_tokens) hf_bpe_offset_result {
    if !tokenizer.valid || !tokenizer.byte_level || text == "" || maximum_tokens <= 0 { return hf_bpe_offset_result { ok: false, token_ids: [], start_offsets: [], end_offsets: [], error_code: "invalid_bytelevel_offset_input" } }
    int exact_special = 0
    for exact_special < tokenizer.added_count {
        if text == tokenizer.added_tokens[exact_special] {
            []int special_ids = make([]int, 1)
            []int special_starts = make([]int, 1)
            []int special_ends = make([]int, 1)
            special_ids[0] = tokenizer.added_ids[exact_special]
            special_starts[0] = 0
            special_ends[0] = len(text)
            return hf_bpe_offset_result { ok: true, token_ids: special_ids, start_offsets: special_starts, end_offsets: special_ends, error_code: "" }
        }
        exact_special = exact_special + 1
    }
    string normalized = bpe_normalize(tokenizer, text)
    if normalized != text { return hf_bpe_offset_result { ok: false, token_ids: [], start_offsets: [], end_offsets: [], error_code: "normalized_offset_mapping_required" } }
    []string symbols = make([]string, len(text) + 1)
    []int starts = make([]int, len(text) + 1)
    []int ends = make([]int, len(text) + 1)
    int count = len(text)
    int i = 0
    for i < count { symbols[i] = bpe_byte_symbol(text[i]); starts[i] = i; ends[i] = i + 1; i = i + 1 }
    for count > 1 {
        int best = -1
        int best_rank = 2147483647
        i = 0
        for i + 1 < count {
            int rank = bpe_merge_rank(tokenizer, symbols[i], symbols[i + 1])
            if rank >= 0 && rank < best_rank { best = i; best_rank = rank }
            i = i + 1
        }
        if best < 0 { break }
        symbols[best] = symbols[best] + symbols[best + 1]
        ends[best] = ends[best + 1]
        i = best + 1
        for i + 1 < count { symbols[i] = symbols[i + 1]; starts[i] = starts[i + 1]; ends[i] = ends[i + 1]; i = i + 1 }
        count = count - 1
    }
    int output_count = count
    if output_count > maximum_tokens { output_count = maximum_tokens }
    []int ids = make([]int, output_count)
    []int output_starts = make([]int, output_count)
    []int output_ends = make([]int, output_count)
    i = 0
    for i < output_count {
        ids[i] = bpe_vocab_id(tokenizer, symbols[i])
        int start = starts[i]
        int end = ends[i]
        if tokenizer.byte_level_trim_offsets {
            for start < end && bpe_is_space(text[start]) { start = start + 1 }
            for end > start && bpe_is_space(text[end - 1]) { end = end - 1 }
        }
        output_starts[i] = start
        output_ends[i] = end
        i = i + 1
    }
    hf_bpe_offset_result { ok: true, token_ids: ids, start_offsets: output_starts, end_offsets: output_ends, error_code: "" }
}

func bpe_decode_byte_symbol(string symbol) int {
    int byte = 0
    for byte < 256 {
        if bpe_byte_symbol(byte) == symbol { return byte }
        byte = byte + 1
    }
    -1
}

func hf_bpe_decode(hf_bpe_tokenizer tokenizer, []int token_ids) hf_bpe_decode_result {
    if !tokenizer.valid { return hf_bpe_decode_result { ok: false, text: "", error_code: "invalid_bpe_tokenizer" } }
    string output = ""
    int i = 0
    for i < len(token_ids) {
        string token = bpe_id_token(tokenizer, token_ids[i])
        if token == "" { return hf_bpe_decode_result { ok: false, text: output, error_code: "unknown_token_id" } }
        if bpe_added_id(tokenizer, token) >= 0 { output = output + token } else if tokenizer.byte_level {
            int position = 0
            for position < len(token) {
                int width = bpe_utf8_width(token[position])
                string symbol = bpe_substring(token, position, position + width)
                int byte = bpe_decode_byte_symbol(symbol)
                if byte < 0 { return hf_bpe_decode_result { ok: false, text: output, error_code: "invalid_bytelevel_symbol" } }
                output = output + string(byte)
                position = position + width
            }
        } else if tokenizer.metaspace_pre_tokenizer {
            int position = 0
            for position < len(token) {
                if position + len(tokenizer.metaspace_replacement) <= len(token) && bpe_substring(token, position, position + len(tokenizer.metaspace_replacement)) == tokenizer.metaspace_replacement { output = output + " "; position = position + len(tokenizer.metaspace_replacement) } else { output = output + string(token[position]); position = position + 1 }
            }
        } else { output = output + token }
        i = i + 1
    }
    if tokenizer.metaspace_pre_tokenizer && len(output) > 0 && output[0] == 32 { output = bpe_substring(output, 1, len(output)) }
    hf_bpe_decode_result { ok: true, text: output, error_code: "" }
}

func hf_bpe_decode_generated(hf_bpe_tokenizer tokenizer, []int token_ids) hf_bpe_decode_result {
    []int content_ids = make([]int, len(token_ids))
    int count = 0
    int i = 0
    for i < len(token_ids) {
        int id = token_ids[i]
        if id != tokenizer.eos_id && id != tokenizer.bos_id && id != tokenizer.pad_id { content_ids[count] = id; count = count + 1 }
        i = i + 1
    }
    []int exact = make([]int, count)
    i = 0
    for i < count { exact[i] = content_ids[i]; i = i + 1 }
    hf_bpe_decode(tokenizer, exact)
}
