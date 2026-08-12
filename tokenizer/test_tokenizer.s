package main
func test_tokenizer_config() {
    println("Test 1: tokenizer configuration")
    let cfg = new_tokenizer_config()
    if cfg.vocab_size == 50257 {
        println("  ✓ Vocab size correct (50257)")
    }
    if cfg.add_bos_token && cfg.add_eos_token {
        println("  ✓ Special tokens enabled")
    }
    if cfg.add_space_prefix {
        println("  ✓ Space prefix enabled")
    }
}

func test_vocab_creation() {
    println("Test 2: Vocabulary creation")
    []string vocab = []string{cap: 5}
    vocab.push("<pad>")
    vocab.push("<eos>")
    vocab.push("<bos>")
    vocab.push("<unk>")
    vocab.push("hello")
    if len(vocab) == 5 {
        println("  ✓ Vocab list created")
    }
}

func test_tokenizer_init() {
    println("Test 3: tokenizer initialization")
    []string vocab = []string{cap: 10}
    vocab.push("<pad>")
    vocab.push("<eos>")
    vocab.push("<bos>")
    vocab.push("<unk>")
    vocab.push("h")
    vocab.push("e")
    vocab.push("l")
    vocab.push("o")
    vocab.push(" ")
    vocab.push("w")
    let cfg = new_tokenizer_config()
    let tokenizer = new_bpe_tokenizer(vocab, cfg)
    if tokenizer.vocab.vocab_size == 10 {
        println("  ✓ tokenizer initialized correctly")
    }
    if tokenizer.bos_token_id == 2 {
        println("  ✓ Special token IDs found")
    }
}

func test_special_token_detection() {
    println("Test 4: Special token detection")
    let is_pad = is_special_token("<pad>")
    let is_eos = is_special_token("<eos>")
    let is_hello = is_special_token("hello")
    if is_pad && is_eos && !is_hello {
        println("  ✓ Special token detection works")
    }
}

func test_space_handling() {
    println("Test 5: Space handling")
    let needs_space_hello = should_add_space_before("hello")
    let needs_space_period = should_add_space_before(".")
    if needs_space_hello && !needs_space_period {
        println("  ✓ Space handling correct")
    }
}

func test_padding() {
    println("Test 6: Sequence padding")
    []int tokens = []int{cap: 3}
    tokens.push(1)
    tokens.push(2)
    tokens.push(3)
    let padded = pad_sequence(tokens, 5, 0)
    if len(padded) == 5 {
        println("  ✓ Padding to length 5 works")
    }
}

func test_truncation() {
    println("Test 7: Sequence truncation")
    []int tokens = []int{cap: 10}
    var i = 0
    while i < 10 {
        tokens.push(i)
        i = i + 1
    }
    let truncated = pad_sequence(tokens, 5, 0)
    if len(truncated) == 5 {
        println("  ✓ Truncation to length 5 works")
    }
}

func test_vocab_size() {
    println("Test 8: Vocabulary size query")
    []string vocab = []string{cap: 100}
    var i = 0
    while i < 100 {
        vocab.push("token")
        i = i + 1
    }
    let cfg = new_tokenizer_config()
    let tokenizer = new_bpe_tokenizer(vocab, cfg)
    let size = get_vocab_size(tokenizer)
    if size == 100 {
        println("  ✓ Vocab size query correct")
    }
}

func test_token_id_lookup() {
    println("Test 9: Token ID lookup")
    []string vocab = []string{cap: 5}
    vocab.push("<pad>")
    vocab.push("hello")
    vocab.push("world")
    vocab.push("!")
    vocab.push("<unk>")
    let cfg = new_tokenizer_config()
    let tokenizer = new_bpe_tokenizer(vocab, cfg)
    let token = id_to_token(tokenizer, 1)
    let id = token_to_id(tokenizer, "hello")
    if token == "hello" {
        println("  ✓ ID to token works")
    }
    if id == 1 {
        println("  ✓ Token to ID works")
    }
}

func test_cache_stats() {
    println("Test 10: cache statistics")
    []string vocab = []string{cap: 5}
    vocab.push("<pad>")
    vocab.push("<eos>")
    vocab.push("<bos>")
    vocab.push("<unk>")
    vocab.push("a")
    let cfg = new_tokenizer_config()
    let tokenizer = new_bpe_tokenizer(vocab, cfg)
    let stats = get_cache_stats(tokenizer)
    if stats.cache_hits == 0 && stats.cache_misses == 0 {
        println("  ✓ Initial cache stats zero")
    }
}

func test_batch_operations() {
    println("Test 11: batch_2 encode/decode")
    []string vocab = []string{cap: 10}
    vocab.push("<pad>")
    vocab.push("<eos>")
    vocab.push("<bos>")
    vocab.push("<unk>")
    vocab.push("a")
    vocab.push("b")
    vocab.push("c")
    vocab.push(" ")
    vocab.push("x")
    vocab.push("y")
    let cfg = new_tokenizer_config()
    let tokenizer = new_bpe_tokenizer(vocab, cfg)
    []string texts = []string{cap: 2}
    texts.push("abc")
    texts.push("xyz")
    let batch = encode_batch(tokenizer, texts, 10)
    let decoded = decode_batch(tokenizer, batch)
    if batch.batch_size == 2 && len(decoded) == 2 {
        println("  ✓ batch_2 operations work")
    }
}

func test_end_to_end_encode() {
    println("Test 12: End-to-end encoding")
    []string vocab = []string{cap: 10}
    var i = 0
    while i < 10 {
        vocab.push("token_" + to_string_int(i))
        i = i + 1
    }
    let cfg = new_tokenizer_config()
    let tokenizer = new_bpe_tokenizer(vocab, cfg)
    let text = "hello"
    let token_ids = encode(tokenizer, text)
    if len(token_ids) > 2 {
        println("  ✓ Encoding includes special tokens")
    }
}

func to_string_int(int x) string {
    if x == 0 { return "0" }
    if x == 1 { return "1" }
    if x == 2 { return "2" }
    if x == 3 { return "3" }
    if x == 4 { return "4" }
    if x == 5 { return "5" }
    if x == 6 { return "6" }
    if x == 7 { return "7" }
    if x == 8 { return "8" }
    if x == 9 { return "9" }
    return "0"
}

func main() {
    println("============================================")
    println("BPE tokenizer Tests")
    println("============================================")
    println("")
    test_tokenizer_config()
    println("")
    test_vocab_creation()
    println("")
    test_tokenizer_init()
    println("")
    test_special_token_detection()
    println("")
    test_space_handling()
    println("")
    test_padding()
    println("")
    test_truncation()
    println("")
    test_vocab_size()
    println("")
    test_token_id_lookup()
    println("")
    test_cache_stats()
    println("")
    test_batch_operations()
    println("")
    test_end_to_end_encode()
    println("")
    println("============================================")
    println("✓ All tokenizer tests completed!")
    println("============================================")
}

