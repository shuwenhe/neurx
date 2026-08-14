// NeurX Tokenizers - Basic Examples
// Demonstration of fundamental tokenization operations

import "../types"
import "../tokenizer"
import "../huggingface_tokenizer"
import "../special_tokens"
import "../cache"
import "../utils"

// ============================================================================
// Example 1: Basic Tokenization
// ============================================================================

func BasicTokenizationExample() {
    println("\n=== Basic Tokenization Example ===\n")
    
    // Create tokenizer configuration
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
    
    // Create tokenizer
    tokenizer_inst := tokenizer.NewBaseTokenizer(config)
    
    // Add some vocabulary entries (simplified)
    tokenizer_inst.vocab_text_to_id["hello"] = 1
    tokenizer_inst.vocab_text_to_id["world"] = 2
    tokenizer_inst.vocab_id_to_text[1] = "hello"
    tokenizer_inst.vocab_id_to_text[2] = "world"
    
    // Encode text
    text := "hello world"
    result := tokenizer_inst.Encode(text)
    
    println("Input text:", text)
    println("Encoded tokens:", result.tokens)
    println("Success:", result.success)
    println("Error code:", result.error_code)
}

// ============================================================================
// Example 2: HuggingFace Tokenizer
// ============================================================================

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
    
    // Create HF tokenizer
    hf_tokenizer := huggingface_tokenizer.NewHFTokenizer(config, "./models/bert-base")
    
    // Load vocabulary
    hf_tokenizer.LoadVocabulary("./vocab.txt")
    
    // Set up basic vocabulary
    hf_tokenizer.base.vocab_text_to_id["hello"] = 7592
    hf_tokenizer.base.vocab_text_to_id["world"] = 2088
    hf_tokenizer.base.vocab_text_to_id["[CLS]"] = 101
    hf_tokenizer.base.vocab_text_to_id["[SEP]"] = 102
    
    // Encode text
    text := "Hello world"
    result := hf_tokenizer.Encode(text)
    
    println("Model:", config.model_name)
    println("Input:", text)
    println("Tokens:", result.tokens)
    
    // Decode
    decoded := hf_tokenizer.Decode(result.tokens)
    println("Decoded:", decoded)
}

// ============================================================================
// Example 3: Special Tokens Management
// ============================================================================

func SpecialTokensExample() {
    println("\n=== Special Tokens Management Example ===\n")
    
    // Create special token manager
    mgr := special_tokens.NewSpecialTokenManager()
    
    // Register custom token
    mgr.RegisterSpecialToken("[CUSTOM]", 100, "Custom Token")
    
    // Create token sequence
    tokens := make(vec[i32], 0)
    tokens = append(tokens, 1)    // BOS
    tokens = append(tokens, 7592) // "hello"
    tokens = append(tokens, 2)    // SEP
    tokens = append(tokens, 7592) // "world"
    tokens = append(tokens, 1)    // EOS
    
    // Analyze special tokens
    special_count := mgr.CountSpecialTokensInSequence(tokens)
    mask := mgr.CreateSpecialTokenMask(tokens)
    
    println("Total tokens:", len(tokens))
    println("Special tokens count:", special_count)
    println("Special token mask:", mask)
    
    // Get all special tokens
    all_special := mgr.GetAllSpecialTokens()
    println("Total special token types:", len(all_special))
}

// ============================================================================
// Example 4: Token Caching
// ============================================================================

func TokenCachingExample() {
    println("\n=== Token Caching Example ===\n")
    
    // Create cache with LRU eviction
    cache_inst := cache.NewTokenCache(100000, "lru")
    
    // Create some token sequences
    text1 := "Hello world"
    tokens1 := make(vec[i32], 0)
    tokens1 = append(tokens1, 1)
    tokens1 = append(tokens1, 2)
    
    text2 := "Hello there"
    tokens2 := make(vec[i32], 0)
    tokens2 = append(tokens2, 1)
    tokens2 = append(tokens2, 3)
    
    // Cache the tokens
    cache_inst.Put(text1, tokens1)
    cache_inst.Put(text2, tokens2)
    
    // Test cache hit
    if result, ok := cache_inst.Get(text1); ok {
        println("Cache HIT for:", text1)
        println("Cached tokens:", result)
    }
    
    // Test cache miss
    if _, ok := cache_inst.Get("unknown text"); !ok {
        println("Cache MISS for: unknown text")
    }
    
    // Print statistics
    println("\nCache Statistics:")
    println("  Hit Rate:", cache_inst.GetHitRate(), "%")
    println("  Utilization:", cache_inst.GetUtilization(), "%")
    println("  Entries:", cache_inst.GetEntryCount())
}

// ============================================================================
// Example 5: Batch Processing
// ============================================================================

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
    
    // Create batch of texts
    texts := make(vec[string], 0)
    texts = append(texts, "first text")
    texts = append(texts, "second text")
    texts = append(texts, "third text")
    
    // Process batch
    results := tokenizer_inst.EncodeBatch(texts)
    
    println("Batch processing:")
    println("  Texts:", len(texts))
    println("  Results:", len(results))
    
    for i := 0; i < len(results); i += 1 {
        println("  Text", i, "tokens:", len(results[i].tokens))
    }
}

// ============================================================================
// Example 6: Utility Functions
// ============================================================================

func UtilityFunctionsExample() {
    println("\n=== Utility Functions Example ===\n")
    
    // Create token sequence
    tokens := make(vec[i32], 0)
    tokens = append(tokens, 1)
    tokens = append(tokens, 2)
    tokens = append(tokens, 2)
    tokens = append(tokens, 3)
    tokens = append(tokens, 1)
    
    // Get frequency
    freq := utils.GetTokenFrequency(tokens)
    println("Token frequency calculated")
    
    // Get unique count
    unique := utils.GetUniqueTokenCount(tokens)
    println("Unique tokens:", unique)
    
    // Get entropy
    entropy := utils.GetTokenEntropy(tokens)
    println("Entropy:", entropy)
    
    // Get statistics
    stats := utils.GetSequenceStats(tokens)
    println("Sequence length:", stats["length"])
    println("Diversity ratio:", stats["diversity_ratio"])
    
    // Padding example
    padded := utils.PadSequence(tokens, 10, 0)
    println("Original length:", len(tokens))
    println("Padded length:", len(padded))
}

// ============================================================================
// Main Entry Point
// ============================================================================

func main() {
    println("╔════════════════════════════════════════════════════════════╗")
    println("║         NeurX Tokenizers - Basic Examples                 ║")
    println("╚════════════════════════════════════════════════════════════╝")
    
    // Run all examples
    BasicTokenizationExample()
    HuggingFaceTokenizerExample()
    SpecialTokensExample()
    TokenCachingExample()
    BatchProcessingExample()
    UtilityFunctionsExample()
    
    println("\n=== All examples completed ===\n")
}
