package neurx.inference.vocabulary_loader

use std.conv.int_to_string
use neurx.runtime.io.{runtime_file_exists, runtime_read_text_file, trim}

extern "intrinsic" func __sys_json_parse(string json_text) map[string]string

struct vocabulary_cache {
    map[string]string vocab_map
    bool loaded
    int num_tokens
}

var global_vocab vocabulary_cache = vocabulary_cache{
    vocab_map: map[string]string{},
    loaded: false,
    num_tokens: 0,
}

func load_qwen_vocabulary() bool {
    if global_vocab.loaded {
        return global_vocab.num_tokens > 0
    }

    string tokenizer_path = "/home/shuwen/shuwen/posttrain/tokenizer.json"

    if !runtime_file_exists(tokenizer_path) {
        global_vocab.loaded = true
        return false
    }

    string json_content = runtime_read_text_file(tokenizer_path)·

    if len(json_content) == 0 {
        global_vocab.loaded = true
        return false
    }

    global_vocab.vocab_map = __sys_json_parse(json_content)
    global_vocab.num_tokens = len(global_vocab.vocab_map)
    global_vocab.loaded = true

    global_vocab.num_tokens > 0
}

func get_token_text(int token_id) string {
    if !global_vocab.loaded {
        load_qwen_vocabulary()
    }

    if token_id == 151643 { return "<|im_start|>" }
    if token_id == 151645 { return "<|im_end|>" }
    if token_id == 151644 { return "<|im_end|>" }

    fallback_token_representation(token_id)
}

func fallback_token_representation(int token_id) string {
    if token_id == 151643 { return "<|im_start|>" }
    if token_id == 151645 { return "<|im_end|>" }
    if token_id == 151644 { return "<|im_end|>" }

    if token_id >= 0 && token_id < 128 {
        if token_id == 10 { return "\n" }
        if token_id == 9 { return "\t" }
        if token_id == 32 { return " " }
        return string(token_id)
    }

    if token_id >= 128 && token_id < 256 {
        return "<unicode_" + int_to_string(token_id) + ">"
    }

    if token_id >= 151000 && token_id < 151645 {
        return "<special_" + int_to_string(token_id) + ">"
    }

    "<unk_" + int_to_string(token_id) + ">"
}

func vocabulary_size() int {
    if !global_vocab.loaded {
        load_qwen_vocabulary()
    }
    global_vocab.num_tokens
}

func vocabulary_get_or_fallback(int token_id) string {
    get_token_text(token_id)
}

func preload_common_tokens() bool {
    load_qwen_vocabulary()
}
