
import "../types"
import "../tokenizer"
import "../huggingface_tokenizer"
import "../special_tokens"
import "../cache"
import "../utils"

func BasicTokenizationExample() {
    println("\n=== Basic Tokenization Example ===\n")

    config := types.TokenizerConfig{
        model_name: "test-model",
        tokenizer_type: types.TokenizerType.HUGGINGFACE,
        vocab_size: 30000,
        max_token_length: 512,
        cache_enabled: true,
        cache_size: 10000,
        add_bos: true,
        add_eos: true,
    }

    tokenizer_inst := tokenizer.NewBaseTokenizer(config)

    tokenizer_inst.vocab_text_to_id["hello"] = 1
    tokenizer_inst.vocab_text_to_id["world"] = 2
    tokenizer_inst.vocab_id_to_text[1] = "hello"
    tokenizer_inst.vocab_id_to_text[2] = "world"

    text := "hello world"
    result := tokenizer_inst.Encode(text)

    println("Input text:", text)
    println("Encoded tokens:", result.tokens)
    println("Success:", result.success)
    println("Error code:", result.error_code)
}

func HuggingFaceTokenizerExample() {
    println("\n=== HuggingFace Tokenizer Example ===\n")

    config := types.TokenizerConfig{
        model_name: "bert-base-uncased",
        tokenizer_type: types.TokenizerType.HUGGINGFACE,
        vocab_size: 30522,
        cache_enabled: true,
        cache_size: 50000,
        lowercase: true,
        add_bos: false,
        add_eos: false,
    }

    hf_tokenizer := huggingface_tokenizer.NewHFTokenizer(config, "./models/bert-base")

    hf_tokenizer.LoadVocabulary("./vocab.txt")

    hf_tokenizer.base.vocab_text_to_id["hello"] = 7592
    hf_tokenizer.base.vocab_text_to_id["world"] = 2088
    hf_tokenizer.base.vocab_text_to_id["[CLS]"] = 101
    hf_tokenizer.base.vocab_text_to_id["[SEP]"] = 102

    text := "Hello world"
    result := hf_tokenizer.Encode(text)

    println("Model:", config.model_name)
    println("Input:", text)
    println("Tokens:", result.tokens)

    decoded := hf_tokenizer.Decode(result.tokens)
    println("Decoded:", decoded)
}

func SpecialTokensExample() {
    println("\n=== Special Tokens Management Example ===\n")

    mgr := special_tokens.NewSpecialTokenManager()

    mgr.RegisterSpecialToken("[CUSTOM]", 100, "Custom Token")

    tokens := make(vec[i32], 0)
    tokens = append(tokens, 1)
    tokens = append(tokens, 7592)
    tokens = append(tokens, 2)
    tokens = append(tokens, 7592)
    tokens = append(tokens, 1)

    special_count := mgr.CountSpecialTokensInSequence(tokens)
    mask := mgr.CreateSpecialTokenMask(tokens)

    println("Total tokens:", len(tokens))
    println("Special tokens count:", special_count)
    println("Special token mask:", mask)

    all_special := mgr.GetAllSpecialTokens()
    println("Total special token types:", len(all_special))
}

func TokenCachingExample() {
    println("\n=== Token Caching Example ===\n")

    cache_inst := cache.NewTokenCache(100000, "lru")

    text1 := "Hello world"
    tokens1 := make(vec[i32], 0)
    tokens1 = append(tokens1, 1)
    tokens1 = append(tokens1, 2)

    text2 := "Hello there"
    tokens2 := make(vec[i32], 0)
    tokens2 = append(tokens2, 1)
    tokens2 = append(tokens2, 3)

    cache_inst.Put(text1, tokens1)
    cache_inst.Put(text2, tokens2)

    if result, ok := cache_inst.Get(text1); ok {
        println("Cache HIT for:", text1)
        println("Cached tokens:", result)
    }

    if _, ok := cache_inst.Get("unknown text"); !ok {
        println("Cache MISS for: unknown text")
    }

    println("\nCache Statistics:")
    println("  Hit Rate:", cache_inst.GetHitRate(), "%")
    println("  Utilization:", cache_inst.GetUtilization(), "%")
    println("  Entries:", cache_inst.GetEntryCount())
}

func BatchProcessingExample() {
    println("\n=== Batch Processing Example ===\n")

    config := types.TokenizerConfig{
        model_name: "test-model",
        tokenizer_type: types.TokenizerType.HUGGINGFACE,
        vocab_size: 30000,
        cache_enabled: false,
        add_bos: true,
        add_eos: true,
    }

    tokenizer_inst := tokenizer.NewBaseTokenizer(config)

    texts := make(vec[string], 0)
    texts = append(texts, "first text")
    texts = append(texts, "second text")
    texts = append(texts, "third text")

    results := tokenizer_inst.EncodeBatch(texts)

    println("Batch processing:")
    println("  Texts:", len(texts))
    println("  Results:", len(results))

    for i := 0; i < len(results); i += 1 {
        println("  Text", i, "tokens:", len(results[i].tokens))
    }
}

func UtilityFunctionsExample() {
    println("\n=== Utility Functions Example ===\n")

    tokens := make(vec[i32], 0)
    tokens = append(tokens, 1)
    tokens = append(tokens, 2)
    tokens = append(tokens, 2)
    tokens = append(tokens, 3)
    tokens = append(tokens, 1)

    freq := utils.GetTokenFrequency(tokens)
    println("Token frequency calculated")

    unique := utils.GetUniqueTokenCount(tokens)
    println("Unique tokens:", unique)

    entropy := utils.GetTokenEntropy(tokens)
    println("Entropy:", entropy)

    stats := utils.GetSequenceStats(tokens)
    println("Sequence length:", stats["length"])
    println("Diversity ratio:", stats["diversity_ratio"])

    padded := utils.PadSequence(tokens, 10, 0)
    println("Original length:", len(tokens))
    println("Padded length:", len(padded))
}

func main() {
    println("╔════════════════════════════════════════════════════════════╗")
    println("║         NeurX Tokenizers - Basic Examples                 ║")
    println("╚════════════════════════════════════════════════════════════╝")

    BasicTokenizationExample()
    HuggingFaceTokenizerExample()
    SpecialTokensExample()
    TokenCachingExample()
    BatchProcessingExample()
    UtilityFunctionsExample()

    println("\n=== All examples completed ===\n")
}
