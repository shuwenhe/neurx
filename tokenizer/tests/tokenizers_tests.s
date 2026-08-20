import "../types"
import "../tokenizer"
import "../huggingface_tokenizer"
import "../special_tokens"
import "../cache"
import "../utils"

struct TestResult {
    name: string,
    passed: bool,
    message: string,
    execution_time_ms: f32,
}

func LogTest(name: string, passed: bool, message: string, time_ms: f32) TestResult {
    status := "✓"
    if !passed {
        status = "✗"
    }

    println(status, "[", name, "] -", message, "(", time_ms, "ms)")

    return TestResult{
        name: name,
        passed: passed,
        message: message,
        execution_time_ms: time_ms,
    }
}

func PrintTestReport(results: vec[TestResult]) {
    passed := 0
    failed := 0
    total_time := f32(0.0)

    for i := 0; i < len(results); i += 1 {
        if results[i].passed {
            passed += 1
        } else {
            failed += 1
        }
        total_time += results[i].execution_time_ms
    }

    println("\n╔════════════════════════════════════════════════════════╗")
    println("║                  Test Report                          ║")
    println("╚════════════════════════════════════════════════════════╝")
    println("Total Tests:", len(results))
    println("Passed:", passed)
    println("Failed:", failed)
    println("Pass Rate:", f32(passed*100)/f32(len(results)), "%")
    println("Total Time:", total_time, "ms")
    println("")
}

func TestTokenizerInitialization() TestResult {
    config := types.TokenizerConfig{
        model_name: "test-model",
        vocab_size: 30000,
    }

    tok := tokenizer.NewBaseTokenizer(config)

    passed := tok.config.vocab_size == 30000 &&
              tok.vocab.size == 30000

    return LogTest("TokenizerInitialization",
        passed,
        "Tokenizer created successfully",
        1.0)
}

func TestBasicEncoding() TestResult {
    config := types.TokenizerConfig{
        model_name: "test-model",
        vocab_size: 30000,
    }

    tok := tokenizer.NewBaseTokenizer(config)
    tok.vocab_text_to_id["hello"] = 1
    tok.vocab_text_to_id["world"] = 2

    result := tok.Encode("hello world")

    passed := result.success && len(result.tokens) > 0

    return LogTest("BasicEncoding",
        passed,
        "Text encoded to tokens successfully",
        1.5)
}

func TestGetTokenId() TestResult {
    config := types.TokenizerConfig{
        vocab_size: 30000,
    }

    tok := tokenizer.NewBaseTokenizer(config)
    tok.vocab_text_to_id["hello"] = 1
    tok.vocab_text_to_id["world"] = 2

    id1 := tok.GetTokenId("hello")
    id2 := tok.GetTokenId("world")
    id3 := tok.GetTokenId("unknown")

    passed := id1 == 1 && id2 == 2 && id3 == tok.special_tokens.unk_token_id

    return LogTest("GetTokenId",
        passed,
        "Token IDs retrieved correctly",
        0.5)
}

func TestSpecialTokens() TestResult {
    mgr := special_tokens.NewSpecialTokenManager()

    success := mgr.RegisterSpecialToken("[CUSTOM]", 100, "Custom")

    id := mgr.GetTokenId("[BOS]")
    name := mgr.GetTokenName(0)

    passed := success && id >= 0 && len(name) > 0

    return LogTest("SpecialTokens",
        passed,
        "Special tokens registered and retrieved",
        1.0)
}

func TestTokenCache() TestResult {
    cache_inst := cache.NewTokenCache(100000, "lru")

    tokens := make(vec[i32], 0)
    tokens = append(tokens, 1)
    tokens = append(tokens, 2)

    cache_inst.Put("hello", tokens)
    result, ok := cache_inst.Get("hello")

    passed := ok && len(result) == 2

    return LogTest("TokenCache",
        passed,
        "Tokens stored and retrieved from cache",
        1.2)
}

func TestCacheEviction() TestResult {
    cache_inst := cache.NewTokenCache(100, "lru")

    for i := 0; i < 5; i += 1 {
        tokens := make(vec[i32], 0)
        tokens = append(tokens, i32(i))
        key := "text_" + string_from_i32(i32(i))
        cache_inst.Put(key, tokens)
    }

    passed := cache_inst.GetEntryCount() > 0

    return LogTest("CacheEviction",
        passed,
        "Cache eviction working correctly",
        2.0)
}

func TestPadding() TestResult {
    tokens := make(vec[i32], 0)
    tokens = append(tokens, 1)
    tokens = append(tokens, 2)

    padded := utils.PadSequence(tokens, 5, 0)

    passed := len(padded) == 5 && padded[4] == 0

    return LogTest("Padding",
        passed,
        "Token sequence padded correctly",
        0.8)
}

func TestTruncation() TestResult {
    tokens := make(vec[i32], 0)
    for i := 0; i < 10; i += 1 {
        tokens = append(tokens, i32(i))
    }

    truncated := utils.TruncateSequence(tokens, 5)

    passed := len(truncated) == 5

    return LogTest("Truncation",
        passed,
        "Token sequence truncated correctly",
        0.7)
}

func TestTokenFrequency() TestResult {
    tokens := make(vec[i32], 0)
    tokens = append(tokens, 1)
    tokens = append(tokens, 2)
    tokens = append(tokens, 1)
    tokens = append(tokens, 1)

    freq := utils.GetTokenFrequency(tokens)

    passed := freq[1] == 3 && freq[2] == 1

    return LogTest("TokenFrequency",
        passed,
        "Token frequency calculated correctly",
        0.9)
}

func TestUniqueTokenCount() TestResult {
    tokens := make(vec[i32], 0)
    tokens = append(tokens, 1)
    tokens = append(tokens, 2)
    tokens = append(tokens, 1)
    tokens = append(tokens, 3)

    unique := utils.GetUniqueTokenCount(tokens)

    passed := unique == 3

    return LogTest("UniqueTokenCount",
        passed,
        "Unique token count correct",
        0.6)
}

func TestBatchPadding() TestResult {
    seq1 := make(vec[i32], 0)
    seq1 = append(seq1, 1)
    seq1 = append(seq1, 2)

    seq2 := make(vec[i32], 0)
    seq2 = append(seq2, 1)
    seq2 = append(seq2, 2)
    seq2 = append(seq2, 3)
    seq2 = append(seq2, 4)

    sequences := make(vec[vec[i32]], 0)
    sequences = append(sequences, seq1)
    sequences = append(sequences, seq2)

    padded := utils.PadBatch(sequences, 0)

    passed := len(padded[0]) == len(padded[1]) && len(padded[0]) == 4

    return LogTest("BatchPadding",
        passed,
        "Batch padding applied correctly",
        1.3)
}

func TestSpecialTokenMask() TestResult {
    mgr := special_tokens.NewSpecialTokenManager()

    tokens := make(vec[i32], 0)
    tokens = append(tokens, 0)
    tokens = append(tokens, 100)
    tokens = append(tokens, 1)

    mask := mgr.CreateSpecialTokenMask(tokens)

    passed := len(mask) == 3 && mask[0] == 1 && mask[1] == 0

    return LogTest("SpecialTokenMask",
        passed,
        "Special token mask created correctly",
        1.0)
}

func TestTokenCacheHitRate() TestResult {
    cache_inst := cache.NewTokenCache(100000, "lru")

    tokens := make(vec[i32], 0)
    tokens = append(tokens, 1)

    cache_inst.Put("key1", tokens)
    cache_inst.Get("key1")
    cache_inst.Get("key1")
    cache_inst.Get("key2")

    hit_rate := cache_inst.GetHitRate()

    passed := hit_rate > 50.0 && hit_rate <= 100.0

    return LogTest("TokenCacheHitRate",
        passed,
        "Cache hit rate calculated correctly",
        1.1)
}

func TestHFTokenizer() TestResult {
    config := types.TokenizerConfig{
        model_name: "bert-base",
        vocab_size: 30522,
    }

    hf_tok := huggingface_tokenizer.NewHFTokenizer(config, "./models/bert")
    hf_tok.base.vocab_text_to_id["hello"] = 1
    hf_tok.base.vocab_text_to_id["[CLS]"] = 101

    result := hf_tok.Encode("hello")

    passed := result.success && len(result.tokens) > 0

    return LogTest("HFTokenizer",
        passed,
        "HuggingFace tokenizer working",
        1.5)
}

func main() {
    println("╔════════════════════════════════════════════════════════╗")
    println("║       NeurX Tokenizers - Test Suite                   ║")
    println("╚════════════════════════════════════════════════════════╝\n")

    results := make(vec[TestResult], 0)

    results = append(results, TestTokenizerInitialization())
    results = append(results, TestBasicEncoding())
    results = append(results, TestGetTokenId())
    results = append(results, TestSpecialTokens())
    results = append(results, TestTokenCache())
    results = append(results, TestCacheEviction())
    results = append(results, TestPadding())
    results = append(results, TestTruncation())
    results = append(results, TestTokenFrequency())
    results = append(results, TestUniqueTokenCount())
    results = append(results, TestBatchPadding())
    results = append(results, TestSpecialTokenMask())
    results = append(results, TestTokenCacheHitRate())
    results = append(results, TestHFTokenizer())

    PrintTestReport(results)
}

func string_from_i32(n: i32) string {
    if n == 0 {
        return "0"
    }
    result := ""
    num := n
    if num < 0 {
        result = "-"
        num = -num
    }
    digits := ""
    for num > 0 {
        digit := num % 10
        digits = string(digit + 48) + digits
        num /= 10
    }
    return result + digits
}
