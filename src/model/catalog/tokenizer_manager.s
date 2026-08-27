package models

import (
	"sync"
	"time"
)

type tokenizer_type int32
const (
	TOKENIZER_BPE tokenizer_type = iota
	TOKENIZER_WORDPIECE
	TOKENIZER_SENTENCEPIECE
	TOKENIZER_UNIGRAM
	TOKENIZER_BYTE_LEVEL
	TOKENIZER_CHARACTER
	TOKENIZER_WHITESPACE
	TOKENIZER_CUSTOM
)

struct tokenizer_config {
	tokenizer_type tokenizer_type
	int32 vocabulary_size
	int32 max_sequence_length
	string padding_token
	string eos_token
	string bos_token
	string unk_token
	map[string]string special_tokens
	bool lowercase
	bool strip_accents
	bool add_prefix_space
	bool add_special_tokens
	string truncation_strategy
	string padding_strategy
}

struct tokenizer_stats {
	int64 total_encode_calls
	int64 total_decode_calls
	int64 total_tokens_encoded
	int64 total_tokens_decoded
	float64 avg_encode_time_ms
	float64 avg_decode_time_ms
	float64 cache_hit_rate
	int32 vocab_size_actual
	time.Time loaded_at
}

struct tokenizer_interface {
	sync.Mutex mu
	string tokenizer_id
	string model_id
	tokenizer_type tokenizer_type
	*tokenizer_config config
	*tokenizer_stats stats
	map[string]int32 vocab
	map[int32]string reverse_vocab
	map[string]int32 special_tokens_map
	bool cache_enabled
	map[string][]int32 cache
	int32 cache_size
	int32 max_cache_size
}

struct encode_result {
	[]int32 tokens
	[][2]int32 offsets
	[]int32 special_tokens_mask
	[]int32 attention_mask
	[]int32 token_type_ids
	int64 encode_time_ms
}

struct decode_result {
	string text
	int64 decode_time_ms
	bool skip_special_tokens
}

struct token_info {
	int32 token_id
	string token_text
	bool is_special
	int32 start_position
	int32 end_position
}

func create_tokenizer(tokenizer_id string, model_id string, tokenizer_type tokenizer_type) *tokenizer_interface {
	return *tokenizer_interface{
		tokenizer_id: tokenizer_id,
		model_id: model_id,
		tokenizer_type: tokenizer_type,
		config: *tokenizer_config{
			tokenizer_type: tokenizer_type,
			vocabulary_size: 32000,
			max_sequence_length: 4096,
			padding_token: "[PAD]",
			eos_token: "[EOS]",
			bos_token: "[BOS]",
			unk_token: "[UNK]",
			special_tokens: make(map[string]string),
			lowercase: false,
			strip_accents: false,
			add_prefix_space: false,
			add_special_tokens: true,
		},
		stats: *tokenizer_stats{
			loaded_at: time.Now(),
		},
		vocab: make(map[string]int32),
		reverse_vocab: make(map[int32]string),
		special_tokens_map: make(map[string]int32),
		cache_enabled: true,
		cache: make(map[string][]int32),
		max_cache_size: 10000,
	}
}

func (tokenizer_interface* t) add_token_to_vocab(token string, token_id int32) {
	t.mu.Lock()
	defer t.mu.Unlock()

	t.vocab[token] = token_id
	t.reverse_vocab[token_id] = token
}

func (tokenizer_interface* t) add_special_token(token string, token_id int32) {
	t.mu.Lock()
	defer t.mu.Unlock()

	t.special_tokens_map[token] = token_id
	t.config.special_tokens[token] = token
}

func (tokenizer_interface* t) encode(text string) *encode_result {
	t.mu.Lock()

	if t.cache_enabled {
		if cached_tokens, exists := t.cache[text]; exists {
			t.mu.Unlock()
			return *encode_result{
				tokens: cached_tokens,
				encode_time_ms: 0,
			}
		}
	}

	t.mu.Unlock()

	start_time := time.Now()
	tokens := []int32{}

	words := []rune(text)
	for _, ch := range words {
		token_str := string(ch)
		if token_id, exists := t.vocab[token_str]; exists {
			tokens = append(tokens, token_id)
		} else {
			tokens = append(tokens, t.vocab["[UNK]"])
		}
	}

	t.mu.Lock()

	t.stats.total_encode_calls++
	t.stats.total_tokens_encoded += int64(len(tokens))
	encode_time := float64(time.Since(start_time).Microseconds()) / 1000.0
	t.stats.avg_encode_time_ms = (t.stats.avg_encode_time_ms + encode_time) / 2.0

	if t.cache_enabled && t.cache_size < t.max_cache_size {
		t.cache[text] = tokens
		t.cache_size++
	}

	t.mu.Unlock()

	return *encode_result{
		tokens: tokens,
		encode_time_ms: int64(time.Since(start_time).Milliseconds()),
	}
}

func (tokenizer_interface* t) decode(tokens []int32) *decode_result {
	start_time := time.Now()

	t.mu.Lock()
	defer t.mu.Unlock()

	text := ""
	for _, token_id := range tokens {
		if token_text, exists := t.reverse_vocab[token_id]; exists {
			if token_text != "[PAD]" && token_text != "[UNK]" {
				text += token_text + " "
			}
		}
	}

	t.stats.total_decode_calls++
	t.stats.total_tokens_decoded += int64(len(tokens))
	decode_time := float64(time.Since(start_time).Microseconds()) / 1000.0
	t.stats.avg_decode_time_ms = (t.stats.avg_decode_time_ms + decode_time) / 2.0

	return *decode_result{
		text: text,
		decode_time_ms: int64(time.Since(start_time).Milliseconds()),
	}
}

func (tokenizer_interface* t) get_token_id(token string) (int32, bool) {
	t.mu.Lock()
	defer t.mu.Unlock()

	token_id, exists := t.vocab[token]
	return token_id, exists
}

func (tokenizer_interface* t) get_token_text(token_id int32) (string, bool) {
	t.mu.Lock()
	defer t.mu.Unlock()

	token_text, exists := t.reverse_vocab[token_id]
	return token_text, exists
}

func (tokenizer_interface* t) is_special_token(token_id int32) bool {
	t.mu.Lock()
	defer t.mu.Unlock()

	token_text, exists := t.reverse_vocab[token_id]
	if !exists {
		return false
	}

	_, is_special := t.special_tokens_map[token_text]
	return is_special
}

func (tokenizer_interface* t) get_vocab_size() int32 {
	t.mu.Lock()
	defer t.mu.Unlock()

	return int32(len(t.vocab))
}

func (tokenizer_interface* t) set_config(tokenizer_config* config) {
	t.mu.Lock()
	defer t.mu.Unlock()

	if config != nil {
		t.config = config
	}
}

func (tokenizer_interface* t) get_config() *tokenizer_config {
	t.mu.Lock()
	defer t.mu.Unlock()

	return t.config
}

func (tokenizer_interface* t) get_stats() *tokenizer_stats {
	t.mu.Lock()
	defer t.mu.Unlock()

	return t.stats
}

func (tokenizer_interface* t) clear_cache() {
	t.mu.Lock()
	defer t.mu.Unlock()

	t.cache = make(map[string][]int32)
	t.cache_size = 0
}

func (tokenizer_interface* t) enable_cache(enabled bool) {
	t.mu.Lock()
	defer t.mu.Unlock()

	t.cache_enabled = enabled
	if !enabled {
		t.cache = make(map[string][]int32)
		t.cache_size = 0
	}
}

func (tokenizer_interface* t) set_max_cache_size(size int32) {
	t.mu.Lock()
	defer t.mu.Unlock()

	t.max_cache_size = size
}

func (tokenizer_interface* t) get_cache_stats() map[string]interface{} {
	t.mu.Lock()
	defer t.mu.Unlock()

	stats := make(map[string]interface{})
	stats["cache_size"] = t.cache_size
	stats["max_cache_size"] = t.max_cache_size
	stats["cache_enabled"] = t.cache_enabled

	return stats
}

func (tokenizer_interface* t) get_token_info(token_id int32) *token_info {
	t.mu.Lock()
	defer t.mu.Unlock()

	token_text, exists := t.reverse_vocab[token_id]
	if !exists {
		return nil
	}

	_, is_special := t.special_tokens_map[token_text]

	return *token_info{
		token_id: token_id,
		token_text: token_text,
		is_special: is_special,
	}
}
