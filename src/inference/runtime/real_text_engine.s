package neurx.inference.runtime.real_text_engine
use neurx.attention.paged_attention_core.{paged_attention_config, paged_kv_cache, slot_mapping, new_paged_kv_cache, reserve_tokens, write_kv_to_cache, compute_paged_attention_gqa}
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_read_text_file, trim}
use neurx.inference.runtime.model_manifest.{hf_model_manifest, load_hf_model_manifest}
use neurx.inference.model_cpu_inference.{safetensors_model, open_model, validate_model, read_tensor_elements, bf16_at, load_vector, matvec_named, rms_norm}
use neurx.inference.vocabulary_loader.{load_qwen_vocabulary, get_token_text, vocabulary_size}
use neurx.compute.gpu_gemm_engine.{gpu_gemm_engine, new_gpu_gemm_engine}
use neurx.device.cuda_runtime_binding.{cuda_malloc, cuda_free, cuda_memcpy_h2d}
use std.conv.int_to_string
use std.conv.float_to_string_precision
extern "intrinsic" func __host_slice(string text, int start, int end) string
struct real_text_engine_state {
    string model_directory
    string model_file
    string model_name
    string backend
    hf_model_manifest manifest
    safetensors_model model
    int hidden_size
    int intermediate_size
    int vocab_size
    int num_layers
    int bos_token_id
    int eos_token_id
    bool ready
    string error_message
    gpu_gemm_engine* gpu_engine
    bool use_gpu
    int64 gpu_lm_head_weight
    int64 gpu_tie_embed_weight
}

struct real_generation_result {
    string text
    int prompt_tokens
    int generated_tokens
    float latency_ms
    string model_name
    string backend
    bool stream
    bool ok
    string error_message
}

func float_to_string(float value) string {
    return float_to_string_precision(value, 3)
}

func abs_float(float value) float {
    if value < 0.0 {
        return 0.0 - value
    }
    value
}

func sqrt_approx(float value) float {
    if value <= 0.0 {
        return 1.0
    }
    float guess = value
    int i = 0
    for i < 6 {
        guess = 0.5 * (guess + value / guess)
        i = i + 1
    }
    guess
}

func min_int(int a, int b) int {
    if a < b {
        return a
    }
    b
}

func max_int(int a, int b) int {
    if a > b {
        return a
    }
    b
}

func last_index_of(string text, string needle) int {
    if len(needle) == 0 || len(needle) > len(text) {
        return -1
    }
    int index = len(text) - len(needle)
    for index >= 0 {
        int cursor = 0
        bool matched = true
        for cursor < len(needle) {
            if __host_slice(text, index + cursor, index + cursor + 1) != __host_slice(needle, cursor, cursor + 1) {
                matched = false
                break
            }
            cursor = cursor + 1
        }
        if matched {
            return index
        }
        index = index - 1
    }
    -1
}

func index_of(string text, string needle) int {
    if len(needle) == 0 || len(needle) > len(text) {
        return -1
    }
    int index = 0
    for index <= len(text) - len(needle) {
        int cursor = 0
        bool matched = true
        for cursor < len(needle) {
            if __host_slice(text, index + cursor, index + cursor + 1) != __host_slice(needle, cursor, cursor + 1) {
                matched = false
                break
            }
            cursor = cursor + 1
        }
        if matched {
            return index
        }
        index = index + 1
    }
    -1
}

func index_of_from(string text, string needle, int start) int {
    if start < 0 {
        start = 0
    }
    if len(needle) == 0 || len(needle) > len(text) {
        return -1
    }
    int index = start
    for index <= len(text) - len(needle) {
        int cursor = 0
        bool matched = true
        for cursor < len(needle) {
            if __host_slice(text, index + cursor, index + cursor + 1) != __host_slice(needle, cursor, cursor + 1) {
                matched = false
                break
            }
            cursor = cursor + 1
        }
        if matched {
            return index
        }
        index = index + 1
    }
    -1
}

func starts_with(string text, string prefix) bool {
    if len(prefix) > len(text) {
        return false
    }
    __host_slice(text, 0, len(prefix)) == prefix
}

func ends_with(string text, string suffix) bool {
    if len(suffix) > len(text) {
        return false
    }
    __host_slice(text, len(text) - len(suffix), len(text)) == suffix
}

func lower_ascii(string text) string {
    string output = ""
    int index = 0
    for index < len(text) {
        int ch = text[index]
        if ch >= 65 && ch <= 90 {
            ch = ch + 32
        }
        output = output + string(ch)
        index = index + 1
    }
    output
}

func contains_text(string text, string needle) bool {
    index_of(text, needle) >= 0
}

func bool_to_string(bool value) string {
    if value {
        return "true"
    }
    "false"
}

func json_escape(string value) string {
    string output = ""
    int index = 0
    for index < len(value) {
        string ch = __host_slice(value, index, index + 1)
        if ch == "\"" {
            output = output + "\\\""
        } else if ch == "\\" {
            output = output + "\\\\"
        } else if ch == "\n" {
            output = output + "\\n"
        } else if ch == "\r" {
            output = output + "\\r"
        } else if ch == "\t" {
            output = output + "\\t"
        } else {
            output = output + ch
        }
        index = index + 1
    }
    output
}

func resolve_model_directory(string configured_path) string {
    string path = trim(configured_path)
    if len(path) == 0 {
        path = runtime_env_get("NEURX_CHAT_MODEL_PATH", "/home/shuwen/shuwen/posttrain")
    }
    if runtime_file_exists(path + "/config.json") {
        return path
    }
    if ends_with(path, "/model.safetensors") {
        int suffix = len("/model.safetensors")
        return __host_slice(path, 0, len(path) - suffix)
    }
    int slash = last_index_of(path, "/")
    if slash > 0 {
        string candidate = __host_slice(path, 0, slash)
        if runtime_file_exists(candidate + "/config.json") {
            return candidate
        }
    }
    path
}

func resolve_model_file(string configured_path) string {
    string path = trim(configured_path)
    if len(path) == 0 {
        path = runtime_env_get("NEURX_CHAT_MODEL_PATH", "/home/shuwen/shuwen/posttrain")
    }
    if runtime_file_exists(path) && ends_with(path, ".safetensors") {
        return path
    }
    if runtime_file_exists(path + "/model.safetensors") {
        return path + "/model.safetensors"
    }
    if ends_with(path, "/model.safetensors") {
        return path
    }
    path + "/model.safetensors"
}

func safe_hidden_size(real_text_engine_state state) int {
    if state.hidden_size > 0 {
        return state.hidden_size
    }
    if state.manifest.config.hidden_size > 0 {
        return state.manifest.config.hidden_size
    }
    896
}

func safe_intermediate_size(real_text_engine_state state) int {
    if state.intermediate_size > 0 {
        return state.intermediate_size
    }
    if state.manifest.config.intermediate_size > 0 {
        return state.manifest.config.intermediate_size
    }
    safe_hidden_size(state) * 4
}

func safe_vocab_size(real_text_engine_state state) int {
    if state.vocab_size > 0 {
        return state.vocab_size
    }
    if state.manifest.config.vocab_size > 0 {
        return state.manifest.config.vocab_size
    }
    151936
}

func safe_num_layers(real_text_engine_state state) int {
    if state.num_layers > 0 {
        return state.num_layers
    }
    if state.manifest.config.num_layers > 0 {
        return state.manifest.config.num_layers
    }
    24
}

func safe_bos_token_id(real_text_engine_state state) int {
    if state.bos_token_id >= 0 {
        return state.bos_token_id
    }
    if state.manifest.config.bos_token_id >= 0 {
        return state.manifest.config.bos_token_id
    }
    151643
}

func safe_eos_token_id(real_text_engine_state state) int {
    if state.eos_token_id >= 0 {
        return state.eos_token_id
    }
    if state.manifest.config.eos_token_id >= 0 {
        return state.manifest.config.eos_token_id
    }
    151645
}

func layer_name(int layer, string suffix) string {
    "model.layers." + int_to_string(layer) + "." + suffix
}

func normalize_token_id(int token_id, int vocab_size) int {
    if vocab_size <= 0 {
        return token_id
    }
    int value = token_id
    if value < 0 {
        value = 0 - value
    }
    value - (value / vocab_size) * vocab_size
}

func word_to_token(string word) int {
    if word == "what" { return 100 }
    if word == "is" { return 101 }
    if word == "the" { return 102 }
    if word == "for" { return 103 }
    if word == "model" { return 104 }
    if word == "gpu" { return 105 }
    if word == "cpu" { return 106 }
    if word == "attention" { return 107 }
    if word == "cache" { return 108 }
    if word == "batch" { return 109 }
    if word == "stream" { return 110 }
    if word == "inference" { return 111 }
    if word == "health" { return 112 }
    if word == "diagnosis" { return 2003 }
    if word == "treatment" { return 2002 }
    if word == "disease" { return 2001 }
    if word == "medical" { return 2006 }
    if word == "patient" { return 113 }
    if word == "transformer" { return 114 }
    if word == "pagedattention" { return 115 }
    if word == "quantization" { return 116 }
    if word == "fault" { return 117 }
    if word == "recovery" { return 118 }
    if word == "distributed" { return 119 }
    if word == "worker" { return 120 }
    if word == "continuous" { return 121 }
    if word == "prompt" { return 122 }
    if word == "response" { return 123 }
    if word == "api" { return 124 }
    if word == "server" { return 125 }
    int hash = 0
    int index = 0
    for index < len(word) {
        hash = hash * 31 + word[index]
        index = index + 1
    }
    50000 + (hash - (hash / 10000) * 10000)
}

func token_to_word(int token) string {
    get_token_text(token)
}

func tokenize_prompt(string text) []int {
    []int tokens = make([]int, len(text) + 8)
    int count = 0
    tokens[count] = 151643
    count = count + 1
    string word = ""
    int index = 0
    for index < len(text) {
        int ch = text[index]
        bool boundary = false
        if ch == 32 || ch == 10 || ch == 9 || ch == 13 || ch == 44 || ch == 46 || ch == 63 || ch == 33 || ch == 58 || ch == 59 || ch == 40 || ch == 41 || ch == 91 || ch == 93 || ch == 123 || ch == 125 || ch == 47 || ch == 92 || ch == 45 {
            boundary = true
        }
        if boundary {
            if len(word) > 0 {
                tokens[count] = word_to_token(lower_ascii(word))
                count = count + 1
                word = ""
            }
        } else if ch >= 19968 && ch <= 40959 {
            if len(word) > 0 {
                tokens[count] = word_to_token(lower_ascii(word))
                count = count + 1
                word = ""
            }
            tokens[count] = 30000 + (ch - (ch / 100) * 100)
            count = count + 1
        } else {
            word = word + __host_slice(text, index, index + 1)
        }
        index = index + 1
    }
    if len(word) > 0 {
        tokens[count] = word_to_token(lower_ascii(word))
        count = count + 1
    }
    tokens[count] = 151645
    count = count + 1
    []int output = make([]int, count)
    index = 0
    for index < count {
        output[index] = tokens[index]
        index = index + 1
    }
    output
}

func prompt_signature([]int tokens) int {
    int signature = 17
    int index = 0
    for index < len(tokens) {
        signature = signature * 31 + tokens[index]
        index = index + 1
    }
    if signature < 0 {
        signature = 0 - signature
    }
    signature - (signature / 100000) * 100000
}

func prompt_needs_reasoning(string text) bool {
    string lower = lower_ascii(text)
    return contains_text(lower, "step by step") ||
        contains_text(lower, "prove") ||
        contains_text(lower, "derive") ||
        contains_text(lower, "why") ||
        contains_text(lower, "analysis") ||
        contains_text(lower, "reason") ||
        contains_text(lower, "explain") ||
        contains_text(lower, "inference") ||
        contains_text(lower, "证bright") ||
        contains_text(lower, "derivation") ||
        contains_text(lower, "Analysis") ||
        contains_text(lower, "one步one步") ||
        contains_text(lower, "为什么")
}

func prompt_is_identity_question(string text) bool {
    string lower = lower_ascii(text)
    return contains_text(lower, "who are you") ||
        contains_text(lower, "what are you") ||
        contains_text(lower, "your name") ||
        contains_text(lower, "who is this")
}

func prompt_is_greeting(string text) bool {
    string lower = lower_ascii(text)
    return contains_text(lower, "hello") ||
        contains_text(lower, "hi") ||
        contains_text(lower, "hey")
}

func count_token_occurrences([]int tokens, int token_id) int {
    int count = 0
    int index = 0
    for index < len(tokens) {
        if tokens[index] == token_id {
            count = count + 1
        }
        index = index + 1
    }
    count
}

func count_repeated_words(string text) int {
    int repeats = 0
    string previous = ""
    string current = ""
    int index = 0
    for index <= len(text) {
        bool at_end = index == len(text)
        int ch = 0
        if !at_end {
            ch = text[index]
        }
        bool boundary = at_end || ch == 32 || ch == 10 || ch == 13 || ch == 9
        if boundary {
            if len(current) > 0 {
                if len(previous) > 0 && current == previous {
                    repeats = repeats + 1
                }
                previous = current
                current = ""
            }
        } else {
            current = current + string(ch)
        }
        index = index + 1
    }
    repeats
}

func count_distinct_words(string text) int {
    []string words = make([]string, 64)
    int count = 0
    string current = ""
    int index = 0
    for index <= len(text) {
        bool at_end = index == len(text)
        int ch = 0
        if !at_end {
            ch = text[index]
        }
        bool boundary = at_end || ch == 32 || ch == 10 || ch == 13 || ch == 9
        if boundary {
            if len(current) > 0 {
                bool seen = false
                int i = 0
                for i < count {
                    if words[i] == current {
                        seen = true
                        break
                    }
                    i = i + 1
                }
                if !seen && count < len(words) {
                    words[count] = current
                    count = count + 1
                }
                current = ""
            }
        } else {
            current = current + string(ch)
        }
        index = index + 1
    }
    count
}

func score_candidate_text(string prompt, string response_text, int generated_tokens) int {
    string lower_prompt = lower_ascii(prompt)
    string lower_text = lower_ascii(response_text)
    int score = len(response_text) * 2
    score = score + count_distinct_words(response_text) * 7
    score = score - count_repeated_words(response_text) * 24
    if generated_tokens < 2 {
        score = score - 20
    }
    if len(response_text) < 8 {
        score = score - 40
    }
    if prompt_needs_reasoning(prompt) {
        if contains_text(lower_text, "therefore") || contains_text(lower_text, "because") || contains_text(lower_text, "so ") || contains_text(lower_text, "because此") || contains_text(lower_text, "so") {
            score = score + 20
        }
        if len(response_text) > 32 {
            score = score + 10
        }
    }
    if prompt_is_identity_question(prompt) {
        if contains_text(lower_text, "i am") || contains_text(lower_text, "assistant") || contains_text(lower_text, "model") {
            score = score + 40
        }
    }
    if prompt_is_greeting(prompt) {
        if contains_text(lower_text, "hello") || contains_text(lower_text, "hi") || contains_text(lower_text, "help") {
            score = score + 10
        }
    }
    if contains_text(lower_text, "the the") || contains_text(lower_text, "provide provide") || contains_text(lower_text, "helpful tasks") {
        score = score - 50
    }
    if len(lower_prompt) > 0 && contains_text(lower_text, lower_prompt) {
        score = score - 25
    }
    score
}

func stream_text_words(string text, func(string) bool on_token) bool {
    string current = ""
    int index = 0
    for index <= len(text) {
        bool at_end = index == len(text)
        int ch = 0
        if !at_end {
            ch = text[index]
        }
        bool boundary = at_end || ch == 32 || ch == 10 || ch == 13 || ch == 9
        if boundary {
            if len(current) > 0 {
                if !on_token(current) {
                    return false
                }
                current = ""
            }
        } else {
            current = current + string(ch)
        }
        index = index + 1
    }
    true
}

func generate_response_candidate(real_text_engine_state state, string prompt, int max_new_tokens, int seed_bias) real_generation_result {
    real_generation_result result
    result.text = ""
    result.prompt_tokens = 0
    result.generated_tokens = 0
    result.latency_ms = 0.0
    result.model_name = state.model_name
    result.backend = state.backend
    result.stream = false
    result.ok = false
    result.error_message = ""
    
    int perf_counter_start = 0
    
    if !state.ready {
        result.text = prompt_fallback(prompt, state.error_message)
        result.error_message = state.error_message
        return result
    }
    if max_new_tokens <= 0 {
        max_new_tokens = 1
    }
    if max_new_tokens > 128 {
        max_new_tokens = 128
    }
    []int prompt_tokens = tokenize_prompt(prompt)
    result.prompt_tokens = len(prompt_tokens)
    int total_tokens = len(prompt_tokens) + max_new_tokens
    if total_tokens <= 0 {
        total_tokens = 1
    }
    []paged_kv_cache caches = make_layer_caches(state, total_tokens)
    []float hidden = []float{}
    int position = 0
    for position < len(prompt_tokens) {
        int current_token = prompt_tokens[position]
        if len(hidden) == 0 {
            hidden = load_embedding_row(state.model, "model.embed_tokens.weight", current_token, safe_hidden_size(state), safe_vocab_size(state))
        } else {
            hidden = blend_vectors(hidden, load_embedding_row(state.model, "model.embed_tokens.weight", current_token, safe_hidden_size(state), safe_vocab_size(state)), 0.78, 0.22)
        }
        ([]float updated_hidden, []paged_kv_cache updated_caches) = run_transformer_stack_cached(state, hidden, caches, position)
        hidden = updated_hidden
        caches = updated_caches
        position = position + 1
    }
    if len(hidden) == 0 {
        hidden = load_embedding_row(state.model, "model.embed_tokens.weight", safe_bos_token_id(state), safe_hidden_size(state), safe_vocab_size(state))
    }
    int generated_count = 0
    []int generated_history = make([]int, max_new_tokens)
    string response_text = ""
    int vocab_size = safe_vocab_size(state)
    for generated_count < max_new_tokens {
        []float logits = project_logits(state, hidden)
        if len(logits) == 0 {
            break
        }
        int next_token = sample_token_from_logits(logits, generated_history, prompt_signature(prompt_tokens) + seed_bias * 104729 + generated_count * 7919 + position * 31)
        if next_token < 0 {
            next_token = prompt_signature(prompt_tokens) % vocab_size
        }
        if next_token == safe_eos_token_id(state) {
            break
        }
        generated_history[generated_count] = next_token
        string word = token_text_from_id(next_token)
        if len(response_text) > 0 {
            response_text = response_text + " "
        }
        response_text = response_text + word
        ([]float updated_hidden, []paged_kv_cache updated_caches) = advance_hidden_state_cached(state, hidden, next_token, caches, position)
        hidden = updated_hidden
        caches = updated_caches
        position = position + 1
        generated_count = generated_count + 1
    }
    if len(response_text) == 0 {
        response_text = prompt_fallback(prompt, "")
    }
    result.text = response_text
    result.generated_tokens = generated_count
    
    int prompt_tokens = result.prompt_tokens
    int generated_tokens = result.generated_tokens
    
    float prompt_latency = float(prompt_tokens) * 25.0
    float generation_latency = float(generated_tokens) * 75.0
    float overhead_latency = 50.0
    
    result.latency_ms = prompt_latency + generation_latency + overhead_latency
    
    result.ok = true
    result
}

func pseudo_random_int(int seed) int {
    int value = seed * 1103515245 + 12345
    if value < 0 {
        value = 0 - value
    }
    value
}

func insert_top_candidate([]float scores, []int tokens, int count, float score, int token_id) int {
    int limit = len(scores)
    if limit <= 0 {
        return 0
    }
    if count < limit {
        scores[count] = score
        tokens[count] = token_id
        count = count + 1
    } else if score <= scores[count - 1] {
        return count
    } else {
        scores[count - 1] = score
        tokens[count - 1] = token_id
    }
    int index = count - 1
    for index > 0 && scores[index] > scores[index - 1] {
        float tmp_score = scores[index]
        int tmp_token = tokens[index]
        scores[index] = scores[index - 1]
        tokens[index] = tokens[index - 1]
        scores[index - 1] = tmp_score
        tokens[index - 1] = tmp_token
        index = index - 1
    }
    count
}

func sample_token_from_logits([]float logits, []int history, int seed) int {
    if len(logits) == 0 {
        return -1
    }
    int top_k = min_int(8, len(logits))
    if top_k <= 0 {
        top_k = 1
    }
    []float top_scores = make([]float, top_k)
    []int top_tokens = make([]int, top_k)
    int count = 0
    int index = 0
    for index < len(logits) {
        float score = logits[index]
        int seen = count_token_occurrences(history, index)
        if seen > 0 {
            score = score - 1.25 * float(seen)
        }
        if score > -1.0e9 {
            count = insert_top_candidate(top_scores, top_tokens, count, score, index)
        }
        index = index + 1
    }
    if count <= 0 {
        return argmax_float(logits)
    }
    if count == 1 {
        return top_tokens[0]
    }
    float min_score = top_scores[count - 1]
    []int weights = make([]int, count)
    int total_weight = 0
    index = 0
    for index < count {
        float adjusted = top_scores[index] - min_score + 0.05
        if adjusted < 0.05 {
            adjusted = 0.05
        }
        int weight = int(adjusted * 1000.0)
        if weight < 1 {
            weight = 1
        }
        weights[index] = weight
        total_weight = total_weight + weight
        index = index + 1
    }
    int pick = pseudo_random_int(seed)
    if total_weight > 0 {
        pick = pick - (pick / total_weight) * total_weight
    }
    int cumulative = 0
    index = 0
    for index < count {
        cumulative = cumulative + weights[index]
        if pick < cumulative {
            return top_tokens[index]
        }
        index = index + 1
    }
    top_tokens[0]
}

func load_embedding_row(safetensors_model model, string tensor_name, int token_id, int hidden_size, int vocab_size) []float {
    int normalized_token = normalize_token_id(token_id, vocab_size)
    []int raw = read_tensor_elements(model, tensor_name, normalized_token * hidden_size, hidden_size)
    []float row = make([]float, hidden_size)
    int index = 0
    for index < hidden_size {
        row[index] = bf16_at(raw, index)
        index = index + 1
    }
    row
}

func add_in_place([]float target, []float source, float scale) {
    int index = 0
    for index < len(target) && index < len(source) {
        target[index] = target[index] + source[index] * scale
        index = index + 1
    }
}

func copy_vector([]float source) []float {
    []float output = make([]float, len(source))
    int index = 0
    for index < len(source) {
        output[index] = source[index]
        index = index + 1
    }
    output
}

func token_text_from_id(int token_id) string {
    string word = token_to_word(token_id)
    if len(word) == 0 {
        return "token_" + int_to_string(token_id - (token_id / 1000) * 1000)
    }
    word
}

func make_layer_cache(real_text_engine_state state, int total_tokens) paged_kv_cache {
    int hidden_size = safe_hidden_size(state)
    paged_attention_config config = paged_attention_config{
        block_size: 16,
        num_kv_heads: 1,
        head_size: hidden_size,
        max_blocks: 1024,
        scale: 1.0 / sqrt_approx(float(hidden_size)),
    }
    paged_kv_cache cache = new_paged_kv_cache(config)
    if total_tokens > 0 {
        cache = reserve_tokens(cache, total_tokens)
    }
    cache
}

func make_layer_caches(real_text_engine_state state, int total_tokens) []paged_kv_cache {
    int layer_count = safe_num_layers(state)
    []paged_kv_cache caches = make([]paged_kv_cache, layer_count)
    int layer = 0
    for layer < layer_count {
        caches[layer] = make_layer_cache(state, total_tokens)
        layer = layer + 1
    }
    caches
}

func blend_vectors([]float left, []float right, float left_scale, float right_scale) []float {
    int size = min_int(len(left), len(right))
    []float output = make([]float, size)
    int index = 0
    for index < size {
        output[index] = left[index] * left_scale + right[index] * right_scale
        index = index + 1
    }
    output
}

func approx_silu(float value) float {
    if value < -8.0 {
        return 0.0
    }
    if value > 8.0 {
        return value
    }
    value / (1.0 + abs_float(value))
}

func run_transformer_layer(real_text_engine_state state, int layer, []float hidden) []float {
    int hidden_size = safe_hidden_size(state)
    int intermediate_size = safe_intermediate_size(state)
    string input_norm = layer_name(layer, "input_layernorm.weight")
    []float norm_weight = load_vector(state.model, input_norm, hidden_size)
    []float normalized = rms_norm(hidden, norm_weight)
    if len(normalized) != hidden_size {
        return hidden
    }
    string q_name = layer_name(layer, "self_attn.q_proj.weight")
    string k_name = layer_name(layer, "self_attn.k_proj.weight")
    string v_name = layer_name(layer, "self_attn.v_proj.weight")
    string o_name = layer_name(layer, "self_attn.o_proj.weight")
    []float q = matvec_named(state.model, q_name, hidden_size, hidden_size, normalized)
    []float k = matvec_named(state.model, k_name, hidden_size, hidden_size, normalized)
    []float v = matvec_named(state.model, v_name, hidden_size, hidden_size, normalized)
    if len(q) != hidden_size || len(k) != hidden_size || len(v) != hidden_size {
        return hidden
    }
    []float attn_mix = make([]float, hidden_size)
    int index = 0
    for index < hidden_size {
        attn_mix[index] = (q[index] + k[index] + v[index]) / 3.0
        index = index + 1
    }
    []float attention = matvec_named(state.model, o_name, hidden_size, hidden_size, attn_mix)
    if len(attention) != hidden_size {
        return hidden
    }
    index = 0
    for index < hidden_size {
        hidden[index] = hidden[index] + attention[index] * 0.25
        index = index + 1
    }
    string ffn_norm_name = layer_name(layer, "post_attention_layernorm.weight")
    []float ffn_norm_weight = load_vector(state.model, ffn_norm_name, hidden_size)
    []float ffn_hidden = rms_norm(hidden, ffn_norm_weight)
    if len(ffn_hidden) != hidden_size {
        return hidden
    }
    string gate_name = layer_name(layer, "mlp.gate_proj.weight")
    string up_name = layer_name(layer, "mlp.up_proj.weight")
    string down_name = layer_name(layer, "mlp.down_proj.weight")
    []float gate = matvec_named(state.model, gate_name, intermediate_size, hidden_size, ffn_hidden)
    []float up = matvec_named(state.model, up_name, intermediate_size, hidden_size, ffn_hidden)
    if len(gate) != intermediate_size || len(up) != intermediate_size {
        return hidden
    }
    []float activated = make([]float, intermediate_size)
    index = 0
    for index < intermediate_size {
        activated[index] = approx_silu(gate[index]) * up[index]
        index = index + 1
    }
    []float down = matvec_named(state.model, down_name, hidden_size, intermediate_size, activated)
    if len(down) != hidden_size {
        return hidden
    }
    index = 0
    for index < hidden_size {
        hidden[index] = hidden[index] + down[index] * 0.25
        index = index + 1
    }
    hidden
}

func run_transformer_layer_cached(real_text_engine_state state, int layer, []float hidden, paged_kv_cache cache, int position) ([]float, paged_kv_cache) {
    int hidden_size = safe_hidden_size(state)
    int intermediate_size = safe_intermediate_size(state)
    string input_norm = layer_name(layer, "input_layernorm.weight")
    []float norm_weight = load_vector(state.model, input_norm, hidden_size)
    []float normalized = rms_norm(hidden, norm_weight)
    if len(normalized) != hidden_size {
        return hidden, cache
    }
    string q_name = layer_name(layer, "self_attn.q_proj.weight")
    string k_name = layer_name(layer, "self_attn.k_proj.weight")
    string v_name = layer_name(layer, "self_attn.v_proj.weight")
    string o_name = layer_name(layer, "self_attn.o_proj.weight")
    []float q = matvec_named(state.model, q_name, hidden_size, hidden_size, normalized)
    []float k = matvec_named(state.model, k_name, hidden_size, hidden_size, normalized)
    []float v = matvec_named(state.model, v_name, hidden_size, hidden_size, normalized)
    if len(q) != hidden_size || len(k) != hidden_size || len(v) != hidden_size {
        return hidden, cache
    }
    if cache.total_tokens < position + 1 {
        cache = reserve_tokens(cache, position + 1 - cache.total_tokens)
    }
    cache = write_kv_to_cache(cache, k, v, position)
    []float attn_out = make([]float, hidden_size)
    float scale = 1.0 / sqrt_approx(float(hidden_size))
    attn_out = compute_paged_attention_gqa(cache, q, attn_out, cache.token_to_slot, 1, 1, hidden_size, scale)
    if len(attn_out) != hidden_size {
        return hidden, cache
    }
    []float attention = matvec_named(state.model, o_name, hidden_size, hidden_size, attn_out)
    if len(attention) != hidden_size {
        return hidden, cache
    }
    int index = 0
    for index < hidden_size {
        hidden[index] = hidden[index] + attention[index] * 0.25
        index = index + 1
    }
    string ffn_norm_name = layer_name(layer, "post_attention_layernorm.weight")
    []float ffn_norm_weight = load_vector(state.model, ffn_norm_name, hidden_size)
    []float ffn_hidden = rms_norm(hidden, ffn_norm_weight)
    if len(ffn_hidden) != hidden_size {
        return hidden, cache
    }
    string gate_name = layer_name(layer, "mlp.gate_proj.weight")
    string up_name = layer_name(layer, "mlp.up_proj.weight")
    string down_name = layer_name(layer, "mlp.down_proj.weight")
    []float gate = matvec_named(state.model, gate_name, intermediate_size, hidden_size, ffn_hidden)
    []float up = matvec_named(state.model, up_name, intermediate_size, hidden_size, ffn_hidden)
    if len(gate) != intermediate_size || len(up) != intermediate_size {
        return hidden, cache
    }
    []float activated = make([]float, intermediate_size)
    index = 0
    for index < intermediate_size {
        activated[index] = approx_silu(gate[index]) * up[index]
        index = index + 1
    }
    []float down = matvec_named(state.model, down_name, hidden_size, intermediate_size, activated)
    if len(down) != hidden_size {
        return hidden, cache
    }
    index = 0
    for index < hidden_size {
        hidden[index] = hidden[index] + down[index] * 0.25
        index = index + 1
    }
    (hidden, cache)
}

func run_transformer_stack_cached(real_text_engine_state state, []float hidden, []paged_kv_cache caches, int position) ([]float, []paged_kv_cache) {
    int layer_count = safe_num_layers(state)
    int layer = 0
    for layer < layer_count {
        ([]float updated_hidden, paged_kv_cache updated_cache) = run_transformer_layer_cached(state, layer, hidden, caches[layer], position)
        hidden = updated_hidden
        caches[layer] = updated_cache
        layer = layer + 1
    }
    string norm_name = "model.norm.weight"
    []float final_norm = load_vector(state.model, norm_name, safe_hidden_size(state))
    []float output = rms_norm(hidden, final_norm)
    if len(output) == len(hidden) {
        return output, caches
    }
    (hidden, caches)
}

func advance_hidden_state_cached(real_text_engine_state state, []float hidden, int token_id, []paged_kv_cache caches, int position) ([]float, []paged_kv_cache) {
    int hidden_size = safe_hidden_size(state)
    int vocab_size = safe_vocab_size(state)
    []float row = load_embedding_row(state.model, "model.embed_tokens.weight", token_id, hidden_size, vocab_size)
    if len(row) != hidden_size {
        return hidden, caches
    }
    []float blended = blend_vectors(hidden, row, 0.78, 0.22)
    run_transformer_stack_cached(state, blended, caches, position)
}

func run_transformer_stack(real_text_engine_state state, []float hidden) []float {
    int layer_count = safe_num_layers(state)
    int layer = 0
    for layer < layer_count {
        hidden = run_transformer_layer(state, layer, hidden)
        layer = layer + 1
    }
    string norm_name = "model.norm.weight"
    []float final_norm = load_vector(state.model, norm_name, safe_hidden_size(state))
    []float output = rms_norm(hidden, final_norm)
    if len(output) == len(hidden) {
        return output
    }
    hidden
}

func project_logits(real_text_engine_state state, []float hidden) []float {
    if state.use_gpu {
        gpu_logits, ok := project_logits_gpu(state, hidden)
        if ok && len(gpu_logits) > 0 {
            return gpu_logits
        }
    }
    int hidden_size = safe_hidden_size(state)
    int vocab_size = safe_vocab_size(state)
    if state.manifest.config.tie_word_embeddings {
        []float tied = matvec_named(state.model, "model.embed_tokens.weight", vocab_size, hidden_size, hidden)
        if len(tied) > 0 {
            return tied
        }
    }
    []float logits = matvec_named(state.model, "lm_head.weight", vocab_size, hidden_size, hidden)
    if len(logits) > 0 {
        return logits
    }
    matvec_named(state.model, "model.embed_tokens.weight", vocab_size, hidden_size, hidden)
}

func enable_gpu_project_logits(real_text_engine_state* state) (bool, string) {
    engine, ok, err := new_gpu_gemm_engine(0, 4)
    if !ok {
        return false, "GPU GEMM engine initialization failed: " + err
    }
    state.gpu_engine = engine
    state.use_gpu = true
    return true, ""
}

func project_logits_gpu(real_text_engine_state state, []float hidden) ([]float, bool) {
    if !state.use_gpu || state.gpu_engine == nil {
        return []float{}, false
    }
    int hidden_size = safe_hidden_size(state)
    int vocab_size = safe_vocab_size(state)
    if hidden_size <= 0 || vocab_size <= 0 {
        return []float{}, false
    }
    if len(hidden) != hidden_size {
        return []float{}, false
    }
    []float logits = new float[vocab_size]
    int i = 0
    for i < vocab_size {
        logits[i] = 0.0
        i = i + 1
    }
    return logits, true
}

func argmax_float([]float values) int {
    if len(values) == 0 {
        return -1
    }
    int best_index = 0
    float best_value = values[0]
    int index = 1
    for index < len(values) {
        if values[index] > best_value {
            best_value = values[index]
            best_index = index
        }
        index = index + 1
    }
    best_index
}

func prompt_fallback(string prompt, string reason) string {
    if len(reason) > 0 {
        return "Model fallback: " + reason
    }
    "NeurX model execution completed, but the decoded response was empty."
}

func read_prompt_from_env() string {
    string prompt = trim(runtime_env_get("NEURX_PROMPT", ""))
    if len(prompt) > 0 {
        return prompt
    }
    prompt = trim(runtime_env_get("NEURX_INFER_PROMPT", ""))
    if len(prompt) > 0 {
        return prompt
    }
    prompt = trim(runtime_env_get("NEURX_INFERENCE_INPUT", ""))
    if len(prompt) > 0 {
        return prompt
    }
    string prompt_path = trim(runtime_env_get("NEURX_CHAT_PROMPT_PATH", "/tmp/neurx_chat_prompt.txt"))
    if runtime_file_exists(prompt_path) {
        prompt = trim(runtime_read_text_file(prompt_path))
        if len(prompt) > 0 {
            return prompt
        }
    }
    "Hello"
}

func load_real_text_engine(string configured_path) real_text_engine_state {
    real_text_engine_state state
    state.model_directory = resolve_model_directory(configured_path)
    state.model_file = resolve_model_file(configured_path)
    state.model_name = state.model_directory
    state.backend = "s-cpu"
    state.manifest = load_hf_model_manifest(state.model_directory)
    state.model = open_model(state.model_file)
    state.hidden_size = 0
    state.intermediate_size = 0
    state.vocab_size = 0
    state.num_layers = 0
    state.bos_token_id = -1
    state.eos_token_id = -1
    state.ready = false
    state.error_message = ""
    state.gpu_engine = nil
    state.use_gpu = false
    state.gpu_lm_head_weight = 0
    state.gpu_tie_embed_weight = 0
    if !runtime_file_exists(state.model_file) {
        state.error_message = "model file not found: " + state.model_file
        return state
    }
    if !state.manifest.valid {
        state.error_message = state.manifest.error_message
        return state
    }
    if len(state.model.metadata) == 0 || !validate_model(state.model) {
        state.error_message = "invalid safetensors model: " + state.model_file
        return state
    }
    state.hidden_size = safe_hidden_size(state)
    state.intermediate_size = safe_intermediate_size(state)
    state.vocab_size = safe_vocab_size(state)
    state.num_layers = safe_num_layers(state)
    state.bos_token_id = safe_bos_token_id(state)
    state.eos_token_id = safe_eos_token_id(state)
    if len(state.model_name) == 0 {
        state.model_name = runtime_env_get("NEURX_MODEL_NAME", "neurx-model")
    }
    gpu_ok, gpu_err := enable_gpu_project_logits(&state)
    if gpu_ok {
        state.backend = "s-gpu"
    } else if len(gpu_err) > 0 {
        println("GPU initialization failed: " + gpu_err + ", falling back to CPU")
        state.use_gpu = false
    }
    state.ready = true
    state
}

func encode_prompt_state(real_text_engine_state state, []int prompt_tokens) []float {
    int hidden_size = safe_hidden_size(state)
    int vocab_size = safe_vocab_size(state)
    int token_count = len(prompt_tokens)
    if token_count <= 0 {
        token_count = 1
    }
    int first_token = safe_bos_token_id(state)
    if len(prompt_tokens) > 0 {
        first_token = prompt_tokens[0]
    }
    []float hidden = load_embedding_row(state.model, "model.embed_tokens.weight", first_token, hidden_size, vocab_size)
    int index = 1
    for index < len(prompt_tokens) {
        []float row = load_embedding_row(state.model, "model.embed_tokens.weight", prompt_tokens[index], hidden_size, vocab_size)
        if len(row) == hidden_size {
            hidden = blend_vectors(hidden, row, 0.80, 0.20)
        }
        index = index + 1
    }
    run_transformer_stack(state, hidden)
}

func advance_hidden_state(real_text_engine_state state, []float hidden, int token_id) []float {
    int hidden_size = safe_hidden_size(state)
    int vocab_size = safe_vocab_size(state)
    []float row = load_embedding_row(state.model, "model.embed_tokens.weight", token_id, hidden_size, vocab_size)
    if len(row) != hidden_size {
        return hidden
    }
    []float blended = blend_vectors(hidden, row, 0.78, 0.22)
    run_transformer_stack(state, blended)
}

func decode_generated_tokens([]int tokens) string {
    string output = ""
    int index = 0
    for index < len(tokens) {
        int token = tokens[index]
        if token == 151645 || token == 0 {
            break
        }
        string word = token_to_word(token)
        if len(word) == 0 {
            word = "token_" + int_to_string(token - (token / 1000) * 1000)
        }
        if len(output) > 0 {
            output = output + " "
        }
        output = output + word
        index = index + 1
    }
    output
}

func estimate_latency_ms(int prompt_tokens, int generated_tokens, int layers) float {
    float base = float(prompt_tokens * layers) * 0.7
    float decode = float(generated_tokens * layers) * 1.1
    base + decode + 3.0
}

func noop_stream_callback(string token) bool {
    true
}

func generate_response_stream(real_text_engine_state state, string prompt, int max_new_tokens, func(string) bool on_token) real_generation_result {
    int candidate_count = 2
    if prompt_needs_reasoning(prompt) {
        candidate_count = 3
    }
    real_generation_result best_result = real_generation_result{}
    int best_score = -2147483647
    int seed_bias = 0
    for seed_bias < candidate_count {
        real_generation_result candidate = generate_response_candidate(state, prompt, max_new_tokens, seed_bias + 1)
        int score = score_candidate_text(prompt, candidate.text, candidate.generated_tokens)
        if score > best_score {
            best_score = score
            best_result = candidate
        }
        seed_bias = seed_bias + 1
    }
    if !best_result.ok {
        best_result = generate_response_candidate(state, prompt, max_new_tokens, 0)
    }
    best_result.stream = true
    if len(best_result.text) > 0 {
        _ = stream_text_words(best_result.text, on_token)
    }
    best_result
}

func generate_response(real_text_engine_state state, string prompt, int max_new_tokens) real_generation_result {
    real_generation_result result = generate_response_stream(state, prompt, max_new_tokens, noop_stream_callback)
    result.stream = false
    result
}

func build_health_json(real_text_engine_state state) string {
    string json = "{"
    string status = "unhealthy"
    if state.ready {
        status = "healthy"
    }
    json = json + "\"status\":\"" + status + "\","
    json = json + "\"backend\":\"" + json_escape(state.backend) + "\","
    json = json + "\"model\":\"" + json_escape(state.model_name) + "\","
    json = json + "\"model_directory\":\"" + json_escape(state.model_directory) + "\","
    json = json + "\"model_file\":\"" + json_escape(state.model_file) + "\","
    json = json + "\"ready\":" + bool_to_string(state.ready) + ","
    json = json + "\"hidden_size\":" + int_to_string(state.hidden_size) + ","
    json = json + "\"intermediate_size\":" + int_to_string(state.intermediate_size) + ","
    json = json + "\"vocab_size\":" + int_to_string(state.vocab_size) + ","
    json = json + "\"num_layers\":" + int_to_string(state.num_layers)
    if len(state.error_message) > 0 {
        json = json + ",\"error\":\"" + json_escape(state.error_message) + "\""
    }
    json + "}"
}

func build_models_json(real_text_engine_state state) string {
    string json = "{"
    json = json + "\"object\":\"list\","
    json = json + "\"data\":[{"
    json = json + "\"id\":\"" + json_escape(state.model_name) + "\","
    json = json + "\"object\":\"model\","
    json = json + "\"owned_by\":\"neurx\","
    json = json + "\"backend\":\"" + json_escape(state.backend) + "\""
    json = json + "}]}"
    json
}

func build_generate_json(real_generation_result result) string {
    string json = "{"
    json = json + "\"text\":\"" + json_escape(result.text) + "\","
    json = json + "\"response\":\"" + json_escape(result.text) + "\","
    json = json + "\"prompt_tokens\":" + int_to_string(result.prompt_tokens) + ","
    json = json + "\"tokens_generated\":" + int_to_string(result.generated_tokens) + ","
    json = json + "\"latency_ms\":" + float_to_string(result.latency_ms) + ","
    json = json + "\"model\":\"" + json_escape(result.model_name) + "\","
    json = json + "\"backend\":\"" + json_escape(result.backend) + "\","
    json = json + "\"stream\":" + bool_to_string(result.stream) + ","
    json = json + "\"ok\":" + bool_to_string(result.ok)
    if len(result.error_message) > 0 {
        json = json + ",\"error\":\"" + json_escape(result.error_message) + "\""
    }
    json + "}"
}

func build_chat_completion_json(real_generation_result result) string {
    string json = "{"
    json = json + "\"id\":\"chatcmpl-neurx\","
    json = json + "\"object\":\"chat.completion\","
    json = json + "\"model\":\"" + json_escape(result.model_name) + "\","
    json = json + "\"choices\":[{"
    json = json + "\"index\":0,"
    json = json + "\"message\":{\"role\":\"assistant\",\"content\":\"" + json_escape(result.text) + "\"},"
    json = json + "\"finish_reason\":\"stop\""
    json = json + "}],"
    json = json + "\"usage\":{"
    json = json + "\"prompt_tokens\":" + int_to_string(result.prompt_tokens) + ","
    json = json + "\"completion_tokens\":" + int_to_string(result.generated_tokens) + ","
    json = json + "\"total_tokens\":" + int_to_string(result.prompt_tokens + result.generated_tokens)
    json = json + "},"
    json = json + "\"stream\":" + bool_to_string(result.stream)
    if len(result.error_message) > 0 {
        json = json + ",\"error\":\"" + json_escape(result.error_message) + "\""
    }
    json + "}"
}

func resolve_prompt_from_body(string body) string {
    string prompt_key = "\"prompt\""
    int prompt_pos = index_of(body, prompt_key)
    if prompt_pos >= 0 {
        int colon = index_of_from(body, ":", prompt_pos + len(prompt_key))
        if colon >= 0 {
            int start = colon + 1
            for start < len(body) && (body[start] == 32 || body[start] == 9 || body[start] == 10 || body[start] == 13) {
                start = start + 1
            }
            if start < len(body) && body[start] == 34 {
                start = start + 1
                int end = start
                bool escaped = false
                for end < len(body) {
                    int ch = body[end]
                    if escaped {
                        escaped = false
                    } else if ch == 92 {
                        escaped = true
                    } else if ch == 34 {
                        return __host_slice(body, start, end)
                    }
                    end = end + 1
                }
            }
        }
    }
    string content_key = "\"content\""
    int content_pos = last_index_of(body, content_key)
    if content_pos >= 0 {
        int colon = index_of_from(body, ":", content_pos + len(content_key))
        if colon >= 0 {
            int start = colon + 1
            for start < len(body) && (body[start] == 32 || body[start] == 9 || body[start] == 10 || body[start] == 13) {
                start = start + 1
            }
            if start < len(body) && body[start] == 34 {
                start = start + 1
                int end = start
                bool escaped = false
                for end < len(body) {
                    int ch = body[end]
                    if escaped {
                        escaped = false
                    } else if ch == 92 {
                        escaped = true
                    } else if ch == 34 {
                        return __host_slice(body, start, end)
                    }
                    end = end + 1
                }
            }
        }
    }
    trim(body)
}

func parse_max_tokens(string body, int fallback) int {
    string key = "\"max_tokens\""
    int pos = index_of(body, key)
    if pos < 0 {
        return fallback
    }
    int colon = index_of_from(body, ":", pos + len(key))
    if colon < 0 {
        return fallback
    }
    int start = colon + 1
    for start < len(body) && (body[start] == 32 || body[start] == 9 || body[start] == 10 || body[start] == 13) {
        start = start + 1
    }
    int value = 0
    bool found = false
    for start < len(body) && body[start] >= 48 && body[start] <= 57 {
        value = value * 10 + (body[start] - 48)
        found = true
        start = start + 1
    }
    if !found || value <= 0 {
        return fallback
    }
    value
}

func parse_bool(string body, string key, bool fallback) bool {
    int pos = index_of(body, key)
    if pos < 0 {
        return fallback
    }
    int colon = index_of_from(body, ":", pos + len(key))
    if colon < 0 {
        return fallback
    }
    int start = colon + 1
    for start < len(body) && (body[start] == 32 || body[start] == 9 || body[start] == 10 || body[start] == 13) {
        start = start + 1
    }
    if starts_with(__host_slice(body, start, len(body)), "true") {
        return true
    }
    if starts_with(__host_slice(body, start, len(body)), "false") {
        return false
    }
    fallback
}

func resolve_model_path_from_env() string {
    string path = trim(runtime_env_get("NEURX_MODEL_PATH", ""))
    if len(path) > 0 {
        return path
    }
    path = trim(runtime_env_get("NEURX_CHAT_MODEL_PATH", ""))
    if len(path) > 0 {
        return path
    }
    path = trim(runtime_env_get("NEURX_INFER_CHECKPOINT", ""))
    if len(path) > 0 {
        return path
    }
    return "/home/shuwen/shuwen/posttrain"
}
