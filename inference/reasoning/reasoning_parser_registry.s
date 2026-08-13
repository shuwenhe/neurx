package neurx.inference.reasoning.reasoning_parser_registry
func reasoning_parser_none() int { 0 }

func reasoning_parser_deepseek_r1() int { 1 }

func reasoning_parser_deepseek_v3() int { 2 }

func reasoning_parser_qwen3() int { 3 }

func reasoning_parser_kimi() int { 4 }

func reasoning_parser_mistral() int { 5 }

func reasoning_parser_gpt_oss() int { 6 }

func reasoning_parser_granite() int { 7 }

func reasoning_parser_step3() int { 8 }

struct reasoning_parser_config {
    int backend
    string start_token
    string end_token
    bool enabled
}
struct reasoning_parse_result {
    string reasoning_content
    string content
    bool reasoning_complete
    bool valid
}
struct reasoning_stream_state {
    reasoning_parser_config config
    string buffered_text
    string reasoning_content
    string content
    bool reasoning_started
    bool reasoning_complete
    bool initialized
}
func reasoning_config_for(int backend) reasoning_parser_config {
    if backend == reasoning_parser_deepseek_r1() || backend == reasoning_parser_deepseek_v3() || backend == reasoning_parser_qwen3() || backend == reasoning_parser_kimi() { return reasoning_parser_config {backend: backend, start_token: "<think>", end_token: "</think>", enabled: true} }
    if backend == reasoning_parser_mistral() { return reasoning_parser_config {backend: backend, start_token: "[THINK]", end_token: "[/THINK]", enabled: true} }
    if backend == reasoning_parser_gpt_oss() { return reasoning_parser_config {backend: backend, start_token: "<|channel|>analysis<|message|>", end_token: "<|end|>", enabled: true} }
    if backend == reasoning_parser_granite() { return reasoning_parser_config {backend: backend, start_token: "<think>", end_token: "</think>", enabled: true} }
    if backend == reasoning_parser_step3() { return reasoning_parser_config {backend: backend, start_token: "<reasoning>", end_token: "</reasoning>", enabled: true} }
    reasoning_parser_config {backend: reasoning_parser_none(), start_token: "", end_token: "", enabled: false}
}
func reasoning_find(string text, string pattern, int start) int {
    if len(pattern) == 0 || start < 0 { return 0 - 1 }
    int i = start
    while i + len(pattern) <= len(text) {
        int j = 0
        while j < len(pattern) && text[i + j] == pattern[j] { j = j + 1 }
        if j == len(pattern) { return i }
        i = i + 1
    }
    0 - 1
}
func reasoning_copy_range(string text, int start, int end) string {
    string output = ""
    int from = start
    int to = end
    if from < 0 { from = 0 }
    if to > len(text) { to = len(text) }
    int i = from
    while i < to { output = output + string(text[i]); i = i + 1 }
    output
}
func parse_reasoning_text(reasoning_parser_config config, string text) reasoning_parse_result {
    if !config.enabled { return reasoning_parse_result {reasoning_content: "", content: text, reasoning_complete: true, valid: true} }
    int start = reasoning_find(text, config.start_token, 0)
    if start < 0 { return reasoning_parse_result {reasoning_content: "", content: text, reasoning_complete: false, valid: true} }
    int reasoning_start = start + len(config.start_token)
    int finish = reasoning_find(text, config.end_token, reasoning_start)
    if finish < 0 { return reasoning_parse_result {reasoning_content: reasoning_copy_range(text, reasoning_start, len(text)), content: reasoning_copy_range(text, 0, start), reasoning_complete: false, valid: true} }
    string prefix = reasoning_copy_range(text, 0, start)
    string suffix = reasoning_copy_range(text, finish + len(config.end_token), len(text))
    reasoning_parse_result {reasoning_content: reasoning_copy_range(text, reasoning_start, finish), content: prefix + suffix, reasoning_complete: true, valid: true}
}
func init_reasoning_stream(int backend) reasoning_stream_state {
    reasoning_parser_config config = reasoning_config_for(backend)
    reasoning_stream_state {config: config, buffered_text: "", reasoning_content: "", content: "", reasoning_started: false, reasoning_complete: !config.enabled, initialized: backend == reasoning_parser_none() || config.enabled}
}
func consume_reasoning_delta(reasoning_stream_state state, string delta, bool final_delta) reasoning_stream_state {
    state.buffered_text = state.buffered_text + delta
    reasoning_parse_result parsed = parse_reasoning_text(state.config, state.buffered_text)
    state.reasoning_content = parsed.reasoning_content
    state.content = parsed.content
    state.reasoning_started = reasoning_find(state.buffered_text, state.config.start_token, 0) >= 0
    state.reasoning_complete = parsed.reasoning_complete || (final_delta && !state.reasoning_started)
    state
}
