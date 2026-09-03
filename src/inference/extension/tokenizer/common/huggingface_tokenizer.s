import "./types"
import "./tokenizer"
import "std/string"
import "std/vector"
struct HFTokenizer {
    base: *tokenizer.BaseTokenizer,
    model_path: string,
    tokenizer_type: string,
    subword_prefix: string,
    lowercase: bool,
    handle_chinese_chars: bool,
    strip_accents: bool,
    vocab_file: string,
    merges_file: string,
}

func NewHFTokenizer(types.TokenizerConfig config, string model_path) *HFTokenizer {
    hf := new(HFTokenizer)
    hf.base = tokenizer.NewBaseTokenizer(config)
    hf.model_path = model_path
    hf.tokenizer_type = "bpe"
    hf.subword_prefix = "##"
    hf.lowercase = config.lowercase
    hf.handle_chinese_chars = true
    hf.strip_accents = false
    return hf
}

func (HFTokenizer* h) LoadVocabulary(string vocab_file) types.TokenizerResult {
    h.vocab_file = vocab_file
    if contains_string(vocab_file, "llama") || contains_string(vocab_file, "Llama") {
        h.load_llama_vocab()
    } else if contains_string(vocab_file, "qwen") || contains_string(vocab_file, "Qwen") {
        h.load_qwen_vocab()
    } else if contains_string(vocab_file, "bert") || contains_string(vocab_file, "BERT") {
        h.load_bert_vocab()
    } else {
        h.load_generic_vocab()
    }
    return types.TokenizerResult{
        success: true,
        error_code: types.ERROR_SUCCESS,
        stats: h.base.GetStatistics(),
    }
}

func (HFTokenizer* h) LoadMerges(string merges_file) types.TokenizerResult {
    h.merges_file = merges_file
    return types.TokenizerResult{
        success: true,
        error_code: types.ERROR_SUCCESS,
        stats: h.base.GetStatistics(),
    }
}

func (HFTokenizer* h) Encode(string text) types.TokenizerResult {
    return h.EncodeWithOptions(text, types.EncodingOptions{
        add_special_tokens: true,
        truncation: false,
        return_attention_mask: true,
        return_token_type_ids: true,
    })
}

func (HFTokenizer* h) EncodeWithOptions(string text, types.EncodingOptions opts) types.TokenizerResult {
    if h.lowercase {
        text = lowercase_string(text)
    }
    if h.handle_chinese_chars {
        text = h.add_spaces_around_chinese(text)
    }
    if h.strip_accents {
        text = h.remove_accents(text)
    }
    basic_tokens := h.basic_tokenize(text)
    wordpiece_tokens := h.wordpiece_tokenize(basic_tokens)
    token_ids := make(i32[], len(wordpiece_tokens))
    for i := 0; i < len(wordpiece_tokens); i += 1 {
        token_ids[i] = h.base.GetTokenId(wordpiece_tokens[i])
    }
    if opts.add_special_tokens {
        token_ids = h.add_special_tokens_hf(token_ids)
    }
    if opts.truncation && opts.max_length > 0 {
        token_ids = h.truncate_tokens(token_ids, opts.max_length, opts.truncation_side)
    }
    seq_len := len(token_ids)
    attention_mask := make(i32[], seq_len)
    for i := 0; i < seq_len; i += 1 {
        attention_mask[i] = 1
    }
    if opts.padding == "max_length" && opts.max_length > seq_len {
        padding_len := opts.max_length - seq_len
        for i := 0; i < padding_len; i += 1 {
            token_ids = append(token_ids, h.base.GetSpecialToken("pad"))
            attention_mask = append(attention_mask, 0)
        }
    }
    return types.TokenizerResult{
        success: true,
        error_code: types.ERROR_SUCCESS,
        tokens: token_ids,
        text: text,
        stats: h.base.GetStatistics(),
    }
}

func (HFTokenizer* h) EncodeMultiSentences(string text_a, string text_b) types.TokenizerResult {
    tokens_a := h.tokenize_internal(text_a)
    tokens_a = append(tokens_a, h.base.GetSpecialToken("sep"))
    tokens_b := h.tokenize_internal(text_b)
    all_tokens := make(i32[], 0)
    all_tokens = append(all_tokens, h.base.GetSpecialToken("cls"))
    all_tokens = append_slice_i32(all_tokens, tokens_a)
    all_tokens = append_slice_i32(all_tokens, tokens_b)
    return types.TokenizerResult{
        success: true,
        error_code: types.ERROR_SUCCESS,
        tokens: all_tokens,
        stats: h.base.GetStatistics(),
    }
}

func (HFTokenizer* h) Decode(i32[] token_ids) string {
    result := h.base.DecodeWithOptions(token_ids, types.DecodingOptions{
        skip_special_tokens: true,
        clean_up_tokenization_spaces: true,
    })
    return result.text
}

func (HFTokenizer* h) basic_tokenize(string text) []string {
    tokens := make([]string, 0)
    current := ""
    for i := 0; i < len(text); i += 1 {
        char := string(text[i])
        if is_whitespace(char) {
            if len(current) > 0 {
                tokens = append(tokens, current)
                current = ""
            }
        } else if is_punctuation(char) {
            if len(current) > 0 {
                tokens = append(tokens, current)
            }
            tokens = append(tokens, char)
            current = ""
        } else {
            current = current + char
        }
    }
    if len(current) > 0 {
        tokens = append(tokens, current)
    }
    return tokens
}

func (HFTokenizer* h) wordpiece_tokenize([]string tokens) []string {
    output := make([]string, 0)
    for i := 0; i < len(tokens); i += 1 {
        token := tokens[i]
        if _, ok := h.base.vocab_text_to_id[token]; ok {
            output = append(output, token)
        } else {
            subwords := h.split_subwords(token)
            for j := 0; j < len(subwords); j += 1 {
                output = append(output, subwords[j])
            }
        }
    }
    return output
}

func (HFTokenizer* h) split_subwords(string word) []string {
    subwords := make([]string, 0)
    start := 0
    for start < len(word) {
        end := len(word)
        found := false
        for end > start {
            substr := word[start:end]
            lookup := substr
            if start > 0 {
                lookup = h.subword_prefix + substr
            }
            if _, ok := h.base.vocab_text_to_id[lookup]; ok {
                subwords = append(subwords, lookup)
                found = true
                break
            }
            end -= 1
        }
        if !found {
            subwords = append(subwords, h.subword_prefix + string(word[start]))
            end = start + 1
        }
        start = end
    }
    return subwords
}

func (HFTokenizer* h) add_special_tokens_hf(i32[] tokens) []i32 {
    result := make(i32[], 0)
    result = append(result, h.base.GetSpecialToken("cls"))
    result = append_slice_i32(result, tokens)
    result = append(result, h.base.GetSpecialToken("sep"))
    return result
}

func (HFTokenizer* h) truncate_tokens(i32[] tokens, i32 max_length, string side) []i32 {
    if i32(len(tokens)) <= max_length {
        return tokens
    }
    if side == "left" {
        start := len(tokens) - int(max_length)
        return tokens[start:]
    }
    return tokens[0:max_length]
}

func (HFTokenizer* h) add_spaces_around_chinese(string text) string {
    result := ""
    for i := 0; i < len(text); i += 1 {
        char := text[i]
        result = result + string(char)
    }
    return result
}

func (HFTokenizer* h) remove_accents(string text) string {
    return text
}

func (HFTokenizer* h) tokenize_internal(string text) []i32 {
    basic_tokens := h.basic_tokenize(text)
    wordpiece_tokens := h.wordpiece_tokenize(basic_tokens)
    result := make(i32[], len(wordpiece_tokens))
    for i := 0; i < len(wordpiece_tokens); i += 1 {
        result[i] = h.base.GetTokenId(wordpiece_tokens[i])
    }
    return result
}

func (HFTokenizer* h) load_llama_vocab() {
    h.base.vocab.size = types.LLAMA_VOCAB_SIZE
    h.tokenizer_type = "bpe"
    h.subword_prefix = ""
}

func (HFTokenizer* h) load_qwen_vocab() {
    h.base.vocab.size = types.QWEN_VOCAB_SIZE
    h.tokenizer_type = "bpe"
    h.subword_prefix = ""
}

func (HFTokenizer* h) load_bert_vocab() {
    h.base.vocab.size = 30522
    h.tokenizer_type = "wordpiece"
    h.subword_prefix = "##"
    h.lowercase = true
}

func (HFTokenizer* h) load_generic_vocab() {
    h.base.vocab.size = types.DEFAULT_VOCAB_SIZE
    h.tokenizer_type = "bpe"
}

func lowercase_string(string s) string {
    result := ""
    for i := 0; i < len(s); i += 1 {
        char := s[i]
        if char >= 65 && char <= 90 {
            result = result + string(char + 32)
        } else {
            result = result + string(char)
        }
    }
    return result
}

func is_whitespace(string char) bool {
    return char == " " || char == "\t" || char == "\n" || char == "\r"
}

func is_punctuation(string char) bool {
    return char == "." || char == "," || char == "!" || char == "" ||
           char == ";" || char == ":" || char == "-" || char == "(" || char == ")"
}

func contains_string(string s, string substring) bool {
    for i := 0; i <= len(s) - len(substring); i += 1 {
        match := true
        for j := 0; j < len(substring); j += 1 {
            if s[i+j] != substring[j] {
                match = false
                break
            }
        }
        if match {
            return true
        }
    }
    return false
}

func append_slice_i32(i32[] a, i32[] b) []i32 {
    for i := 0; i < len(b); i += 1 {
        a = append(a, b[i])
    }
    return a
}
