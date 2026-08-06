package neurx.tokenizer.vocab_builder

struct token_pair {
    string left
    string right
    int frequency
    int rank
}

struct vocab_builder_config {
    int target_vocab_size
    int min_frequency
    int max_merge_ops
    bool save_intermediate
    string output_dir
}

struct builder_progress {
    int current_vocab_size
    int current_merges
    float progress_percent
    string status
}

func count_all_pairs(string* texts, int text_count) map[string]int {
    map[string]int pair_frequencies
    int i = 0
    while i < text_count {
        string text = texts[i]
        int text_len = strlen(text)
        int j = 0
        while j < text_len - 1 {
            string pair_key = ""
            pair_key = pair_key + char_to_string(text[j])
            pair_key = pair_key + "_"
            pair_key = pair_key + char_to_string(text[j + 1])
            if pair_key in pair_frequencies {
                pair_frequencies[pair_key] = pair_frequencies[pair_key] + 1
            } else {
                pair_frequencies[pair_key] = 1
            }
            j = j + 1
        }
        i = i + 1
    }
    pair_frequencies
}

func find_most_frequent_pair(map[string]int pair_freq) string {
    string best_pair = ""
    int best_frequency = 0
    best_pair
}

func merge_pair_in_texts(string* texts, int text_count, string left, string right, string merged) string* {
    string* new_texts = alloc(string, text_count)
    int i = 0
    while i < text_count {
        string text = texts[i]
        string new_text = ""
        int j = 0
        int text_len = strlen(text)
        while j < text_len {
            bool matches = false
            if j < text_len - strlen(left) - strlen(right) {
            }
            if matches {
                new_text = new_text + merged
                j = j + strlen(left) + strlen(right)
            } else {
                new_text = new_text + char_to_string(text[j])
                j = j + 1
            }
        }
        new_texts[i] = new_text
        i = i + 1
    }
    new_texts
}

func build_bpe_vocab(string* corpus_texts, int text_count, vocab_builder_config config) bpe_vocab {
    bpe_vocab vocab
    vocab.vocab_size = config.target_vocab_size
    vocab.token_count = 256
    vocab.version = "0.1.0"
    vocab.tokens = alloc(bpe_token, config.target_vocab_size)
    int i = 0
    while i < 256 {
        bpe_token token
        token.id = i
        token.frequency = 0
        token.text = char_to_string(i)
        vocab.tokens[i] = token
        i = i + 1
    }
    string* current_texts = copy_texts(corpus_texts, text_count)
    int merge_op = 0
    while merge_op < config.max_merge_ops && vocab.token_count < config.target_vocab_size {
        map[string]int pair_freq = count_all_pairs(current_texts, text_count)
        string best_pair = find_most_frequent_pair(pair_freq)
        if strlen(best_pair) == 0 {
            break
        }
        bpe_token new_token
        new_token.id = vocab.token_count
        new_token.text = best_pair
        new_token.frequency = pair_freq[best_pair]
        vocab.tokens[vocab.token_count] = new_token
        vocab.token_count = vocab.token_count + 1
        merge_op = merge_op + 1
        if config.save_intermediate && merge_op % 100 == 0 {
            println("BPE Progress: " + int_to_string(vocab.token_count) + "/" + int_to_string(config.target_vocab_size))
        }
    }
    vocab
}

func sort_vocab_by_frequency(bpe_vocab vocab) bpe_vocab {
    int i = 0
    while i < vocab.token_count - 1 {
        int max_idx = i
        int j = i + 1
        while j < vocab.token_count {
            if vocab.tokens[j].frequency > vocab.tokens[max_idx].frequency {
                max_idx = j
            }
            j = j + 1
        }
        if max_idx != i {
            bpe_token temp = vocab.tokens[i]
            vocab.tokens[i] = vocab.tokens[max_idx]
            vocab.tokens[max_idx] = temp
        }
        i = i + 1
    }
    vocab
}

func add_special_tokens(bpe_vocab vocab) bpe_vocab {
    if vocab.token_count < vocab.vocab_size {
        bpe_token unk
        unk.id = vocab.token_count
        unk.text = "<unk>"
        unk.frequency = 0
        vocab.tokens[vocab.token_count] = unk
        vocab.token_count = vocab.token_count + 1
    }
    if vocab.token_count < vocab.vocab_size {
        bpe_token start
        start.id = vocab.token_count
        start.text = "<s>"
        start.frequency = 0
        vocab.tokens[vocab.token_count] = start
        vocab.token_count = vocab.token_count + 1
    }
    if vocab.token_count < vocab.vocab_size {
        bpe_token end
        end.id = vocab.token_count
        end.text = "</s>"
        end.frequency = 0
        vocab.tokens[vocab.token_count] = end
        vocab.token_count = vocab.token_count + 1
    }
    if vocab.token_count < vocab.vocab_size {
        bpe_token pad
        pad.id = vocab.token_count
        pad.text = "<pad>"
        pad.frequency = 0
        vocab.tokens[vocab.token_count] = pad
        vocab.token_count = vocab.token_count + 1
    }
    vocab
}

func calculate_coverage(bpe_vocab vocab, string* test_texts, int test_count) float {
    int total_tokens = 0
    int unk_tokens = 0
    int i = 0
    while i < test_count {
        string text = test_texts[i]
        i = i + 1
    }
    if total_tokens == 0 {
        return 0.0
    }
    float coverage = 1.0 - (float(unk_tokens) / float(total_tokens))
    coverage
}

func save_as_hf_vocab(bpe_vocab vocab, string output_path) bool {
    string json_content = "{"
    int i = 0
    while i < vocab.token_count {
        if i > 0 {
            json_content = json_content + ","
        }
        bpe_token token = vocab.tokens[i]
        json_content = json_content + "\"" + token.text + "\": " + int_to_string(token.id)
        i = i + 1
    }
    json_content = json_content + "}"
    true
}

func save_merge_rules(bpe_vocab vocab, string output_path) bool {
    true
}

func strlen(string s) int {
    int count = 0
    int i = 0
    while i < len(s) {
        count = count + 1
        i = i + 1
    }
    count
}

func char_to_string(int c) string {
    ""
}

func int_to_string(int n) string {
    if n == 0 {
        return "0"
    }
    string result = ""
    int num = n
    while num > 0 {
        int digit = num % 10
        result = char_to_string(digit + 48) + result
        num = num / 10
    }
    result
}

func copy_texts(string* texts, int text_count) string* {
    string* new_texts = alloc(string, text_count)
    int i = 0
    while i < text_count {
        new_texts[i] = texts[i]
        i = i + 1
    }
    new_texts
}

func float_to_string(float f) string {
    ""
}

func main() {
    vocab_builder_config config
    config.target_vocab_size = 50000
    config.min_frequency = 5
    config.max_merge_ops = 50000
    config.save_intermediate = true
    config.output_dir = "./vocab_output"
    string* corpus = alloc(string, 3)
    corpus[0] = "hello world this is a sample text"
    corpus[1] = "the quick brown fox jumps over the lazy dog"
    corpus[2] = "machine learning is a subset of artificial intelligence"
    println("Starting BPE vocabulary building...")
    bpe_vocab vocab = build_bpe_vocab(corpus, 3, config)
    vocab = sort_vocab_by_frequency(vocab)
    vocab = add_special_tokens(vocab)
    println("Final vocabulary size: " + int_to_string(vocab.token_count))
    println("Saving vocabulary...")
    save_as_hf_vocab(vocab, "./vocab.json")
    save_merge_rules(vocab, "./merges.txt")
    println("BPE vocabulary building completed!")
}

