package neurx.data.jsonl_loader
use neurx.strings
use neurx.runtime.io.{io_println, runtime_file_exists, runtime_read_text_file}
use neurx.tokenizer.model_bpe.{bpe_tokenizer, token_config, new_tokenizer_config, new_bpe_tokenizer, encode, pad_sequence}

struct jsonl_document {
    string text
    string source
    long document_id
    []string metadata_keys
    []string metadata_values
}

func read_jsonl_file(string filepath) []jsonl_document {
    []jsonl_document docs = make([]jsonl_document, 0)
    if !runtime_file_exists(filepath) {
        return docs
    }
    string content = runtime_read_text_file(filepath)
    []string lines = split_lines(content)
    int i = 0
    long doc_id = 0
    for i < len(lines) {
        string line = trim_string(lines[i])
        if len(line) > 0 {
            jsonl_document doc = parse_json_document(line)
            doc.source = filepath
            doc.document_id = doc_id
            docs = append(docs, doc)
            doc_id = doc_id + 1
        }
        i = i + 1
    }
    docs
}

func parse_json_document(string json_line) jsonl_document {
    jsonl_document doc = jsonl_document {
        text: "",
        source: "unknown",
        document_id: 0,
        metadata_keys: []string{},
        metadata_values: []string{},
    }
    string extracted = extract_json_string_field(json_line, "text")
    if len(extracted) > 0 {
        doc.text = extracted
    } else {
        doc.text = json_line
    }
    doc
}

struct jsonl_data_config {
    string data_dir
    int num_shards
    int batch_size
    int seq_len
    int vocab_size
    int dp_rank
    int dp_size
    int max_seq_length
    int shuffle_buffer_size
}

struct jsonl_batch {
    []int token_ids
    []int attention_mask
    []long document_ids
    []string metadata
}

struct jsonl_data_loader {
    jsonl_data_config config
    bpe_tokenizer tokenizer
    int current_shard_idx
    int current_doc_idx
    []jsonl_document current_shard_docs
    []int token_buffer
    int buffer_start_idx
    int buffer_end_idx
    long total_tokens_processed
    int num_batches_generated
    int documents_per_shard
}

func jsonl_data_loader_new(
    string data_dir,
    int batch_size,
    int seq_len,
    int dp_rank,
    int dp_size
) jsonl_data_loader {
    jsonl_data_config cfg = jsonl_data_config {
        data_dir: data_dir,
        num_shards: 8192,
        batch_size: batch_size,
        seq_len: seq_len,
        vocab_size: 128000,
        dp_rank: dp_rank,
        dp_size: dp_size,
        max_seq_length: 32768,
        shuffle_buffer_size: 10000,
    }
    bpe_tokenizer tok = new_bpe_tokenizer(build_default_vocab(), new_tokenizer_config())
    jsonl_data_loader loader = jsonl_data_loader {
        config: cfg,
        tokenizer: tok,
        current_shard_idx: 0,
        current_doc_idx: 0,
        current_shard_docs: make([]jsonl_document, 0),
        token_buffer: []int{},
        buffer_start_idx: 0,
        buffer_end_idx: 0,
        total_tokens_processed: 0,
        num_batches_generated: 0,
        documents_per_shard: 0,
    }
    loader
}

func get_shard_indices_for_rank(
    int dp_rank,
    int dp_size,
    int num_shards
) []int {
    []int shard_indices = []int{}
    int shard = dp_rank
    for shard < num_shards {
        shard_indices = append_int(shard_indices, shard)
        shard = shard + dp_size
    }
    shard_indices
}

func pack_tokens_into_batch(
    jsonl_data_loader loader,
    []int token_sequence,
    int batch_size,
    int seq_len
) jsonl_batch {
    []int batch_token_ids = make([]int, batch_size * seq_len)
    []int batch_attention_mask = make([]int, batch_size * seq_len)
    int i = 0
    for i < batch_size {
        []int tokens = make([]int, seq_len)
        []int mask = make([]int, seq_len)
        int j = 0
        for j < seq_len {
            int token_idx = i * seq_len + j
            if token_idx < len(token_sequence) {
                tokens[j] = token_sequence[token_idx]
                mask[j] = 1
            } else {
                tokens[j] = loader.tokenizer.pad_token_id
                mask[j] = 0
            }
            j = j + 1
        }
        int base = i * seq_len
        int k = 0
        for k < seq_len {
            batch_token_ids[base + k] = tokens[k]
            batch_attention_mask[base + k] = mask[k]
            k = k + 1
        }
        i = i + 1
    }
    jsonl_batch batch = jsonl_batch {
        token_ids: batch_token_ids,
        attention_mask: batch_attention_mask,
        document_ids: make([]long, 0),
        metadata: []string{},
    }
    batch
}

func get_next_batch(
    jsonl_data_loader loader
) jsonl_batch {
    if loader.current_doc_idx >= len(loader.current_shard_docs) {
        load_next_shard(loader)
    }
    []int accumulated_tokens = []int{}
    for len(accumulated_tokens) < (loader.config.batch_size * loader.config.seq_len) {
        if loader.current_doc_idx >= len(loader.current_shard_docs) {
            load_next_shard(loader)
            if len(loader.current_shard_docs) == 0 {
                break
            }
        }
        jsonl_document doc = loader.current_shard_docs[loader.current_doc_idx]
        []int tokens = encode(loader.tokenizer, doc.text)
        []int doc_tokens = []int{}
        doc_tokens = append_int(doc_tokens, loader.tokenizer.bos_token_id)
        int i = 0
        for i < len(tokens) {
            doc_tokens = append_int(doc_tokens, tokens[i])
            i = i + 1
        }
        doc_tokens = append_int(doc_tokens, loader.tokenizer.eos_token_id)
        i = 0
        for i < len(doc_tokens) {
            if len(accumulated_tokens) < loader.config.batch_size * loader.config.seq_len {
                accumulated_tokens = append_int(accumulated_tokens, doc_tokens[i])
            }
            i = i + 1
        }
        loader.current_doc_idx = loader.current_doc_idx + 1
        loader.total_tokens_processed = loader.total_tokens_processed + long(len(doc_tokens))
    }
    jsonl_batch batch = pack_tokens_into_batch(
        loader, accumulated_tokens,
        loader.config.batch_size,
        loader.config.seq_len
    )
    loader.num_batches_generated = loader.num_batches_generated + 1
    batch
}

func load_next_shard(jsonl_data_loader loader) {
    []int shard_indices = get_shard_indices_for_rank(
        loader.config.dp_rank,
        loader.config.dp_size,
        loader.config.num_shards
    )
    if loader.current_shard_idx >= len(shard_indices) {
        loader.current_shard_docs = make([]jsonl_document, 0)
        return
    }
    int shard_id = shard_indices[loader.current_shard_idx]
    string filepath = loader.config.data_dir + "/shard_" + int_to_string(shard_id) + ".jsonl"
    []jsonl_document docs = read_jsonl_file(filepath)
    loader.current_shard_docs = docs
    loader.current_doc_idx = 0
    loader.current_shard_idx = loader.current_shard_idx + 1
}

func get_loader_stats(jsonl_data_loader loader) string {
    string stats = "JSONL Loader Stats:\n"
    stats = stats + "  Total tokens processed: " + long_to_string(loader.total_tokens_processed) + "\n"
    stats = stats + "  Batches generated: " + int_to_string(loader.num_batches_generated) + "\n"
    stats = stats + "  Current shard: " + int_to_string(loader.current_shard_idx) + "\n"
    stats
}

func append_int([]int arr, int val) []int {
    []int out = make([]int, len(arr) + 1)
    int i = 0
    for i < len(arr) {
        out = append(out, arr[i])
        i = i + 1
    }
    out = append(out, val)
    out
}

func append_string([]string arr, string val) []string {
    []string out = make([]string, len(arr) + 1)
    int i = 0
    for i < len(arr) {
        out = append(out, arr[i])
        i = i + 1
    }
    out = append(out, val)
    out
}

func int_to_string(int x) string {
    if x == 0 {
        return "0"
    }
    bool neg = false
    int value = x
    if value < 0 {
        neg = true
        value = -value
    }
    string out = ""
    for value > 0 {
        int digit = value % 10
        out = string(digit + 48) + out
        value = value / 10
    }
    if neg {
        out = "-" + out
    }
    out
}

func long_to_string(long x) string {
    int value = int(x)
    int_to_string(value)
}

func split_lines(string text) []string {
    []string lines = []string{}
    string current = ""
    int i = 0
    for i < len(text) {
        string ch = neurx.strings.substring(text, i, i + 1)
        if ch == "\n" || ch == "\r" {
            if len(current) > 0 {
                lines = append(lines, current)
                current = ""
            }
        } else {
            current = neurx.strings.concat2(current, ch)
        }
        i = i + 1
    }
    if len(current) > 0 {
        lines = append(lines, current)
    }
    lines
}

func trim_string(string text) string {
    int left = 0
    int right = len(text) - 1
    for left < len(text) {
        string ch = neurx.strings.substring(text, left, left + 1)
        if ch != " " && ch != "\t" && ch != "\n" && ch != "\r" {
            break
        }
        left = left + 1
    }
    for right >= left {
        string ch = neurx.strings.substring(text, right, right + 1)
        if ch != " " && ch != "\t" && ch != "\n" && ch != "\r" {
            break
        }
        right = right - 1
    }
    if right < left {
        return ""
    }
    neurx.strings.substring(text, left, right + 1)
}

func extract_json_string_field(string json_line, string field_name) string {
    string needle = "\"" + field_name + "\""
    int pos = find_substring(json_line, needle)
    if pos < 0 {
        return ""
    }
    int i = pos + len(needle)
    for i < len(json_line) {
        string ch = neurx.strings.substring(json_line, i, i + 1)
        if ch == ":" {
            i = i + 1
            break
        }
        i = i + 1
    }
    for i < len(json_line) {
        string ch = neurx.strings.substring(json_line, i, i + 1)
        if ch != " " && ch != "\t" {
            break
        }
        i = i + 1
    }
    if i >= len(json_line) {
        return ""
    }
    if neurx.strings.substring(json_line, i, i + 1) != "\"" {
        return ""
    }
    i = i + 1
    string out = ""
    for i < len(json_line) {
        string ch = neurx.strings.substring(json_line, i, i + 1)
        if ch == "\"" {
            return out
        }
        if ch == "\\" && i + 1 < len(json_line) {
            string next_ch = neurx.strings.substring(json_line, i + 1, i + 2)
            if next_ch == "\"" {
                out = neurx.strings.concat2(out, "\"")
                i = i + 2
                continue
            }
            if next_ch == "n" {
                out = neurx.strings.concat2(out, "\n")
                i = i + 2
                continue
            }
            if next_ch == "t" {
                out = neurx.strings.concat2(out, "\t")
                i = i + 2
                continue
            }
            if next_ch == "\\" {
                out = neurx.strings.concat2(out, "\\")
                i = i + 2
                continue
            }
        }
        out = neurx.strings.concat2(out, ch)
        i = i + 1
    }
    out
}

func find_substring(string text, string pattern) int {
    if len(pattern) == 0 {
        return 0
    }
    int i = 0
    for i + len(pattern) <= len(text) {
        int j = 0
        for j < len(pattern) {
            if neurx.strings.substring(text, i + j, i + j + 1) != neurx.strings.substring(pattern, j, j + 1) {
                break
            }
            j = j + 1
        }
        if j == len(pattern) {
            return i
        }
        i = i + 1
    }
    -1
}

func build_default_vocab() []string {
    []string vocab = []string{}
    vocab = append(vocab, "<pad>")
    vocab = append(vocab, "<bos>")
    vocab = append(vocab, "<eos>")
    vocab = append(vocab, "<unk>")
    int c = 32
    for c <= 126 {
        vocab = append(vocab, string(c))
        c = c + 1
    }
    vocab = append(vocab, "\n")
    vocab = append(vocab, "\t")
    vocab
}
