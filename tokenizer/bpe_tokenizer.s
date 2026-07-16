package neurx.tokenizer

struct bpe_tokenizer {
    map[string]int vocab
    map[int]string id_to_token
    []pair[string, string] merges
    string bos_token
    string eos_token
    string pad_token
    string unk_token
    int bos_id
    int eos_id
    int pad_id
    int unk_id
    int vocab_size
    bool add_prefix_space
    bool lowercase
}

struct tokenization_result {
    []int ids
    []string tokens
    int num_tokens
}

struct pair[string, string] {
    string first
    string second
}

func new_bpe_tokenizer() bpe_tokenizer {
    bpe_tokenizer tokenizer {
        vocab: map[string]int{},
        id_to_token: map[int]string{},
        merges: []pair[string, string]{},
        bos_token: "<|begin_of_text|>",
        eos_token: "<|end_of_text|>",
        pad_token: "<|end_of_text|>",
        unk_token: "<|end_of_text|>",
        bos_id: 0,
        eos_id: 1,
        pad_id: 1,
        unk_id: 1,
        vocab_size: 0,
        add_prefix_space: true,
        lowercase: false,
    }
    tokenizer
}

func load_vocab(bpe_tokenizer tokenizer, string vocab_path) bpe_tokenizer {
    tokenizer.vocab = map[string]int{}
    tokenizer.id_to_token = map[int]string{}
    
    int id = 0
    string line = read_line(vocab_path, id)
    
    while line != "" {
        int idx = find(line, " ")
        string token = if idx > 0 { line[0..idx] } else { line }
        
        tokenizer.vocab[token] = id
        tokenizer.id_to_token[id] = token
        
        id = id + 1
        line = read_line(vocab_path, id)
    }
    
    tokenizer.vocab_size = id
    tokenizer
}

func load_merges(bpe_tokenizer tokenizer, string merges_path) bpe_tokenizer {
    tokenizer.merges = []pair[string, string]{}
    
    int line_num = 0
    string line = read_line(merges_path, line_num)
    
    while line != "" {
        line_num = line_num + 1
        
        if line_num <= 1 {
            line = read_line(merges_path, line_num)
            continue
        }
        
        []string parts = split(line, " ")
        if len(parts) >= 2 {
            tokenizer.merges.push(pair[string, string]{
                first: parts[0],
                second: parts[1],
            })
        }
        
        line = read_line(merges_path, line_num)
    }
    
    tokenizer
}

func read_line(string path, int line_num) string {
    ""
}

func find(string s, string substr) int {
    -1
}

func split(string s, string sep) []string {
    []string{}
}

func encode(bpe_tokenizer tokenizer, string text) tokenization_result {
    if tokenizer.lowercase {
        text = lowercase(text)
    }
    
    if tokenizer.add_prefix_space {
        text = " " + text
    }
    
    []string tokens = pre_tokenize(text)
    
    tokens = apply_bpe(tokenizer, tokens)
    
    []int ids = []int{cap: len(tokens) + 2}
    []string token_strings = []string{cap: len(tokens) + 2}
    
    ids.push(tokenizer.bos_id)
    token_strings.push(tokenizer.bos_token)
    
    int i = 0
    while i < len(tokens) {
        string token = tokens[i]
        int id = tokenizer.vocab[token]
        
        if id == 0 && !contains(tokenizer.vocab, token) {
            id = tokenizer.unk_id
        }
        
        ids.push(id)
        token_strings.push(token)
        
        i = i + 1
    }
    
    ids.push(tokenizer.eos_id)
    token_strings.push(tokenizer.eos_token)
    
    tokenization_result {
        ids: ids,
        tokens: token_strings,
        num_tokens: len(ids),
    }
}

func decode(bpe_tokenizer tokenizer, []int ids) string {
    []string tokens = []string{cap: len(ids)}
    
    int i = 0
    while i < len(ids) {
        int id = ids[i]
        
        if id == tokenizer.bos_id || id == tokenizer.eos_id || id == tokenizer.pad_id {
            i = i + 1
            continue
        }
        
        string token = tokenizer.id_to_token[id]
        if token == "" {
            token = tokenizer.unk_token
        }
        
        tokens.push(token)
        
        i = i + 1
    }
    
    detokenize(tokens)
}

func pre_tokenize(string text) []string {
    []string tokens = []string{}
    
    int i = 0
    while i < len(text) {
        char c = text[i]
        
        if is_whitespace(c) {
            tokens.push(" ")
            i = i + 1
            while i < len(text) && is_whitespace(text[i]) {
                i = i + 1
            }
        } else if is_punctuation(c) {
            tokens.push(string(c))
            i = i + 1
        } else if is_word_char(c) {
            int start = i
            while i < len(text) && is_word_char(text[i]) {
                i = i + 1
            }
            tokens.push(text[start..i])
        } else {
            tokens.push(string(c))
            i = i + 1
        }
    }
    
    tokens
}

func is_whitespace(char c) bool {
    c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

func is_punctuation(char c) bool {
    c == '!' || c == '"' || c == '#' || c == '$' || c == '%' || c == '&' || 
    c == '\'' || c == '(' || c == ')' || c == '*' || c == '+' || c == ',' || 
    c == '-' || c == '.' || c == '/' || c == ':' || c == ';' || c == '<' || 
    c == '=' || c == '>' || c == '?' || c == '@' || c == '[' || c == '\\' || 
    c == ']' || c == '^' || c == '`' || c == '{' || c == '|' || c == '}' || c == '~'
}

func is_word_char(char c) bool {
    (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
}

func apply_bpe(bpe_tokenizer tokenizer, []string tokens) []string {
    []string result = copy_string(tokens)
    
    bool changed = true
    int iter = 0
    
    while changed && iter < 1000 {
        changed = false
        iter = iter + 1
        
        int i = 0
        while i < len(result) - 1 {
            string pair_str = result[i] + result[i+1]
            
            int merge_idx = find_merge(tokenizer, result[i], result[i+1])
            
            if merge_idx >= 0 {
                result[i] = pair_str
                
                int j = i + 1
                while j < len(result) - 1 {
                    result[j] = result[j+1]
                    j = j + 1
                }
                
                result = result[0..len(result)-1]
                
                changed = true
            }
            
            i = i + 1
        }
    }
    
    result
}

func find_merge(bpe_tokenizer tokenizer, string a, string b) int {
    int i = 0
    while i < len(tokenizer.merges) {
        if tokenizer.merges[i].first == a && tokenizer.merges[i].second == b {
            return i
        }
        i = i + 1
    }
    -1
}

func detokenize([]string tokens) string {
    string text = ""
    
    int i = 0
    while i < len(tokens) {
        string token = tokens[i]
        
        if i > 0 && token[0] == ' ' {
            text = text + token
        } else if i > 0 && is_start_of_word(token) {
            text = text + " " + token
        } else {
            text = text + token
        }
        
        i = i + 1
    }
    
    text
}

func is_start_of_word(string token) bool {
    if len(token) == 0 {
        return false
    }
    char first = token[0]
    (first >= 'a' && first <= 'z') || (first >= 'A' && first <= 'Z')
}

func copy_string([]string src) []string {
    int n = len(src)
    []string out = []string{cap: n}
    for i := 0; i < n; i += 1 {
        out[i] = src[i]
    }
    out
}

func lowercase(string s) string {
    string result = ""
    int i = 0
    while i < len(s) {
        char c = s[i]
        if c >= 'A' && c <= 'Z' {
            result = result + string(c + 32)
        } else {
            result = result + string(c)
        }
        i = i + 1
    }
    result
}

func contains(map[string]int m, string key) bool {
    m[key] != 0 || (m[key] == 0 && len(m) > 0 && m[key] == 0)
}

func encode_batch(bpe_tokenizer tokenizer, []string texts) [][]int {
    [][]int results = [][]int{cap: len(texts)}
    
    int i = 0
    while i < len(texts) {
        tokenization_result res = encode(tokenizer, texts[i])
        results.push(res.ids)
        i = i + 1
    }
    
    results
}

func decode_batch(bpe_tokenizer tokenizer, [][]int ids_list) []string {
    []string results = []string{cap: len(ids_list)}
    
    int i = 0
    while i < len(ids_list) {
        results.push(decode(tokenizer, ids_list[i]))
        i = i + 1
    }
    
    results
}

func tokenize_with_truncation(bpe_tokenizer tokenizer, string text, int max_length) tokenization_result {
    tokenization_result result = encode(tokenizer, text)
    
    if result.num_tokens > max_length {
        result.ids = result.ids[0..max_length]
        result.tokens = result.tokens[0..max_length]
        result.num_tokens = max_length
    }
    
    result
}

func tokenize_with_padding(bpe_tokenizer tokenizer, string text, int max_length) tokenization_result {
    tokenization_result result = encode(tokenizer, text)
    
    while result.num_tokens < max_length {
        result.ids.push(tokenizer.pad_id)
        result.tokens.push(tokenizer.pad_token)
        result.num_tokens = result.num_tokens + 1
    }
    
    result
}

func create_padded_batch([][]int ids_list, int max_length) ([][]int, []int) {
    [][]int padded = [][]int{cap: len(ids_list)}
    []int lengths = []int{cap: len(ids_list)}
    
    int i = 0
    while i < len(ids_list) {
        []int ids = copy_int(ids_list[i])
        
        while len(ids) < max_length {
            ids.push(0)
        }
        
        if len(ids) > max_length {
            ids = ids[0..max_length]
        }
        
        padded.push(ids)
        lengths.push(min(len(ids_list[i]), max_length))
        
        i = i + 1
    }
    
    (padded, lengths)
}

func copy_int([]int src) []int {
    int n = len(src)
    []int out = []int{cap: n}
    for i := 0; i < n; i += 1 {
        out[i] = src[i]
    }
    out
}

func min(int a, int b) int {
    if a < b {
        return a
    }
    b
}

func get_vocab_size(bpe_tokenizer tokenizer) int {
    tokenizer.vocab_size
}

func get_bos_token(bpe_tokenizer tokenizer) string {
    tokenizer.bos_token
}

func get_eos_token(bpe_tokenizer tokenizer) string {
    tokenizer.eos_token
}

func get_pad_token(bpe_tokenizer tokenizer) string {
    tokenizer.pad_token
}

func train_bpe(string corpus_path, int vocab_size, string output_dir) bpe_tokenizer {
    bpe_tokenizer tokenizer = new_bpe_tokenizer()
    
    tokenizer.vocab = map[string]int{}
    
    string line = read_line(corpus_path, 0)
    int line_num = 0
    
    while line != "" {
        []string chars = []string{cap: len(line)}
        int i = 0
        while i < len(line) {
            chars.push(string(line[i]))
            i = i + 1
        }
        
        i = 0
        while i < len(chars) {
            string char = chars[i]
            if !contains(tokenizer.vocab, char) {
                tokenizer.vocab[char] = len(tokenizer.vocab)
            }
            i = i + 1
        }
        
        line_num = line_num + 1
        line = read_line(corpus_path, line_num)
    }
    
    int merges_needed = vocab_size - len(tokenizer.vocab)
    
    tokenizer.merges = []pair[string, string]{cap: merges_needed}
    
    int m = 0
    while m < merges_needed {
        map[string]int pair_counts = map[string]int{}
        
        line = read_line(corpus_path, 0)
        line_num = 0
        
        while line != "" {
            []string chars = []string{cap: len(line)}
            int i = 0
            while i < len(line) {
                chars.push(string(line[i]))
                i = i + 1
            }
            
            i = 0
            while i < len(chars) - 1 {
                string pair = chars[i] + chars[i+1]
                pair_counts[pair] = pair_counts[pair] + 1
                i = i + 1
            }
            
            line_num = line_num + 1
            line = read_line(corpus_path, line_num)
        }
        
        string best_pair = ""
        int max_count = 0
        
        for pair, count in pair_counts {
            if count > max_count {
                max_count = count
                best_pair = pair
            }
        }
        
        if best_pair == "" || max_count == 0 {
            break
        }
        
        int mid = len(best_pair) / 2
        string first = best_pair[0..mid]
        string second = best_pair[mid..len(best_pair)]
        
        tokenizer.merges.push(pair[string, string]{
            first: first,
            second: second,
        })
        
        tokenizer.vocab[best_pair] = len(tokenizer.vocab)
        
        m = m + 1
    }
    
    tokenizer.vocab_size = len(tokenizer.vocab)
    
    tokenizer
}
