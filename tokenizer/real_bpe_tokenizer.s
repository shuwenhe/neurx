package neurx.tokenizer.real_bpe_tokenizer

struct real_bpe_tokenizer {
    map[string]int vocab
    map[int]string id_to_token
    []pair merge_rules
    map[int]string byte_tokens
    int vocab_size
    int bos_id
    int eos_id
    int pad_id
    int unk_id
    string bos_token
    string eos_token
    string pad_token
    string unk_token
    bool add_bos
    bool add_eos
}

struct pair {
    string first
    string second
}

func new_real_bpe_tokenizer() real_bpe_tokenizer {
    map[string]int vocab = map[string]int{}
    map[int]string id_to_token = map[int]string{}
    []pair merges = []pair{}
    int id = 0
    int i = 0
    while i < 26 {
        string c = string_from_code(97 + i)
        vocab[c] = id
        id_to_token[id] = c
        id = id + 1
        i = i + 1
    }
    i = 0
    while i < 26 {
        string c = string_from_code(65 + i)
        vocab[c] = id
        id_to_token[id] = c
        id = id + 1
        i = i + 1
    }
    i = 0
    while i < 10 {
        string c = string_from_code(48 + i)
        vocab[c] = id
        id_to_token[id] = c
        id = id + 1
        i = i + 1
    }
    string[] punct = []string{" ", ".", ",", "!", "?", ":", ";", "'", "\"", "-", "(", ")", "\n"}
    int p = 0
    while p < len(punct) {
        if vocab[punct[p]] == 0 && !map_has(vocab, punct[p]) {
            vocab[punct[p]] = id
            id_to_token[id] = punct[p]
            id = id + 1
        }
        p = p + 1
    }
    string[] common = []string{"the", " a", " is", " of", " to", " in", " and", " that", " for", " it", " as", " was", " with", " on", " are", " you", " hi", "hello", " world", "foo", "bar", " test"}
    int c = 0
    while c < len(common) {
        if !map_has(vocab, common[c]) {
            vocab[common[c]] = id
            id_to_token[id] = common[c]
            id = id + 1
        }
        c = c + 1
    }
    merges = []pair{
        pair{first: "h", second: "e"},
        pair{first: "he", second: "l"},
        pair{first: "hel", second: "l"},
        pair{first: "hell", second: "o"},
        pair{first: " ", second: "h"},
        pair{first: " h", second: "e"},
        pair{first: " he", second: "l"},
        pair{first: " hel", second: "l"},
        pair{first: " hell", second: "o"},
        pair{first: "w", second: "o"},
        pair{first: "wo", second: "r"},
        pair{first: "wor", second: "l"},
        pair{first: "worl", second: "d"},
        pair{first: " ", second: "w"},
        pair{first: " w", second: "o"},
        pair{first: " wo", second: "r"},
        pair{first: " wor", second: "l"},
        pair{first: " worl", second: "d"},
    }
    int bos_id = id
    vocab["<|bos|>"] = bos_id
    id_to_token[bos_id] = "<|bos|>"
    id = id + 1
    int eos_id = id
    vocab["<|eos|>"] = eos_id
    id_to_token[eos_id] = "<|eos|>"
    id = id + 1
    int pad_id = id
    vocab["<|pad|>"] = pad_id
    id_to_token[pad_id] = "<|pad|>"
    id = id + 1
    int unk_id = id
    vocab["<|unk|>"] = unk_id
    id_to_token[unk_id] = "<|unk|>"
    id = id + 1
    map[int]string byte_tokens = map[int]string{}
    int b = 0
    while b < 256 {
        string tok = "<0x"
        tok = tok + hex_byte(b)
        tok = tok + ">"
        vocab[tok] = id
        id_to_token[id] = tok
        byte_tokens[b] = tok
        id = id + 1
        b = b + 1
    }
    real_bpe_tokenizer{
        vocab: vocab,
        id_to_token: id_to_token,
        merge_rules: merges,
        byte_tokens: byte_tokens,
        vocab_size: id,
        bos_id: bos_id,
        eos_id: eos_id,
        pad_id: pad_id,
        unk_id: unk_id,
        bos_token: "<|bos|>",
        eos_token: "<|eos|>",
        pad_token: "<|pad|>",
        unk_token: "<|unk|>",
        add_bos: true,
        add_eos: false,
    }
}

func string_from_code(int code) string {
    string(code)
}

func hex_byte(int b) string {
    string hex = "0123456789ABCDEF"
    int hi = b / 16
    int lo = b - (b / 16) * 16
    string_from_code(int(hex[hi])) + string_from_code(int(hex[lo]))
}

func map_has(map[string]int m, string key) bool {
    int v = m[key]
    v != 0 || m_contains_key(m, key)
}

func map_has_int(map[int]string m, int key) bool {
    string v = m[key]
    v != "" || m_contains_key_int(m, key)
}
extern "intrinsic" func m_contains_key(map[string]int m, string key) bool
extern "intrinsic" func m_contains_key_int(map[int]string m, int key) bool

func pre_tokenize(string text) []string {
    []string words = []string{}
    string cur = ""
    int i = 0
    while i < len(text) {
        int ch = int(text[i])
        if ch == 32 || ch == 10 || ch == 9 {
            if len(cur) > 0 {
                words = append(words, cur)
                cur = ""
            }
            words = append(words, " ")
        } else if (ch >= 65 && ch <= 90) || (ch >= 97 && ch <= 122) || (ch >= 48 && ch <= 57) {
            cur = cur + string_from_code(ch)
        } else {
            if len(cur) > 0 {
                words = append(words, cur)
                cur = ""
            }
            words = append(words, string_from_code(ch))
        }
        i = i + 1
    }
    if len(cur) > 0 {
        words = append(words, cur)
    }
    words
}

func word_to_chars(string word) []string {
    []string chars = []string{}
    if word == "" {
        return chars
    }
    int i = 0
    while i < len(word) {
        chars = append(chars, string_from_code(int(word[i])))
        i = i + 1
    }
    chars
}

func find_pair_rank([]string symbols, int idx) pair {
    pair{first: symbols[idx], second: symbols[idx + 1]}
}

func pair_equals(pair a, pair b) bool {
    a.first == b.first && a.second == b.second
}

func apply_bpe_merges(real_bpe_tokenizer tokenizer, []string words) []string {
    []string out = []string{}
    int w = 0
    while w < len(words) {
        string word = words[w]
        if map_has(tokenizer.vocab, word) {
            out = append(out, word)
            w = w + 1
            continue
        }
        []string symbols = word_to_chars(word)
        bool changed = true
        while changed {
            changed = false
            int best_rank = -1
            int best_pos = -1
            int i = 0
            while i < len(symbols) - 1 {
                pair candidate = find_pair_rank(symbols, i)
                int m = 0
                while m < len(tokenizer.merge_rules) {
                    if pair_equals(candidate, tokenizer.merge_rules[m]) {
                        if best_rank < 0 || m < best_rank {
                            best_rank = m
                            best_pos = i
                        }
                    }
                    m = m + 1
                }
                i = i + 1
            }
            if best_pos >= 0 {
                []string new_symbols = []string{}
                int j = 0
                while j < best_pos {
                    new_symbols = append(new_symbols, symbols[j])
                    j = j + 1
                }
                new_symbols = append(new_symbols, symbols[best_pos] + symbols[best_pos + 1])
                j = best_pos + 2
                while j < len(symbols) {
                    new_symbols = append(new_symbols, symbols[j])
                    j = j + 1
                }
                symbols = new_symbols
                changed = true
            }
        }
        int s = 0
        while s < len(symbols) {
            out = append(out, symbols[s])
            s = s + 1
        }
        w = w + 1
    }
    out
}

func encode(real_bpe_tokenizer tokenizer, string text) []int {
    []string words = pre_tokenize(text)
    []string tokens = apply_bpe_merges(tokenizer, words)
    []int ids = []int{}
    if tokenizer.add_bos {
        ids = append(ids, tokenizer.bos_id)
    }
    int i = 0
    while i < len(tokens) {
        string tok = tokens[i]
        if map_has(tokenizer.vocab, tok) {
            ids = append(ids, tokenizer.vocab[tok])
        } else {
            int j = 0
            while j < len(tok) {
                int code = int(tok[j])
                if code < 0 {
                    code = code + 256
                }
                if code >= 256 {
                    code = 255
                }
                string byte_tok = tokenizer.byte_tokens[code]
                if map_has(tokenizer.vocab, byte_tok) {
                    ids = append(ids, tokenizer.vocab[byte_tok])
                } else {
                    ids = append(ids, tokenizer.unk_id)
                }
                j = j + 1
            }
        }
        i = i + 1
    }
    if tokenizer.add_eos {
        ids = append(ids, tokenizer.eos_id)
    }
    ids
}

func decode(real_bpe_tokenizer tokenizer, []int ids) string {
    string result = ""
    int i = 0
    while i < len(ids) {
        int id = ids[i]
        if id == tokenizer.bos_id || id == tokenizer.eos_id || id == tokenizer.pad_id {
            i = i + 1
            continue
        }
        if map_has_int(tokenizer.id_to_token, id) {
            string tok = tokenizer.id_to_token[id]
            if len(tok) >= 6 && tok[0:5] == "<0x" && tok[len(tok)-1] == 62 {
                int b = parse_hex_byte(tok[3:5])
                result = result + string_from_code(b)
            } else {
                result = result + tok
            }
        } else {
            result = result + tokenizer.unk_token
        }
        i = i + 1
    }
    result
}

func parse_hex_byte(string hex2) int {
    if len(hex2) < 2 {
        return 0
    }
    int hi = hex_digit(int(hex2[0]))
    int lo = hex_digit(int(hex2[1]))
    if hi < 0 || lo < 0 {
        return 0
    }
    hi * 16 + lo
}

func hex_digit(int ch) int {
    if ch >= 48 && ch <= 57 {
        return ch - 48
    }
    if ch >= 65 && ch <= 70 {
        return ch - 55
    }
    if ch >= 97 && ch <= 102 {
        return ch - 87
    }
    -1
}

func vocab_lookup(real_bpe_tokenizer tokenizer, string token) int {
    if !map_has(tokenizer.vocab, token) {
        return tokenizer.unk_id
    }
    tokenizer.vocab[token]
}

func token_count(real_bpe_tokenizer tokenizer, string text) int {
    []int ids = encode(tokenizer, text)
    len(ids)
}
