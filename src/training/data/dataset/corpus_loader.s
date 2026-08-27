package neurx.data.dataset.corpus_loader
use neurx.data.streaming_reader.{
    streaming_reader_state, line_read_result,
    init_streaming_reader, read_next_line, default_tb_stream_reader_config,
    stream_reader_config, reset_reader
}
use neurx.tokenizer.data_pipeline.{
    bpe_tokenizer_state, encode, init_bpe_tokenizer, default_llm_tokenizer_config
}
use neurx.runtime.io.{runtime_read_text_file, runtime_file_exists, runtime_run_command_output}

struct data_source {
    string name
    string path
    float weight
    string text_field
    bool is_code
}

struct corpus_config {
    []data_source sources
    int num_sources
    int seq_len
    int batch_size
    int shuffle_buffer
    int min_doc_length
    int max_doc_length
    float min_quality_score
    bool enable_dedup
    int bos_token_id
    int eos_token_id
    int pad_token_id
}

func default_pretraining_corpus() corpus_config {
    []data_source srcs = []data_source{cap: 6}
    srcs[0] = data_source {
        name: "web", path: "src/training/data/web",
        weight: 0.45, text_field: "text", is_code: false,
    }
    srcs[1] = data_source {
        name: "code", path: "src/training/data/code",
        weight: 0.20, text_field: "content", is_code: true,
    }
    srcs[2] = data_source {
        name: "books", path: "src/training/data/books",
        weight: 0.15, text_field: "text", is_code: false,
    }
    srcs[3] = data_source {
        name: "academic", path: "src/training/data/arxiv",
        weight: 0.10, text_field: "abstract", is_code: false,
    }
    srcs[4] = data_source {
        name: "math", path: "src/training/data/math",
        weight: 0.05, text_field: "text", is_code: false,
    }
    srcs[5] = data_source {
        name: "multilingual", path: "src/training/data/multilingual",
        weight: 0.05, text_field: "text", is_code: false,
    }
    corpus_config {
        sources: srcs,
        num_sources: 6,
        seq_len: 4096,
        batch_size: 8,
        shuffle_buffer: 10000,
        min_doc_length: 200,
        max_doc_length: 1000000,
        min_quality_score: 0.3,
        enable_dedup: true,
        bos_token_id: 2,
        eos_token_id: 3,
        pad_token_id: 0,
    }
}

struct corpus_state {
    corpus_config config
    bpe_tokenizer_state tokenizer
    []streaming_reader_state readers
    int current_source
    int rng
    []string shuffle_buffer
    int buf_head
    int buf_size
    int total_docs_seen
    int total_tokens_seen
    int docs_filtered
    int docs_deduped
    []int dedup_hashes
}

func new_corpus_state(corpus_config cfg) corpus_state {
    bpe_tokenizer_state tok = init_bpe_tokenizer(default_llm_tokenizer_config())
    []streaming_reader_state readers = []streaming_reader_state{cap: cfg.num_sources}
    int i = 0
    for i < cfg.num_sources {
        stream_reader_config rc = default_tb_stream_reader_config()
        rc.seq_len = cfg.seq_len
        if runtime_file_exists(cfg.sources[i].path) {
            readers[i] = init_streaming_reader(cfg.sources[i].path, rc)
        }
        i = i + 1
    }
    []string buf = []string{cap: cfg.shuffle_buffer}
    []int hashes = []int{cap: 1000000}
    corpus_state {
        config: cfg,
        tokenizer: tok,
        readers: readers,
        current_source: 0,
        rng: 42,
        shuffle_buffer: buf,
        buf_head: 0,
        buf_size: 0,
        total_docs_seen: 0,
        total_tokens_seen: 0,
        docs_filtered: 0,
        docs_deduped: 0,
        dedup_hashes: hashes,
    }
}

func new_corpus_config_from_sources([]data_source sources, int batch_size, int seq_len, bool enable_dedup) corpus_config {
    corpus_config cfg = default_pretraining_corpus()
    cfg.sources = sources
    cfg.num_sources = len(sources)
    cfg.batch_size = batch_size
    cfg.seq_len = seq_len
    cfg.enable_dedup = enable_dedup
    cfg
}

func new_corpus_state_from_paths([]string paths, int batch_size, int seq_len, bool enable_dedup) corpus_state {
    if len(paths) == 0 {
        return new_corpus_state(default_pretraining_corpus())
    }
    []data_source sources = []data_source{cap: len(paths)}
    int i = 0
    for i < len(paths) {
        data_source src = data_source {
            name: "source_" + int_to_string(i),
            path: paths[i],
            weight: 1.0,
            text_field: "text",
            is_code: false,
        }
        sources[i] = src
        i = i + 1
    }
    new_corpus_state(new_corpus_config_from_sources(sources, batch_size, seq_len, enable_dedup))
}

func jsonl_extract_text(string line, string field) string {
    string pattern = "\"" + field + "\":"
    int plen = len(pattern)
    int llen = len(line)
    int pos = cl_find(line, pattern, 0)
    if pos < 0 {
        return ""
    }
    int start = pos + plen
    for start < llen && line[start] == 32 {
        start = start + 1
    }
    if start >= llen {
        return ""
    }
    if line[start] != 34 {
        return ""
    }
    start = start + 1
    string result = ""
    int i = start
    for i < llen {
        int c = line[i]
        if c == 34 { break }
        if c == 92 && i + 1 < llen {
            int nc = line[i + 1]
            if nc == 110 { result = result + string(10); i = i + 2; continue }
            if nc == 116 { result = result + string(9);  i = i + 2; continue }
            if nc == 92  { result = result + string(92); i = i + 2; continue }
            if nc == 34  { result = result + string(34); i = i + 2; continue }
            i = i + 1
        }
        result = result + string(c)
        i = i + 1
    }
    result
}

func cl_find(string s, string pattern, int start) int {
    int slen = len(s)
    int plen = len(pattern)
    int i = start
    for i <= slen - plen {
        bool match = true
        int j = 0
        for j < plen {
            if s[i + j] != pattern[j] { match = false; break }
            j = j + 1
        }
        if match { return i }
        i = i + 1
    }
    -1
}

func compute_quality_score(string text) float {
    int n = len(text)
    if n == 0 { return 0.0 }
    int printable = 0
    int alpha = 0
    int space = 0
    int word_len = 0
    int word_count = 0
    bool in_word = false
    int total_word_len = 0
    int i = 0
    for i < n {
        int c = text[i]
        if c >= 32 && c < 127 {
            printable = printable + 1
        }
        bool is_alpha = false
        if c >= 65 && c <= 90 {
            is_alpha = true
        }
        if c >= 97 && c <= 122 {
            is_alpha = true
        }
        if is_alpha {
            alpha = alpha + 1
            if !in_word { in_word = true; word_len = 0 }
            word_len = word_len + 1
        } else {
            if in_word {
                total_word_len = total_word_len + word_len
                word_count = word_count + 1
                in_word = false
            }
        }
        if c == 32 { space = space + 1 }
        i = i + 1
    }
    float print_ratio = (printable * 1.0) / (n * 1.0)
    float alpha_ratio = (alpha * 1.0) / (n * 1.0)
    float avg_word_len = 0.0
    if word_count > 0 {
        avg_word_len = (total_word_len * 1.0) / (word_count * 1.0)
    }
    float score = 0.0
    if print_ratio > 0.9 { score = score + 0.4 }
    if alpha_ratio > 0.3 { score = score + 0.3 }
    float wl = avg_word_len
    if wl >= 3.0 && wl <= 12.0 { score = score + 0.3 }
    score
}

func doc_hash(string text) int {
    int h = 2166136261
    int i = 0
    for i < len(text) && i < 2048 {
        h = h * 16777619
        h = h + text[i]
        if h < 0 { h = -h }
        i = i + 1
    }
    h
}

func corpus_is_duplicate(corpus_state state, int hash) bool {
    int i = 0
    for i < state.total_docs_seen && i < len(state.dedup_hashes) {
        if state.dedup_hashes[i] == hash { return true }
        i = i + 1
    }
    false
}

struct packing_buffer {
    []int tokens
    int length
    int capacity
}

func new_packing_buffer(int capacity) packing_buffer {
    []int buf = []int{cap: capacity}
    packing_buffer { tokens: buf, length: 0, capacity: capacity }
}

func pb_append(packing_buffer buf, int token_id) packing_buffer {
    if buf.length < buf.capacity {
        buf.tokens[buf.length] = token_id
        buf.length = buf.length + 1
    }
    buf
}

func pb_is_full(packing_buffer buf) bool {
    buf.length >= buf.capacity
}

func pb_flush(packing_buffer buf) []int {
    []int out = []int{cap: buf.capacity}
    int i = 0
    for i < buf.capacity {
        if i < buf.length {
            out[i] = buf.tokens[i]
        } else {
            out[i] = 0
        }
        i = i + 1
    }
    out
}

func pb_reset(packing_buffer buf) packing_buffer {
    packing_buffer { tokens: buf.tokens, length: 0, capacity: buf.capacity }
}

func corpus_select_source(corpus_state state) corpus_source_selection {
    state.rng = state.rng * 1664525 + 1013904223
    int rabs = state.rng
    if rabs < 0 { rabs = -rabs }
    int r_mod = rabs - (rabs / 1000000) * 1000000
    float r = (r_mod * 1.0) / 1000000.0
    float cumulative = 0.0
    int i = 0
    for i < state.config.num_sources {
        cumulative = cumulative + state.config.sources[i].weight
        if r < cumulative {
            corpus_source_selection {
                source_index: i,
                state: state,
            }
        }
        i = i + 1
    }
    corpus_source_selection {
        source_index: state.config.num_sources - 1,
        state: state,
    }
}

struct corpus_batch {
    []int input_ids
    []int target_ids
    int batch_size
    int seq_len
    int total_tokens
    []string source_names
}

struct corpus_source_selection {
    int source_index
    corpus_state state
}

struct corpus_document_result {
    string text
    corpus_state state
    bool ok
}

struct corpus_batch_result {
    corpus_batch batch
    corpus_state state
}

struct corpus_token_stream_result {
    []int token_ids
    corpus_state state
    int batches_read
    int tokens_collected
}

func corpus_read_document(corpus_state state) corpus_document_result {
    int attempts = 0
    int max_attempts = 20
    for attempts < max_attempts {
        int src_idx
        corpus_source_selection source_selection = corpus_select_source(state)
        src_idx = source_selection.source_index
        state = source_selection.state
        data_source src = state.config.sources[src_idx]
        line_read_result lr = read_next_line(state.readers[src_idx])
        state.readers[src_idx] = lr.updated_reader
        if !lr.success {
            if lr.end_of_file {
                state.readers[src_idx] = reset_reader(state.readers[src_idx])
            }
            attempts = attempts + 1
            continue
        }
        string text = jsonl_extract_text(lr.line_content, src.text_field)
        if len(text) < state.config.min_doc_length {
            state.docs_filtered = state.docs_filtered + 1
            attempts = attempts + 1
            continue
        }
        if len(text) > state.config.max_doc_length {
            text = cl_substring(text, 0, state.config.max_doc_length)
        }
        float qs = compute_quality_score(text)
        if qs < state.config.min_quality_score {
            state.docs_filtered = state.docs_filtered + 1
            attempts = attempts + 1
            continue
        }
        if state.config.enable_dedup {
            int h = doc_hash(text)
            if corpus_is_duplicate(state, h) {
                state.docs_deduped = state.docs_deduped + 1
                attempts = attempts + 1
                continue
            }
            if state.total_docs_seen < len(state.dedup_hashes) {
                state.dedup_hashes[state.total_docs_seen] = h
            }
        }
        state.total_docs_seen = state.total_docs_seen + 1
        corpus_document_result {
            text: text,
            state: state,
            ok: true,
        }
    }
    corpus_document_result {
        text: "",
        state: state,
        ok: false,
    }
}

func corpus_next_batch(corpus_state state) corpus_batch_result {
    int seq_len = state.config.seq_len
    int batch_size = state.config.batch_size
    int bos = state.config.bos_token_id
    int eos = state.config.eos_token_id
    []int all_input = []int{cap: batch_size * seq_len}
    []int all_target = []int{cap: batch_size * seq_len}
    []string src_names = []string{cap: batch_size}
    packing_buffer buf = new_packing_buffer(seq_len)
    int seqs_ready = 0
    for seqs_ready < batch_size {
        string doc_text
        bool ok
        corpus_document_result doc_result = corpus_read_document(state)
        doc_text = doc_result.text
        state = doc_result.state
        ok = doc_result.ok
        if !ok {
            for seqs_ready < batch_size {
                int pos = seqs_ready * seq_len
                int t = 0
                for t < seq_len {
                    all_input[pos + t] = state.config.pad_token_id
                    all_target[pos + t] = -1
                    t = t + 1
                }
                src_names[seqs_ready] = "pad"
                seqs_ready = seqs_ready + 1
            }
            break
        }
        []int token_ids = encode(state.tokenizer, doc_text)
        state.total_tokens_seen = state.total_tokens_seen + len(token_ids)
        buf = pb_append(buf, bos)
        int i = 0
        for i < len(token_ids) {
            buf = pb_append(buf, token_ids[i])
            if pb_is_full(buf) {
                []int seq = pb_flush(buf)
                int pos = seqs_ready * seq_len
                int t = 0
                for t < seq_len {
                    all_input[pos + t] = seq[t]
                    if t + 1 < seq_len {
                        all_target[pos + t] = seq[t + 1]
                    } else {
                        all_target[pos + t] = -1
                    }
                    t = t + 1
                }
                src_names[seqs_ready] = doc_text
                seqs_ready = seqs_ready + 1
                buf = pb_reset(buf)
                if seqs_ready >= batch_size { break }
            }
            i = i + 1
        }
        buf = pb_append(buf, eos)
    }
    corpus_batch batch = corpus_batch {
        input_ids: all_input,
        target_ids: all_target,
        batch_size: batch_size,
        seq_len: seq_len,
        total_tokens: batch_size * seq_len,
        source_names: src_names,
    }
    corpus_batch_result {
        batch: batch,
        state: state,
    }
}

func corpus_collect_token_ids(corpus_state state, int max_tokens) corpus_token_stream_result {
    []int collected = []int{cap: max_tokens}
    int batches_read = 0
    int tokens_collected = 0
    int target_tokens = max_tokens
    if target_tokens < 0 {
        target_tokens = 0
    }
    for tokens_collected < target_tokens {
        corpus_batch_result batch_result = corpus_next_batch(state)
        state = batch_result.state
        []int batch_tokens = batch_result.batch.input_ids
        int i = 0
        for i < len(batch_tokens) && tokens_collected < target_tokens {
            collected = append(collected, batch_tokens[i])
            tokens_collected = tokens_collected + 1
            i = i + 1
        }
        batches_read = batches_read + 1
        if len(batch_tokens) == 0 {
            break
        }
        if tokens_collected >= target_tokens {
            break
        }
        if batches_read > 1000000 {
            break
        }
    }
    corpus_token_stream_result {
        token_ids: collected,
        state: state,
        batches_read: batches_read,
        tokens_collected: tokens_collected,
    }
}

struct corpus_stats {
    int total_docs
    int filtered_docs
    int deduped_docs
    float filter_rate
    float dedup_rate
    int total_tokens_b
}

func corpus_get_stats(corpus_state state) corpus_stats {
    int total = state.total_docs_seen
    float fr = 0.0
    float dr = 0.0
    if total > 0 {
        fr = (state.docs_filtered * 1.0) / (total * 1.0)
        dr = (state.docs_deduped * 1.0) / (total * 1.0)
    }
    corpus_stats {
        total_docs: total,
        filtered_docs: state.docs_filtered,
        deduped_docs: state.docs_deduped,
        filter_rate: fr,
        dedup_rate: dr,
        total_tokens_b: state.total_tokens_seen / 1000000000,
    }
}

func cl_substring(string s, int start, int end) string {
    string out = ""
    int i = start
    for i < end && i < len(s) {
        out = out + string(s[i])
        i = i + 1
    }
    out
}
