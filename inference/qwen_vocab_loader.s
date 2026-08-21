package neurx.inference.qwen_vocab_loader

use std.conv.int_to_string
use neurx.runtime.io.{runtime_file_exists, runtime_read_text_file}

extern "intrinsic" func __host_slice(string text, int start, int end) string
extern "intrinsic" func __sys_json_parse(string json_text) map[string]string

struct vocab_cache {
    map[string]string vocab_map
    bool loaded
}

var cached_vocab vocab_cache = vocab_cache{vocab_map: map[string]string{}, loaded: false}

func load_qwen_vocab() bool {
    if cached_vocab.loaded {
        return len(cached_vocab.vocab_map) > 0
    }

    string vocab_file = "/tmp/qwen_vocab.json"
    if !runtime_file_exists(vocab_file) {
        vocab_file = "/home/shuwen/shuwen/neurx/inference/qwen_vocab.json"
    }

    if runtime_file_exists(vocab_file) {
        string json_content = runtime_read_text_file(vocab_file)
        if len(json_content) > 0 {
            cached_vocab.vocab_map = __sys_json_parse(json_content)
            cached_vocab.loaded = true
            return true
        }
    }

    cached_vocab.loaded = true
    false
}

func lookup_token_text(int token_id) string {
    if !cached_vocab.loaded {
        load_qwen_vocab()
    }

    string key = int_to_string(token_id)
    if key in cached_vocab.vocab_map {
        return cached_vocab.vocab_map[key]
    }

    fallback_token_decode(token_id)
}

func fallback_token_decode(int token_id) string {

    if token_id == 0 { return "!" }
    if token_id == 151643 { return "<|im_start|>" }
    if token_id == 151644 { return "<|im_end|>" }
    if token_id == 151645 { return "<|im_end|>" }

    if token_id >= 0 && token_id < 128 {
        return string(token_id)
    }

    "<token_" + int_to_string(token_id) + ">"
}

func token_id_to_text(int token_id) string {
    lookup_token_text(token_id)
}
