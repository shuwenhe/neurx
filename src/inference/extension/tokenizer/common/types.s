import "std/string"
import "std/vector"

    HUGGINGFACE,
    SENTENCEPIECE,
    TIKTOKEN,
    LLAMA,
    CUSTOM,
}

    NORMAL,
    SPECIAL,
    PADDING,
    UNKNOWN,
    SYSTEM,
}

struct Token {
    id: i32,
    text: string,
    token_class: TokenClass,
    special: bool,
}

struct TokenizerConfig {
    model_name: string,
    tokenizer_type: TokenizerType,
    vocab_size: i32,
    max_token_length: i32,
    cache_enabled: bool,
    cache_size: i32,
    add_bos: bool,
    add_eos: bool,
    add_prefix_space: bool,
    trim_spaces: bool,
    lowercase: bool,
}

struct TokenizerStats {
    total_encodings: i64,
    total_decodings: i64,
    avg_tokens_per_sequence: f32,
    cache_hits: i64,
    cache_misses: i64,
    bytes_processed: i64,
    encoding_time_ms: f32,
    decoding_time_ms: f32,
}

struct TokenizerResult {
    success: bool,
    error_code: i32,
    error_message: string,
    tokens: i32[],
    text: string,
    stats: TokenizerStats,
    timestamp_ms: i64,
}

struct SpecialTokens {
    bos_token_id: i32,
    eos_token_id: i32,
    unk_token_id: i32,
    pad_token_id: i32,
    cls_token_id: i32,
    sep_token_id: i32,
    mask_token_id: i32,
}

struct TokenizerVocab {
    size: i32,
    min_token_id: i32,
    max_token_id: i32,
    num_special_tokens: i32,
    num_regular_tokens: i32,
    encoding_name: string,
    language: string,
}

struct EncodingOptions {
    add_special_tokens: bool,
    max_length: i32,
    padding: string,
    truncation: bool,
    truncation_side: string,
    return_attention_mask: bool,
    return_token_type_ids: bool,
}

struct DecodingOptions {
    skip_special_tokens: bool,
    clean_up_tokenization_spaces: bool,
    use_source_tokenizer: bool,
}

struct TokenSequence {
    tokens: i32[],
    text_tokens: string[],
    attention_mask: i32[],
    token_type_ids: i32[],
    special_tokens_mask: i32[],
    length: i32,
}

struct TokenCache {
    text: string,
    tokens: i32[],
    hash: u64,
    timestamp: i64,
    hit_count: i32,
    size_bytes: i32,
}

struct EncodingStats {
    input_length: i32,
    output_length: i32,
    encoding_time_ms: f32,
    cache_hit: bool,
    special_tokens_added: i32,
    padding_added: i32,
}

struct VocabularyEntry {
    token_id: i32,
    text: string,
    frequency: i32,
    priority: f32,
    is_special: bool,
    encoding_length: i32,
}

struct TokenStatistics {
    token_id: i32,
    occurrences: i64,
    probability: f32,
    average_position: f32,
    entropy: f32,
    cross_entropy: f32,
}

const ERROR_SUCCESS = 0
const ERROR_INVALID_CONFIG = -1
const ERROR_TOKENIZER_NOT_FOUND = -2
const ERROR_ENCODING_FAILED = -3
const ERROR_DECODING_FAILED = -4
const ERROR_VOCAB_NOT_LOADED = -5
const ERROR_INVALID_TOKEN_ID = -6
const ERROR_SPECIAL_TOKEN_NOT_FOUND = -7
const ERROR_CACHE_FULL = -8
const ERROR_INVALID_ENCODING_OPTIONS = -9
const ERROR_TRUNCATION_FAILED = -10

const DEFAULT_CACHE_SIZE = 10000
const DEFAULT_MAX_TOKEN_LENGTH = 512
const DEFAULT_VOCAB_SIZE = 32000
const CACHE_ENTRY_OVERHEAD_BYTES = 256

const LLAMA_VOCAB_SIZE = 32000
const QWEN_VOCAB_SIZE = 152064
const GPT_VOCAB_SIZE = 50257
const T5_VOCAB_SIZE = 32128
