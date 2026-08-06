package neurx.tokenizer.data_pipeline
use neurx.strings

struct tokenizer_config {
    string tokenizer_type
    int vocab_size
    string vocab_file
    string merges_file
    string model_file
    string pad_token
    string unk_token
    string bos_token
    string eos_token
    string mask_token
    int pad_token_id
    int unk_token_id
    int bos_token_id
    int eos_token_id
    bool lowercase
    bool strip_whitespace
    bool normalize_unicode
    bool add_prefix_space
    int max_sequence_length
    bool truncation_strategy
    bool enable_caching
    int cache_size
    bool enable_parallel
    int num_threads
    bool return_attention_mask
    bool return_token_type_ids
}

func default_llm_tokenizer_config() tokenizer_config {
    tokenizer_config cfg
    cfg.tokenizer_type = "bpe"
    cfg.vocab_size = 16000
    cfg.vocab_file = "./vocab.json"
    cfg.merges_file = "./merges.txt"
    cfg.model_file = ""
    cfg.pad_token = "<pad>"
    cfg.unk_token = "<unk>"
    cfg.bos_token = "<s>"
    cfg.eos_token = "</s>"
    cfg.mask_token = "<mask>"
    cfg.pad_token_id = 0
    cfg.unk_token_id = 1
    cfg.bos_token_id = 2
    cfg.eos_token_id = 3
    cfg.lowercase = false
    cfg.strip_whitespace = true
    cfg.normalize_unicode = true
    cfg.add_prefix_space = true
    cfg.max_sequence_length = 2048
    cfg.truncation_strategy = "longest_first"
    cfg.enable_caching = true
    cfg.cache_size = 100000
    cfg.enable_parallel = true
    cfg.num_threads = 4
    cfg.return_attention_mask = true
    cfg.return_token_type_ids = false
    return cfg
}

struct bpe_tokenizer_state {
    tokenizer_config config
    []string id_to_token
    map[string]int token_to_id
    []bpe_merge merges
    map[string]int merge_ranks
    string pre_tokenize_pattern
    map[string][]int encoding_cache
    int cache_hits
    int cache_misses
    int total_tokens_produced
    int total_strings_encoded
    float avg_tokens_per_string
}

func init_bpe_tokenizer(tokenizer_config config) bpe_tokenizer_state {
    bpe_tokenizer_state state
    state.config = config
    state.cache_hits = 0
    state.cache_misses = 0
    state.total_tokens_produced = 0
    state.total_strings_encoded = 0
    state.avg_tokens_per_string = 0.0
    state = load_vocabulary(state, config.vocab_file)
    if config.tokenizer_type == "bpe" && len(config.merges_file) > 0 {
        state = load_merges(state, config.merges_file)
    }
    if len(state.pre_tokenize_pattern) == 0 {
        state.pre_tokenize_pattern = get_gpt2_pre_tokenize_pattern()
    }
    return state
}

func load_vocabulary(bpe_tokenizer_state state, string vocab_path) bpe_tokenizer_state {
    string content = read_text_file(vocab_path)
    if len(content) == 0 {
        print("Warning: Empty vocabulary file, using default")
        return state
    }
    map[string]int vocab = parse_vocab_json(content)
    state.id_to_token = []string{cap: state.config.vocab_size}
    state.token_to_id = vocab
    return state
}

func load_merges(bpe_tokenizer_state state, string merges_path) bpe_tokenizer_state {
    string content = read_text_file(merges_path)
    if len(content) == 0 {
        print("Warning: Empty merges file")
        return state
    }
    []string lines = split_lines(content)
    state.merges = []bpe_merge{cap: len(lines)}
    state.merge_ranks = map[string]int{}
    int rank = 0
    while rank < len(lines) {
        string line = lines[rank]
        if len(line) == 0 || line[0] == 35 {
            rank = rank + 1
            continue
        }
        []string parts = split_whitespace(line)
        if len(parts) >= 2 {
            bpe_merge m
            m.token1 = parts[0]
            m.token2 = parts[1]
            m.priority = rank
            state.merges.push(m)
            state.merge_ranks[parts[0] + "|" + parts[1]] = rank
        }
        rank = rank + 1
    }
    return state
}

func encode(bpe_tokenizer_state state, string text) []int {
    state.total_strings_encoded = state.total_strings_encoded + 1
    if state.config.enable_caching && state.encoding_cache.contains(text) {
        state.cache_hits = state.cache_hits + 1
        return state.encoding_cache[text]
    }
    state.cache_misses = state.cache_misses + 1
    string processed = preprocess_text(text, state.config)
    []string words = pre_tokenize(processed, state.pre_tokenize_pattern)
    []int all_token_ids = []int{}
    int w = 0
    while w < len(words) {
        string word = words[w]
        []int word_tokens = bpe_encode_word(state, word)
        int t = 0
        while t < len(word_tokens) {
            all_token_ids.push(word_tokens[t])
            t = t + 1
        }
        w = w + 1
    }
    if len(all_token_ids) > state.config.max_sequence_length {
        all_token_ids = truncate_tokens(all_token_ids, state.config)
    }
    state.total_tokens_produced = state.total_tokens_produced + len(all_token_ids)
    update_running_average(state, len(all_token_ids))
    if state.config.enable_caching && len(state.encoding_cache) < state.config.cache_size {
        state.encoding_cache[text] = all_token_ids
    }
    return all_token_ids
}

func bpe_encode_word(bpe_tokenizer_state state, string word) []int {
    []string tokens = []string{cap: len(word)}
    int i = 0
    while i < len(word) {
        tokens.push(string(word[i]))
        i = i + 1
    }
    if len(tokens) <= 1 {
        if state.token_to_id.contains(word) {
            return [state.token_to_id[word]]
        } else {
            return [state.config.unk_token_id]
        }
    }
    while len(tokens) > 1 {
        int best_pair_idx = -1
        int best_rank = 2147483647
        int p = 0
        while p < len(tokens) - 1 {
            string pair_key = tokens[p] + "|" + tokens[p + 1]
            if state.merge_ranks.contains(pair_key) {
                int rank = state.merge_ranks[pair_key]
                if rank < best_rank {
                    best_rank = rank
                    best_pair_idx = p
                }
            }
            p = p + 1
        }
        if best_pair_idx == -1 {
            break
        }
        string merged = tokens[best_pair_idx] + tokens[best_pair_idx + 1]
        []string new_tokens = []string{cap: len(tokens) - 1}
        int j = 0
        while j < len(tokens) {
            if j == best_pair_idx {
                new_tokens.push(merged)
                j = j + 1
            } else {
                new_tokens.push(tokens[j])
            }
            j = j + 1
        }
        tokens = new_tokens
    }
    []int token_ids = []int{cap: len(tokens)}
    i = 0
    while i < len(tokens) {
        if state.token_to_id.contains(tokens[i]) {
            token_ids.push(state.token_to_id[tokens[i]])
        } else {
            int c = 0
            while c < len(tokens[i]) {
                char ch = tokens[i][c]
                string ch_str = string(ch)
                if state.token_to_id.contains(ch_str) {
                    token_ids.push(state.token_to_id[ch_str])
                } else {
                    token_ids.push(state.config.unk_token_id)
                }
                c = c + 1
            }
        i = i + 1
    }
    return token_ids
}
func decode(bpe_tokenizer_state state, []int token_ids) string {
    []string tokens = []string{cap: len(token_ids)}
    int i = 0
    while i < len(token_ids) {
        int id = token_ids[i]
        if id >= 0 && id < len(state.id_to_token) {
            tokens.push(state.id_to_token[id])
        } else {
            tokens.push(state.config.unk_token)
        }
        i = i + 1
    }
    string result = ""
    i = 0
    while i < len(tokens) {
        result = result + tokens[i]
        i = i + 1
    }
    result = postprocess_decoded(result)
    return result
}
struct batch_encoding_result {
    [][]int input_ids
    [][]int attention_masks
    int batch_size
    int max_seq_len_in_batch
    float total_time_ms
}
func encode_batch(
    bpe_tokenizer_state state,
    []string texts,
    bool padding = true,
    bool truncation = true
) batch_encoding_result {
    int start_time = get_current_time_ms()
    int n = len(texts)
    [][]int raw_encodings = [][]int{cap: n}
    int max_len = 0
    int i = 0
    while i < n {
        []int ids = encode(state, texts[i])
        raw_encodings.push(ids)
        if len(ids) > max_len {
            max_len = len(ids)
        }
        i = i + 1
    }
    if max_len > state.config.max_sequence_length {
        max_len = state.config.max_sequence_length
    }
    [][]int input_ids = [][]int{cap: n}
    [][]int attention_masks = [][]int{cap: n}
    i = 0
    while i < n {
        []int padded = []int{cap: max_len}
        []int mask = []int{cap: max_len}
        int j = 0
        while j < max_len {
            if j < len(raw_encodings[i]) {
                padded[j] = raw_encodings[i][j]
                mask[j] = 1
            } else {
                padded[j] = state.config.pad_token_id
                mask[j] = 0
            }
            j = j + 1
        }
        input_ids.push(padded)
        attention_masks.push(mask)
        i = i + 1
    }
    int end_time = get_current_time_ms()
    batch_encoding_result result
    result.input_ids = input_ids
    result.attention_masks = attention_masks
    result.batch_size = n
    result.max_seq_len_in_batch = max_len
    result.total_time_ms = float(end_time - start_time)
    return result
}
struct streaming_encode_state {
    bpe_tokenizer_state tokenizer
    streaming_reader_state reader
    int buffer_position
    string current_buffer
    []int output_queue
    int tokens_in_queue
    int target_queue_size
    bool end_of_stream
}
func init_streaming_encode(
    bpe_tokenizer_state tokenizer,
    streaming_reader_state reader,
    int target_batch_tokens
) streaming_encode_state {
    streaming_encode_state sstate
    sstate.tokenizer = tokenizer
    sstate.reader = reader
    sstate.buffer_position = 0
    sstate.current_buffer = ""
    sstate.output_queue = []int{cap: target_batch_tokens * 2}
    sstate.tokens_in_queue = 0
    sstate.target_queue_size = target_batch_tokens
    sstate.end_of_stream = false
    return sstate
}
struct streaming_batch_result {
    []int token_ids
    int count
    bool end_of_stream
    streaming_encode_state updated_state
}
func streaming_next_batch(streaming_encode_state sstate) streaming_batch_result {
    while sstate.tokens_in_queue < sstate.target_queue_size && !sstate.end_of_stream {
        if sstate.buffer_position >= len(sstate.current_buffer) {
            line_read_result line_res = read_next_line(sstate.reader)
            sstate.reader = line_res.updated_reader
            if line_res.success {
                sstate.current_buffer = line_res.line_content
                sstate.buffer_position = 0
            } else {
                sstate.end_of_stream = true
                break
            }
        }
        if sstate.buffer_position < len(sstate.current_buffer) {
            string to_encode = substring(
                sstate.current_buffer,
                sstate.buffer_position,
                len(sstate.current_buffer)
            )
            []int new_tokens = encode(sstate.tokenizer, to_encode)
            int t = 0
            while t < len(new_tokens) {
                sstate.output_queue.push(new_tokens[t])
                sstate.tokens_in_queue = sstate.tokens_in_queue + 1
                t = t + 1
            }
            sstate.buffer_position = len(sstate.current_buffer)
        }
    }
    int batch_size = min(sstate.tokens_in_queue, sstate.target_queue_size)
    []int batch = []int{cap: batch_size}
    int b = 0
    while b < batch_size && len(sstate.output_queue) > 0 {
        batch.push(sstate.output_queue[0])
        sstate.output_queue.remove_at(0)
        sstate.tokens_in_queue = sstate.tokens_in_queue - 1
        b = b + 1
    }
    streaming_batch_result result
    result.token_ids = batch
    result.count = batch_size
    result.end_of_stream = sstate.end_of_stream && sstate.tokens_in_queue == 0
    result.updated_state = sstate
    return result
}
struct bpe_merge {
    string token1
    string token2
    int priority
}
func preprocess_text(string text, tokenizer_config cfg) string {
    if cfg.normalize_unicode {
        text = unicode_normalize(text)
    }
    if cfg.lowercase {
        text = to_lowercase(text)
    }
    if cfg.add_prefix_space && len(text) > 0 && text[0] != " " {
        text = " " + text
    }
    if cfg.strip_whitespace {
        text = trim(text)
    }
    return text
}
func pre_tokenize(string text, string pattern) []string {
    []string words = []string{cap: 10}
    int start = 0
    int i = 0
    while i <= len(text) {
        if i == len(text) || text[i] == " " || text[i] == "\n" || text[i] == "\t" {
            if i > start {
                string word = substring(text, start, i)
                words.push(word)
            }
            start = i + 1
        }
        i = i + 1
    }
    return words
}
func truncate_tokens([]int tokens, tokenizer_config cfg) []int {
    int max_len = cfg.max_sequence_length
    if len(tokens) <= max_len {
        return tokens
    }
    []int result = []int{cap: max_len}
    int start = 0
    if cfg.truncation_strategy == "only_first" {
        start = len(tokens) - max_len
    }
    int i = 0
    while i < max_len {
        result.push(tokens[start + i])
        i = i + 1
    }
    return result
}
func postprocess_decoded(string text) string {
    return text
}
func update_running_average(bpe_tokenizer_state state, int new_value) void {
    int n = state.total_strings_encoded
    if n > 0 {
        state.avg_tokens_per_string =
            (state.avg_tokens_per_string * float(n - 1) + float(new_value)) / float(n)
    }
func get_gpt2_pre_tokenize_pattern() string {
    return """'s|'t|'re|'ve|'m|'ll|'d| ?\\p{L}+| ?\\p{N}+| ?[^\\s\\p{L}\\p{N}]+|\\s+(?!\\S)|\\s+"""
}
func read_text_file(string path) string {
    return ""
}
func parse_vocab_json(string json_content) map[string]int {
    return map[string]int{}
}
func split_lines(string text) []string {
    return []string{cap: 0}
}
func split_whitespace(string text) []string {
    return []string{cap: 0}
}
func get_current_time_ms() int {
    return 0
}
func substring(string s, int start, int end) string {
    return ""
}
func trim(string s) string {
    return s
}
func to_lowercase(string s) string {
    return s
}
func unicode_normalize(string s) string {
    return s
}
}
}
}

