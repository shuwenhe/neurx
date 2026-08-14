
import "../types"
import "../tokenizer"
import "../huggingface_tokenizer"
import "../special_tokens"
import "../cache"
import "../utils"

func MultiSentenceEncodingExample() {
    println("\n=== Multi-Sentence Encoding Example ===\n")

    config := types.TokenizerConfig{
        model_name: "bert-base-uncased",
        tokenizer_type: types.TokenizerType.HUGGINGFACE,
        vocab_size: 30522,
        lowercase: true,
    }

    hf_tokenizer := huggingface_tokenizer.NewHFTokenizer(config, "./models/bert-base")

    hf_tokenizer.base.vocab_text_to_id["hello"] = 7592
    hf_tokenizer.base.vocab_text_to_id["world"] = 2088
    hf_tokenizer.base.vocab_text_to_id["how"] = 2129
    hf_tokenizer.base.vocab_text_to_id["are"] = 2054
    hf_tokenizer.base.vocab_text_to_id["you"] = 2017
    hf_tokenizer.base.vocab_text_to_id["[CLS]"] = 101
    hf_tokenizer.base.vocab_text_to_id["[SEP]"] = 102

    text_a := "Hello world"
    text_b := "How are you"

    result := hf_tokenizer.EncodeMultiSentences(text_a, text_b)

    println("Text A:", text_a)
    println("Text B:", text_b)
    println("Encoded tokens (A + [SEP] + B):", result.tokens)
    println("Total sequence length:", len(result.tokens))
}

func PaddingTruncationExample() {
    println("\n=== Padding and Truncation Example ===\n")

    config := types.TokenizerConfig{
        model_name: "test-model",
        vocab_size: 30000,
        cache_enabled: false,
    }

    tokenizer_inst := tokenizer.NewBaseTokenizer(config)

    short_seq := make(vec[i32], 0)
    short_seq = append(short_seq, 1)
    short_seq = append(short_seq, 2)

    long_seq := make(vec[i32], 0)
    for i := 0; i < 20; i += 1 {
        long_seq = append(long_seq, i32(i+1))
    }

    padded := utils.PadSequence(short_seq, 10, 0)
    println("Short sequence padded to 10:")
    println("  Original:", len(short_seq))
    println("  Padded:", len(padded))

    truncated := utils.TruncateSequence(long_seq, 10)
    println("\nLong sequence truncated to 10:")
    println("  Original:", len(long_seq))
    println("  Truncated:", len(truncated))

    sequences := make(vec[vec[i32]], 0)
    sequences = append(sequences, short_seq)
    sequences = append(sequences, long_seq)

    batch_padded := utils.PadBatch(sequences, 0)
    println("\nBatch padding:")
    println("  Sequences:", len(sequences))
    lengths := utils.GetBatchLengths(batch_padded)
    println("  Lengths after padding:", lengths)
}

func CachePerformanceExample() {
    println("\n=== Cache Performance Analysis ===\n")

    cache_lru := cache.NewTokenCache(100000, "lru")
    cache_lfu := cache.NewTokenCache(100000, "lfu")

    texts := make(vec[string], 0)
    texts = append(texts, "hello world")
    texts = append(texts, "hello there")
    texts = append(texts, "goodbye world")
    texts = append(texts, "hello world")
    texts = append(texts, "hello world")

    for i := 0; i < len(texts); i += 1 {
        tokens := make(vec[i32], 0)
        for j := 0; j < 5; j += 1 {
            tokens = append(tokens, i32(j+1))
        }
        cache_lru.Put(texts[i], tokens)
    }

    cache_lru.Get("hello world")
    cache_lru.Get("hello world")
    cache_lru.Get("unknown")

    println("LRU Cache Performance:")
    println("  Hit Rate:", cache_lru.GetHitRate(), "%")
    println("  Utilization:", cache_lru.GetUtilization(), "%")
    println("  Entries:", cache_lru.GetEntryCount())

    lru_stats := cache_lru.GetStatistics()
    println("  Hits:", lru_stats.total_hits)
    println("  Misses:", lru_stats.total_misses)
    println("  Evictions:", lru_stats.total_evictions)
}

func SpecialTokenProcessingExample() {
    println("\n=== Special Token Processing Example ===\n")

    mgr := special_tokens.NewSpecialTokenManager()

    tokens := make(vec[i32], 0)
    tokens = append(tokens, 2)
    tokens = append(tokens, 7592)
    tokens = append(tokens, 2088)
    tokens = append(tokens, 3)
    tokens = append(tokens, 7592)
    tokens = append(tokens, 1)

    println("Original sequence length:", len(tokens))

    no_special := mgr.RemoveSpecialTokens(tokens)
    println("After removing special tokens:", len(no_special))

    only_special := mgr.KeepOnlySpecialTokens(tokens)
    println("Only special tokens:", len(only_special))

    special_mask := mgr.CreateSpecialTokenMask(tokens)
    println("Special token mask created")

    replaced := mgr.ReplaceSpecialTokens(tokens, 0)
    println("Special tokens replaced with ID 0")

    instruction_count := mgr.CountSpecialTokensByType(tokens, "instruction")
    boundary_count := mgr.CountSpecialTokensByType(tokens, "boundary")
    println("Instruction tokens:", instruction_count)
    println("Boundary tokens:", boundary_count)
}

func TokenSequenceAnalysisExample() {
    println("\n=== Token Sequence Analysis Example ===\n")

    tokens := make(vec[i32], 0)
    tokens = append(tokens, 1)
    tokens = append(tokens, 2)
    tokens = append(tokens, 3)
    tokens = append(tokens, 2)
    tokens = append(tokens, 1)
    tokens = append(tokens, 4)
    tokens = append(tokens, 2)
    tokens = append(tokens, 1)

    println("Sequence length:", utils.GetSequenceLength(tokens))
    println("Unique tokens:", utils.GetUniqueTokenCount(tokens))

    freq := utils.GetTokenFrequency(tokens)
    println("Token 1 frequency:", freq[1])
    println("Token 2 frequency:", freq[2])

    top_tokens := utils.GetMostFrequentTokens(tokens, 3)
    println("Top 3 most frequent tokens:", top_tokens)

    entropy := utils.GetTokenEntropy(tokens)
    println("Sequence entropy:", entropy)

    stats := utils.GetSequenceStats(tokens)
    println("Statistics:")
    println("  Min token:", stats["min_token"])
    println("  Max token:", stats["max_token"])
    println("  Avg token value:", stats["avg_token_value"])
    println("  Diversity ratio:", stats["diversity_ratio"])
}

func EncodingOptionsExample() {
    println("\n=== Encoding Options Example ===\n")

    config := types.TokenizerConfig{
        model_name: "test-model",
        vocab_size: 30000,
        add_bos: false,
        add_eos: false,
    }

    tokenizer_inst := tokenizer.NewBaseTokenizer(config)

    tokenizer_inst.vocab_text_to_id["hello"] = 1
    tokenizer_inst.vocab_text_to_id["world"] = 2

    opts1 := types.EncodingOptions{
        add_special_tokens: true,
        max_length: 10,
        padding: "max_length",
        truncation: true,
    }
    result1 := tokenizer_inst.EncodeWithOptions("hello world", opts1)
    println("With special tokens and padding:")
    println("  Tokens:", result1.tokens)
    println("  Length:", len(result1.tokens))

    opts2 := types.EncodingOptions{
        add_special_tokens: false,
        truncation: false,
        return_attention_mask: true,
    }
    result2 := tokenizer_inst.EncodeWithOptions("hello world", opts2)
    println("\nWithout special tokens:")
    println("  Tokens:", result2.tokens)
    println("  Length:", len(result2.tokens))
}

func PerformanceBenchmarkingExample() {
    println("\n=== Performance Benchmarking Example ===\n")

    config := types.TokenizerConfig{
        model_name: "test-model",
        vocab_size: 30000,
        cache_enabled: true,
        cache_size: 100000,
    }

    tokenizer_inst := tokenizer.NewBaseTokenizer(config)

    texts := make(vec[string], 0)
    texts = append(texts, "Hello world")
    texts = append(texts, "How are you")
    texts = append(texts, "Hello world")

    for i := 0; i < len(texts); i += 1 {
        _ = tokenizer_inst.Encode(texts[i])
    }

    stats := tokenizer_inst.GetStatistics()
    println("Encoding Statistics:")
    println("  Total encodings:", stats.total_encodings)
    println("  Total decodings:", stats.total_decodings)
    println("  Bytes processed:", stats.bytes_processed)
    println("  Cache hits:", stats.cache_hits)
    println("  Cache misses:", stats.cache_misses)
    println("  Avg tokens per sequence:", stats.avg_tokens_per_sequence)
}

func main() {
    println("╔════════════════════════════════════════════════════════════╗")
    println("║         NeurX Tokenizers - Advanced Examples              ║")
    println("╚════════════════════════════════════════════════════════════╝")

    MultiSentenceEncodingExample()
    PaddingTruncationExample()
    CachePerformanceExample()
    SpecialTokenProcessingExample()
    TokenSequenceAnalysisExample()
    EncodingOptionsExample()
    PerformanceBenchmarkingExample()

    println("\n=== All advanced examples completed ===\n")
}
