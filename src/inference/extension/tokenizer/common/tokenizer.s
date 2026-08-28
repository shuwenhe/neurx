import "./types"
import "std/string"
import "std/vector"
import "std/hash"
struct BaseTokenizer {
    config: types.TokenizerConfig,
    vocab: types.TokenizerVocab,
    special_tokens: types.SpecialTokens,
    vocab_id_to_text: map[i32]string,
    vocab_text_to_id: map[string]i32,
    stats: types.TokenizerStats,
    cache: map[string]types.TokenCache,
    cache_size_bytes: i32,
}
func NewBaseTokenizer(types.TokenizerConfig config) *BaseTokenizer {
    tokenizer := new(BaseTokenizer)
    tokenizer.config = config
    tokenizer.cache_size_bytes = 0
    tokenizer.vocab = types.TokenizerVocab{
        size: config.vocab_size,
        min_token_id: 0,
        max_token_id: config.vocab_size - 1,
        encoding_name: "utf-8",
    }
    tokenizer.special_tokens = types.SpecialTokens{
        bos_token_id: 1,
        eos_token_id: 2,
        unk_token_id: 0,
        pad_token_id: 0,
        cls_token_id: 101,
        sep_token_id: 102,
        mask_token_id: 103,
    }
    return tokenizer
}
func (BaseTokenizer* t) Encode(string text) types.TokenizerResult {
    return t.EncodeWithOptions(text, types.EncodingOptions{
        add_special_tokens: true,
        truncation: false,
        return_attention_mask: true,
    })
}
func (BaseTokenizer* t) EncodeWithOptions(string text, types.EncodingOptions opts) types.TokenizerResult {
    t.stats.total_encodings += 1
    if t.config.cache_enabled {
        if cached, ok := t.cache[text]; ok {
            t.stats.cache_hits += 1
            return types.TokenizerResult{
                success: true,
                error_code: types.ERROR_SUCCESS,
                tokens: cached.tokens,
                text: text,
                stats: t.stats,
            }
        }
    }
    t.stats.cache_misses += 1
    tokens := t.tokenize_internal(text)
    if opts.add_special_tokens {
        tokens = t.add_special_tokens_internal(tokens)
    }
    if opts.truncation && opts.max_length > 0 {
        if len(tokens) > opts.max_length {
            if opts.truncation_side == "right" {
                tokens = tokens[0:opts.max_length]
            } else if opts.truncation_side == "left" {
                start := len(tokens) - opts.max_length
                tokens = tokens[start:]
            }
        }
    }
    if opts.padding == "max_length" && opts.max_length > 0 {
        padding_needed := opts.max_length - len(tokens)
        for i := 0; i < padding_needed; i += 1 {
            tokens = append(tokens, t.special_tokens.pad_token_id)
        }
    }
    if t.config.cache_enabled && len(tokens) < types.DEFAULT_CACHE_SIZE {
        cache_entry := types.TokenCache{
            text: text,
            tokens: tokens,
            hash: simple_hash(text),
            timestamp: current_time_ms(),
            hit_count: 0,
            size_bytes: len(text) + len(tokens) * 4 + types.CACHE_ENTRY_OVERHEAD_BYTES,
        }
        if t.cache_size_bytes + cache_entry.size_bytes < t.config.cache_size {
            t.cache[text] = cache_entry
            t.cache_size_bytes += cache_entry.size_bytes
        }
    }
    t.stats.bytes_processed += i64(len(text))
    return types.TokenizerResult{
        success: true,
        error_code: types.ERROR_SUCCESS,
        tokens: tokens,
        text: text,
        stats: t.stats,
    }
}
func (BaseTokenizer* t) EncodeBatch(string[] texts) types.TokenizerResult[] {
    results := make(types.TokenizerResult[], len(texts))
    for i := 0; i < len(texts); i += 1 {
        results[i] = t.Encode(texts[i])
    }
    return results
}
func (BaseTokenizer* t) Decode(i32[] token_ids) types.TokenizerResult {
    return t.DecodeWithOptions(token_ids, types.DecodingOptions{
        skip_special_tokens: false,
        clean_up_tokenization_spaces: true,
    })
}
func (BaseTokenizer* t) DecodeWithOptions(i32[] token_ids, types.DecodingOptions opts) types.TokenizerResult {
    t.stats.total_decodings += 1
    text_parts := make(string[], len(token_ids))
    for i := 0; i < len(token_ids); i += 1 {
        token_id := token_ids[i]
        if opts.skip_special_tokens && t.is_special_token(token_id) {
            continue
        }
        if token_text, ok := t.vocab_id_to_text[token_id]; ok {
            text_parts[i] = token_text
        } else {
            text_parts[i] = "<unk>"
        }
    }
    decoded_text := t.join_tokens(text_parts, opts.clean_up_tokenization_spaces)
    return types.TokenizerResult{
        success: true,
        error_code: types.ERROR_SUCCESS,
        text: decoded_text,
        stats: t.stats,
    }
}
func (BaseTokenizer* t) DecodeBatch(i32[][]] token_sequences) types.TokenizerResult[] {
    results := make(types.TokenizerResult[], len(token_sequences))
    for i := 0; i < len(token_sequences); i += 1 {
        results[i] = t.Decode(token_sequences[i])
    }
    return results
}
func (BaseTokenizer* t) SetSpecialTokens(types.SpecialTokens special) {
    t.special_tokens = special
    t.vocab.num_special_tokens = 7
}
func (BaseTokenizer* t) GetSpecialToken(string name) i32 {
    switch name {
    case "bos":
        return t.special_tokens.bos_token_id
    case "eos":
        return t.special_tokens.eos_token_id
    case "pad":
        return t.special_tokens.pad_token_id
    case "unk":
        return t.special_tokens.unk_token_id
    default:
        return t.special_tokens.unk_token_id
    }
}
func (BaseTokenizer* t) IsSpecialToken(i32 token_id) bool {
    return t.is_special_token(token_id)
}
func (BaseTokenizer* t) GetVocabularySize() i32 {
    return t.vocab.size
}
func (BaseTokenizer* t) GetTokenText(i32 token_id) string {
    if token_text, ok := t.vocab_id_to_text[token_id]; ok {
        return token_text
    }
    return "<unk>"
}
func (BaseTokenizer* t) GetTokenId(string text) i32 {
    if token_id, ok := t.vocab_text_to_id[text]; ok {
        return token_id
    }
    return t.special_tokens.unk_token_id
}
func (BaseTokenizer* t) tokenize_internal(string text) i32[] {
    tokens := make(i32[], 0)
    words := split_string(text, " ")
    for i := 0; i < len(words); i += 1 {
        word := words[i]
        if len(word) > 0 {
            if token_id, ok := t.vocab_text_to_id[word]; ok {
                tokens = append(tokens, token_id)
            } else {
                for j := 0; j < len(word); j += 1 {
                    char_str := string(word[j])
                    if char_id, ok := t.vocab_text_to_id[char_str]; ok {
                        tokens = append(tokens, char_id)
                    }
                }
            }
        }
    }
    return tokens
}
func (BaseTokenizer* t) add_special_tokens_internal(i32[] tokens) i32[] {
    result := make(i32[], 0)
    if t.config.add_bos {
        result = append(result, t.special_tokens.bos_token_id)
    }
    result = append_slice(result, tokens)
    if t.config.add_eos {
        result = append(result, t.special_tokens.eos_token_id)
    }
    return result
}
func (BaseTokenizer* t) is_special_token(i32 token_id) bool {
    return token_id == t.special_tokens.bos_token_id ||
           token_id == t.special_tokens.eos_token_id ||
           token_id == t.special_tokens.pad_token_id ||
           token_id == t.special_tokens.unk_token_id ||
           token_id == t.special_tokens.cls_token_id ||
           token_id == t.special_tokens.sep_token_id ||
           token_id == t.special_tokens.mask_token_id
}
func (BaseTokenizer* t) join_tokens(string[] tokens, bool clean_spaces) string {
    if len(tokens) == 0 {
        return ""
    }
    result := ""
    for i := 0; i < len(tokens); i += 1 {
        if i > 0 && clean_spaces {
            result = result + " "
        }
        result = result + tokens[i]
    }
    return result
}
func (BaseTokenizer* t) GetStatistics() types.TokenizerStats {
    if t.stats.total_encodings > 0 {
        t.stats.avg_tokens_per_sequence = f32(t.stats.bytes_processed) / f32(t.stats.total_encodings)
    }
    return t.stats
}
func (BaseTokenizer* t) ResetStatistics() {
    t.stats = types.TokenizerStats{}
}
func (BaseTokenizer* t) ClearCache() {
    for key := range t.cache {
        delete(t.cache, key)
    }
    t.cache_size_bytes = 0
}
func (BaseTokenizer* t) GetCacheStatistics() map[string]i64 {
    stats := make(map[string]i64)
    stats["cache_size_bytes"] = i64(t.cache_size_bytes)
    stats["cache_entries"] = i64(len(t.cache))
    stats["cache_hits"] = t.stats.cache_hits
    stats["cache_misses"] = t.stats.cache_misses
    if t.stats.cache_hits + t.stats.cache_misses > 0 {
        hit_rate := i64(100 * t.stats.cache_hits / (t.stats.cache_hits + t.stats.cache_misses))
        stats["cache_hit_rate_percent"] = hit_rate
    }
    return stats
}
func simple_hash(string s) u64 {
    hash := u64(5381)
    for i := 0; i < len(s); i += 1 {
        hash = ((hash << 5) + hash) + u64(s[i])
    }
    return hash
}
func current_time_ms() i64 {
    return i64(0)
}
func split_string(string s, string sep) string[] {
    parts := make(string[], 0)
    current := ""
    for i := 0; i < len(s); i += 1 {
        if string(s[i]) == sep {
            if len(current) > 0 {
                parts = append(parts, current)
                current = ""
            }
        } else {
            current = current + string(s[i])
        }
    }
    if len(current) > 0 {
        parts = append(parts, current)
    }
    return parts
}
func append_slice(i32[] a, i32[] b) i32[] {
    for i := 0; i < len(b); i += 1 {
        a = append(a, b[i])
    }
    return a
}
