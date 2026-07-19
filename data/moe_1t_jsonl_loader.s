package neurx.data.jsonl_loader

// ============================================================================
// JSONL dataloadEnglish text(actualdata)
//
// dataEnglish text:
//   English text JSON English text: {"text": "...", "metadata": {...}}
//   English text: {"text": "document content"}
//
// English textpipeline:
//   1. English text 8192 English text JSONL fileEnglish text
//   2. use BPE tokenizer English text tokenization
//   3. English text batch_size × seq_len English text
//   4. English text token IDs English text attention mask
//
// English text:
//   - English textdataEnglish text(English text DP rank English text)
//   - English textloadEnglish text
//   - English text
//   - supportEnglish text
//
// ============================================================================

use neurx.strings
use neurx.runtime.io.{io_println, runtime_file_exists, runtime_read_text_file}
use neurx.tokenizer.model_bpe.{bpe_tokenizer, token_config, new_tokenizer_config, new_bpe_tokenizer, encode, pad_sequence}

// ============================================================================
// 2. JSONL fileEnglish text
// ============================================================================

struct jsonl_document {
    string text
    string source              // fileSource
    long document_id
    []string metadata_keys
    []string metadata_values
}

// English text JSONL fileEnglish text
func read_jsonl_file(string filepath) []jsonl_document {
    []jsonl_document docs = []jsonl_document{cap: 0}
    if !runtime_file_exists(filepath) {
        return docs
    }

    string content = runtime_read_text_file(filepath)
    []string lines = split_lines(content)
    int i = 0
    long doc_id = 0
    while i < len(lines) {
        string line = trim_string(lines[i])
        if len(line) > 0 {
            jsonl_document doc = parse_json_document(line)
            doc.source = filepath
            doc.document_id = doc_id
            docs.push(doc)
            doc_id = doc_id + 1
        }
        i = i + 1
    }

    docs
}

// English text JSON English text(English text)
func parse_json_document(string json_line) jsonl_document {
    jsonl_document doc = jsonl_document {
        text: "",
        source: "unknown",
        document_id: 0,
        metadata_keys: []string{cap: 0},
        metadata_values: []string{cap: 0},
    }
    string extracted = extract_json_string_field(json_line, "text")
    if len(extracted) > 0 {
        doc.text = extracted
    } else {
        doc.text = json_line
    }
    doc
}

// ============================================================================
// 3. dataloadEnglish text
// ============================================================================

struct jsonl_data_config {
    string data_dir              // JSONL fileEnglish textdirectory
    int num_shards              // English textcount (8192)
    int batch_size
    int seq_len
    int vocab_size              // Tokenizer English text
    int dp_rank                 // Data parallel rank
    int dp_size                 // Data parallel size
    int max_seq_length
    int shuffle_buffer_size
}

struct jsonl_batch {
    []int token_ids             // [batch_size * seq_len]
    []int attention_mask        // [batch_size * seq_len]
    []long document_ids         // [batch_size]
    []string metadata           // [batch_size, num_metadata_fields]
}

struct jsonl_data_loader {
    jsonl_data_config config
    bpe_tokenizer tokenizer

    // English textstate
    int current_shard_idx
    int current_doc_idx
    []jsonl_document current_shard_docs

    // English text
    []int token_buffer          // English text token IDs
    int buffer_start_idx
    int buffer_end_idx

    // statistics
    long total_tokens_processed
    int num_batches_generated
    int documents_per_shard
}

// initializedataloadEnglish text
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
        current_shard_docs: []jsonl_document{cap: 0},
        token_buffer: []int{cap: 0},
        buffer_start_idx: 0,
        buffer_end_idx: 0,
        total_tokens_processed: 0,
        num_batches_generated: 0,
        documents_per_shard: 0,
    }

    loader
}

// ============================================================================
// 4. dataEnglish text
// ============================================================================

// computeEnglish text DP rank English text
func get_shard_indices_for_rank(
    int dp_rank,
    int dp_size,
    int num_shards
) []int {

    []int shard_indices = []int{cap: 0}

    // English text: rank 0 English text 0, dp_size, 2*dp_size, ...
    int shard = dp_rank
    while shard < num_shards {
        shard_indices = append_int(shard_indices, shard)
        shard = shard + dp_size
    }

    shard_indices
}

// ============================================================================
// 5. Token English text
// ============================================================================

// English text token English text batch
func pack_tokens_into_batch(
    jsonl_data_loader loader,
    []int token_sequence,        // English text token English text
    int batch_size,
    int seq_len
) jsonl_batch {

    []int batch_token_ids = []int{cap: batch_size * seq_len}
    []int batch_attention_mask = []int{cap: batch_size * seq_len}

    int i = 0
    while i < batch_size {
        []int tokens = []int{cap: seq_len}
        []int mask = []int{cap: seq_len}

        // English text token_sequence English text seq_len English text token
        int j = 0
        while j < seq_len {
            int token_idx = i * seq_len + j

            if token_idx < len(token_sequence) {
                tokens[j] = token_sequence[token_idx]
                mask[j] = 1
            } else {
                // English text
                tokens[j] = loader.tokenizer.pad_token_id
                mask[j] = 0
            }

            j = j + 1
        }

        int base = i * seq_len
        int k = 0
        while k < seq_len {
            batch_token_ids[base + k] = tokens[k]
            batch_attention_mask[base + k] = mask[k]
            k = k + 1
        }

        i = i + 1
    }

    jsonl_batch batch = jsonl_batch {
        token_ids: batch_token_ids,
        attention_mask: batch_attention_mask,
        document_ids: []long{cap: 0},
        metadata: []string{cap: 0},
    }

    batch
}

// ============================================================================
// 6. English text Batch
// ============================================================================

// English textdata batch
func get_next_batch(
    jsonl_data_loader loader
) jsonl_batch {

    // stepEnglish text 1: English textRequired, loadEnglish text
    if loader.current_doc_idx >= len(loader.current_shard_docs) {
        load_next_shard(loader)
    }

    // stepEnglish text 2: English text token English textdataEnglish text batch
    []int accumulated_tokens = []int{cap: 0}

    while len(accumulated_tokens) < (loader.config.batch_size * loader.config.seq_len) {

        if loader.current_doc_idx >= len(loader.current_shard_docs) {
            load_next_shard(loader)

            // English textloadEnglish text
            if len(loader.current_shard_docs) == 0 {
                break
            }
        }

        // English text
        jsonl_document doc = loader.current_shard_docs[loader.current_doc_idx]

        // Tokenize
        []int tokens = encode(loader.tokenizer, doc.text)

        // English text token
        // English text BOS, English text EOS
        []int doc_tokens = []int{cap: 0}
        doc_tokens = append_int(doc_tokens, loader.tokenizer.bos_token_id)

        int i = 0
        while i < len(tokens) {
            doc_tokens = append_int(doc_tokens, tokens[i])
            i = i + 1
        }

        doc_tokens = append_int(doc_tokens, loader.tokenizer.eos_token_id)

        // English text
        i = 0
        while i < len(doc_tokens) {
            if len(accumulated_tokens) < loader.config.batch_size * loader.config.seq_len {
                accumulated_tokens = append_int(accumulated_tokens, doc_tokens[i])
            }
            i = i + 1
        }

        loader.current_doc_idx = loader.current_doc_idx + 1
        loader.total_tokens_processed = loader.total_tokens_processed + long(len(doc_tokens))
    }

    // stepEnglish text 3: English text batch
    jsonl_batch batch = pack_tokens_into_batch(
        loader, accumulated_tokens,
        loader.config.batch_size,
        loader.config.seq_len
    )

    loader.num_batches_generated = loader.num_batches_generated + 1

    batch
}

// loadEnglish text
func load_next_shard(jsonl_data_loader loader) {

    // computeEnglish text rank English text
    []int shard_indices = get_shard_indices_for_rank(
        loader.config.dp_rank,
        loader.config.dp_size,
        loader.config.num_shards
    )

    if loader.current_shard_idx >= len(shard_indices) {
        // English textloadEnglish text
        loader.current_shard_docs = []jsonl_document{cap: 0}
        return
    }

    int shard_id = shard_indices[loader.current_shard_idx]

    // English textfilepath
    string filepath = loader.config.data_dir + "/shard_" + int_to_string(shard_id) + ".jsonl"

    // English text JSONL file
    []jsonl_document docs = read_jsonl_file(filepath)

    loader.current_shard_docs = docs
    loader.current_doc_idx = 0
    loader.current_shard_idx = loader.current_shard_idx + 1
}

// ============================================================================
// 7. datastatistics
// ============================================================================

// English textloadEnglish textstatisticsinformation
func get_loader_stats(jsonl_data_loader loader) string {

    string stats = "JSONL Loader Stats:\n"
    stats = stats + "  Total tokens processed: " + long_to_string(loader.total_tokens_processed) + "\n"
    stats = stats + "  Batches generated: " + int_to_string(loader.num_batches_generated) + "\n"
    stats = stats + "  Current shard: " + int_to_string(loader.current_shard_idx) + "\n"

    stats
}

// ============================================================================
// 8. toolfunction
// ============================================================================

func append_int([]int arr, int val) []int {
    []int out = []int{cap: len(arr) + 1}
    int i = 0
    while i < len(arr) {
        out.push(arr[i])
        i = i + 1
    }
    out.push(val)
    out
}

func append_string([]string arr, string val) []string {
    []string out = []string{cap: len(arr) + 1}
    int i = 0
    while i < len(arr) {
        out.push(arr[i])
        i = i + 1
    }
    out.push(val)
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
    while value > 0 {
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
    []string lines = []string{cap: 0}
    string current = ""
    int i = 0
    while i < len(text) {
        string ch = neurx.strings.substring(text, i, i + 1)
        if ch == "\n" || ch == "\r" {
            if len(current) > 0 {
                lines.push(current)
                current = ""
            }
        } else {
            current = neurx.strings.concat2(current, ch)
        }
        i = i + 1
    }
    if len(current) > 0 {
        lines.push(current)
    }
    lines
}

func trim_string(string text) string {
    int left = 0
    int right = len(text) - 1
    while left < len(text) {
        string ch = neurx.strings.substring(text, left, left + 1)
        if ch != " " && ch != "\t" && ch != "\n" && ch != "\r" {
            break
        }
        left = left + 1
    }
    while right >= left {
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
    while i < len(json_line) {
        string ch = neurx.strings.substring(json_line, i, i + 1)
        if ch == ":" {
            i = i + 1
            break
        }
        i = i + 1
    }
    while i < len(json_line) {
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
    while i < len(json_line) {
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
    while i + len(pattern) <= len(text) {
        int j = 0
        while j < len(pattern) {
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
    []string vocab = []string{cap: 0}
    vocab.push("<pad>")
    vocab.push("<bos>")
    vocab.push("<eos>")
    vocab.push("<unk>")
    int c = 32
    while c <= 126 {
        vocab.push(string(c))
        c = c + 1
    }
    vocab.push("\n")
    vocab.push("\t")
    vocab
}
