package neurx.inference.engine.v1_api_engine

import "core"
import "engine"
use neurx.inference.reasoning.reasoning_parser_registry.{reasoning_parser_none, reasoning_config_for, parse_reasoning_text, reasoning_parser_deepseek_r1, reasoning_parser_deepseek_v3, reasoning_parser_qwen3, reasoning_parser_kimi, reasoning_parser_mistral, reasoning_parser_gpt_oss, reasoning_parser_granite, reasoning_parser_step3}

struct v1_request {
    request_id         string
    model             string
    messages          int[]erface{}
    max_tokens         int32
    temperature       float32
    top_p              float32
    top_k              int32
    frequency_penalty  float32
    presence_penalty   float32
    stream            bool
    stop              string[]
    tools             int[]erface{}
    tool_choice        interface{}
}

struct v1_response {
    id                string
    object            string
    created           int64
    model             string
    content           []map[string]interface{}
    stop_reason        string
    usage             map[string]int32
}

struct v1_stream_response {
    id                string
    object            string
    created           int64
    model             string
    choices           []map[string]interface{}
    usage             map[string]int32
}

type reasoning_mode string

const (
    reasoning_mode_direct            reasoning_mode = "direct"
    reasoning_mode_beam              reasoning_mode = "beam"
    reasoning_mode_self_consistency   reasoning_mode = "self_consistency"
)

struct reasoning_candidate {
    text      string
    reasoning string
    score     int32
    seed      int64
}

func lower_ascii(text string) string {
    out := ""
    for i := 0; i < len(text); i++ {
        ch := text[i]
        if ch >= 'A' && ch <= 'Z' {
            ch = ch + 32
        }
        out = out + string(ch)
    }
    return out
}

func contains_text(text string, needle string) bool {
    if len(needle) == 0 {
        return true
    }
    if len(text) < len(needle) {
        return false
    }

    for i := 0; i <= len(text)-len(needle); i++ {
        matched := true
        for j := 0; j < len(needle); j++ {
            if text[i+j] != needle[j] {
                matched = false
                break
            }
        }
        if matched {
            return true
        }
    }

    return false
}

func trim_text(text string) string {
    start := 0
    end := len(text)

    for start < end {
        ch := text[start]
        if ch != ' ' && ch != '\n' && ch != '\r' && ch != '\t' {
            break
        }
        start = start + 1
    }

    for end > start {
        ch := text[end-1]
        if ch != ' ' && ch != '\n' && ch != '\r' && ch != '\t' {
            break
        }
        end = end - 1
    }

    return text[start:end]
}

func hash_text(text string) int64 {
    hash := int64(1469598103934665603)
    for i := 0; i < len(text); i++ {
        hash = hash ^ int64(text[i])
        hash = hash * 1099511628211
        if hash < 0 {
            hash = 0 - hash
        }
    }
    if hash == 0 {
        hash = 1
    }
    return hash
}

func estimate_tokens(text string) int32 {
    count := int32(len(text) / 4)
    if count < 1 {
        count = 1
    }
    return count
}

func model_is_reasoning_focused(model string) bool {
    lower := lower_ascii(model)
    return contains_text(lower, "qwen3") ||
        contains_text(lower, "deepseek-r1") ||
        contains_text(lower, "deepseek-v3") ||
        contains_text(lower, "kimi") ||
        contains_text(lower, "mistral") ||
        contains_text(lower, "gpt-oss") ||
        contains_text(lower, "granite") ||
        contains_text(lower, "step3") ||
        contains_text(lower, "reasoning")
}

func model_uses_qwen_style(model string) bool {
    lower := lower_ascii(model)
    return contains_text(lower, "qwen") ||
        contains_text(lower, "deepseek") ||
        contains_text(lower, "kimi") ||
        contains_text(lower, "granite") ||
        contains_text(lower, "step3")
}

func model_uses_mistral_style(model string) bool {
    return contains_text(lower_ascii(model), "mistral")
}

func model_uses_gpt_oss_style(model string) bool {
    lower := lower_ascii(model)
    return contains_text(lower, "gpt-oss") || contains_text(lower, "gpt_oss")
}

func reasoning_backend_for_model(model string) int {
    lower := lower_ascii(model)
    if contains_text(lower, "deepseek-r1") {
        return reasoning_parser_deepseek_r1()
    }
    if contains_text(lower, "deepseek-v3") {
        return reasoning_parser_deepseek_v3()
    }
    if contains_text(lower, "qwen3") {
        return reasoning_parser_qwen3()
    }
    if contains_text(lower, "kimi") {
        return reasoning_parser_kimi()
    }
    if contains_text(lower, "mistral") {
        return reasoning_parser_mistral()
    }
    if contains_text(lower, "gpt-oss") || contains_text(lower, "gpt_oss") {
        return reasoning_parser_gpt_oss()
    }
    if contains_text(lower, "granite") {
        return reasoning_parser_granite()
    }
    if contains_text(lower, "step3") {
        return reasoning_parser_step3()
    }
    return reasoning_parser_none()
}

func reasoning_markers_for_model(model string) (string, string) {
    if model_uses_mistral_style(model) {
        return "[THINK]", "[/THINK]"
    }
    if model_uses_gpt_oss_style(model) {
        return "<|channel|>analysis<|message|>", "<|end|>"
    }
    if contains_text(lower_ascii(model), "step3") {
        return "<reasoning>", "</reasoning>"
    }
    return "<think>", "</think>"
}

func prompt_needs_reasoning(text string) bool {
    lower := lower_ascii(text)
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

func build_system_prompt(model string, request_reasoning bool) string {
    system_prompt := "You are a helpful assistant."

    if request_reasoning {
        system_prompt = "You are a careful assistant that reasons step by step before answering."
        if reasoning_backend_for_model(model) != reasoning_parser_none() {
            system_prompt = system_prompt + " Use the model's native reasoning format when it is helpful, then return only the final answer outside the reasoning trace."
        }
    }

    return system_prompt
}

func build_chat_prompt(req *v1_request) string {
    request_reasoning := false
    system_prompt := ""

    for _, msg := range req.messages {
        msg_map := msg.(map[string]interface{})
        role := msg_map["role"].(string)
        content := msg_map["content"].(string)

        if role == "system" {
            system_prompt = content
            continue
        }

        if role == "user" && prompt_needs_reasoning(content) {
            request_reasoning = true
        }
    }

    if len(system_prompt) == 0 {
        system_prompt = build_system_prompt(req.model, request_reasoning)
    } else if request_reasoning {
        system_prompt = system_prompt + "\n" + build_system_prompt(req.model, request_reasoning)
    }

    if model_uses_qwen_style(req.model) {
        prompt := "<|im_start|>system\n" + system_prompt + "\n<|im_end|>\n"
        for _, msg := range req.messages {
            msg_map := msg.(map[string]interface{})
            role := msg_map["role"].(string)
            content := msg_map["content"].(string)

            if role == "system" {
                continue
            }

        if role == "tool" {
            prompt = prompt + "<|im_start|>system\nTool output: " + content + "\n<|im_end|>\n"
            continue
        }

            prompt = prompt + "<|im_start|>" + role + "\n" + content + "\n<|im_end|>\n"
        }
        return prompt + "<|im_start|>assistant\n"
    }

    if model_uses_mistral_style(req.model) {
        prompt := "<s>[INST] " + system_prompt + "\n\n"
        for _, msg := range req.messages {
            msg_map := msg.(map[string]interface{})
            role := msg_map["role"].(string)
            content := msg_map["content"].(string)
            if role == "system" {
                continue
            }
            if role == "user" {
                prompt = prompt + content + " [/INST]\n"
            } else if role == "assistant" {
                prompt = prompt + content + " [INST] "
            }
        }
        return prompt
    }

    if model_uses_gpt_oss_style(req.model) {
        prompt := system_prompt + "\n"
        for _, msg := range req.messages {
            msg_map := msg.(map[string]interface{})
            role := msg_map["role"].(string)
            content := msg_map["content"].(string)
            if role == "system" {
                continue
            }
            prompt = prompt + role + ": " + content + "\n"
        }
        return prompt + "assistant: "
    }

    prompt := "System: " + system_prompt + "\n"
    for _, msg := range req.messages {
        msg_map := msg.(map[string]interface{})
        role := msg_map["role"].(string)
        content := msg_map["content"].(string)

        if role == "system" {
            continue
        }

        prompt = prompt + role + ": " + content + "\n"
    }

    return prompt + "assistant: "
}

func split_reasoning_output(model string, text string) (string, string, bool) {
    backend := reasoning_backend_for_model(model)
    if backend == reasoning_parser_none() {
        return "", trim_text(text), false
    }

    parsed := parse_reasoning_text(reasoning_config_for(backend), text)
    reasoning := trim_text(parsed.reasoning_content)
    answer := trim_text(parsed.content)
    if len(answer) == 0 {
        answer = trim_text(text)
    }

    return reasoning, answer, parsed.valid
}

func index_text(text string, needle string, start int) int {
    if len(needle) == 0 {
        return start
    }
    if start < 0 {
        start = 0
    }
    if len(text) < len(needle) {
        return -1
    }
    for i := start; i <= len(text)-len(needle); i++ {
        matched := true
        for j := 0; j < len(needle); j++ {
            if text[i+j] != needle[j] {
                matched = false
                break
            }
        }
        if matched {
            return i
        }
    }
    return -1
}

func score_reasoned_candidate(prompt string, answer string, reasoning string) int32 {
    cleaned_answer := trim_text(answer)
    cleaned_reasoning := trim_text(reasoning)
    if len(cleaned_answer) == 0 {
        return -1000000
    }

    score := int32(len(cleaned_answer))
    if len(cleaned_reasoning) > 0 {
        score = score + 60
    }

    lower_answer := lower_ascii(cleaned_answer)
    lower_prompt := lower_ascii(prompt)

    if contains_text(lower_answer, "```") || contains_text(lower_answer, "#include") || contains_text(lower_answer, "package main") {
        score = score + 20
    }

    if prompt_needs_reasoning(lower_prompt) {
        if contains_text(lower_answer, "therefore") || contains_text(lower_answer, "because") || contains_text(cleaned_answer, "because此") || contains_text(cleaned_answer, "so") {
            score = score + 20
        }
        if len(cleaned_answer) > 80 {
            score = score + 10
        }
    }

    if len(cleaned_answer) < 12 {
        score = score - 20
    }

    if len(cleaned_answer) > 4096 {
        score = score - 100
    }

    return score
}

func build_sampling_params(req *v1_request, seed int64) engine.sampling_params {
    temperature := req.temperature
    if temperature < 0 {
        temperature = 0
    }
    if temperature > 2.0 {
        temperature = 2.0
    }

    top_p := req.top_p
    if top_p <= 0 {
        top_p = 1.0
    }
    if top_p > 1.0 {
        top_p = 1.0
    }

    top_k := req.top_k
    if top_k <= 0 {
        top_k = 40
    }

    max_tokens := req.max_tokens
    if max_tokens <= 0 {
        max_tokens = 512
    }

    return engine.sampling_params{
        temperature:      temperature,
        top_p:            top_p,
        top_k:            top_k,
        top_n_tokens:     5,
        max_tokens:       max_tokens,
        min_tokens:       1,
        repetition_penalty: 1.0,
        frequency_penalty: req.frequency_penalty,
        presence_penalty:  req.presence_penalty,
        length_penalty:    1.0,
        early_stop:        false,
        stop:              req.stop,
        skip_special_tokens: true,
        spaces_between_special: false,
        seed:              seed,
    }
}

func run_reasoned_generation(ve *v1_engine, req *v1_request, prompt string) (string, string, error) {
    base_seed := hash_text(req.request_id + "|" + req.model + "|" + prompt)
    profile := reasoning_mode_direct
    candidate_count := 1

    request_reasoning := prompt_needs_reasoning(prompt)
    if request_reasoning {
        candidate_count = 3
        profile = reasoning_mode_self_consistency
        if req.temperature <= 0.2 {
            candidate_count = 2
            profile = reasoning_mode_beam
        }
        if req.temperature > 0.9 {
            candidate_count = 4
        }
    }

    best_text := ""
    best_reasoning := ""
    best_score := int32(-1000000000)

    for i := 0; i < candidate_count; i++ {
        candidate_seed := base_seed + int64((i+1)*7919)
        candidate_params := build_sampling_params(req, candidate_seed)
        if candidate_count > 1 && i > 0 {
            candidate_params.temperature = candidate_params.temperature + float32(i)*0.12
            if candidate_params.temperature > 1.2 {
                candidate_params.temperature = 1.2
            }
            if candidate_params.top_p < 1.0 {
                candidate_params.top_p = candidate_params.top_p + float32(i)*0.03
                if candidate_params.top_p > 1.0 {
                    candidate_params.top_p = 1.0
                }
            }
        }

        text, err := ve.engine.generate_completion(prompt, candidate_params)
        if err != nil {
            continue
        }

        reasoning, answer, has_reasoning := split_reasoning_output(req.model, text)
        if len(answer) == 0 {
            answer = text
        }

        score := score_reasoned_candidate(prompt, answer, reasoning)
        if has_reasoning && len(reasoning) > 0 {
            score = score + 10
        }

        if candidate_count > 1 && profile == reasoning_mode_beam && i == 0 {
            score = score + 5
        }

        if score > best_score {
            best_score = score
            best_text = answer
            best_reasoning = reasoning
        }
    }

    if len(best_text) == 0 {
        fallback_params := build_sampling_params(req, base_seed)
        text, err := ve.engine.generate_completion(prompt, fallback_params)
        if err != nil {
            return "", "", err
        }
        reasoning, answer, _ := split_reasoning_output(req.model, text)
        if len(answer) == 0 {
            answer = text
        }
        return answer, reasoning, nil
    }

    return best_text, best_reasoning, nil
}

struct request_pool {
    max_size           int32
    requests          []*v1_request
    indices           map[string]int32
}

struct v1_engine {
    engine            *engine.llm_engine
    async_engine       *engine.async_llm_engine
    request_pool       *request_pool
    is_initialized     bool
}

func new_request_pool(max_size int32) *request_pool {
    return *request_pool{
        max_size:  max_size,
        requests: make([]*v1_request, 0, max_size),
        indices:  make(map[string]int32),
    }
}

func (request_pool* rp) add(v1_request* req) error {
    if int32(len(rp.requests)) >= rp.max_size {
        return core.Errorf("request pool full")
    }

    rp.indices[req.request_id] = int32(len(rp.requests))
    rp.requests = append(rp.requests, req)

    return nil
}

func (request_pool* rp) get(request_id string) *v1_request {
    if idx, exists := rp.indices[request_id]; exists {
        if idx >= 0 && idx < int32(len(rp.requests)) {
            return rp.requests[idx]
        }
    }
    return nil
}

func (request_pool* rp) remove(request_id string) {
    if idx, exists := rp.indices[request_id]; exists {
        if idx >= 0 && idx < int32(len(rp.requests)) {
            rp.requests = append(rp.requests[:idx], rp.requests[idx+1:]...)
        }
        delete(rp.indices, request_id)
    }
}

func (request_pool* rp) size() int32 {
    return int32(len(rp.requests))
}

func new_v1_engine(eng *engine.llm_engine) *v1_engine {
    return *v1_engine{
        engine:        eng,
        request_pool:   new_request_pool(256),
        is_initialized: false,
    }
}

func (v1_engine* ve) set_async_engine(async_eng *engine.async_llm_engine) {
    ve.async_engine = async_eng
}

func (v1_engine* ve) initialize() error {
    if ve.engine == nil {
        return core.Errorf("base engine not set")
    }

    ve.is_initialized = true
    core.Println("V1Engine initialized")

    return nil
}

func (v1_engine* ve) prepare_request(v1_request* req) error {
    if !ve.is_initialized {
        return core.Errorf("engine not initialized")
    }

    if req.request_id == "" {
        req.request_id = core.GenerateId()
    }

    if req.max_tokens <= 0 {
        req.max_tokens = 1024
    }

    if req.temperature < 0 || req.temperature > 2.0 {
        req.temperature = 0.7
    }

    if req.top_p < 0 || req.top_p > 1.0 {
        req.top_p = 1.0
    }

    return ve.request_pool.add(req)
}

func (v1_engine* ve) execute(v1_request* req) (*v1_response, error) {
    if !ve.is_initialized {
        return nil, core.Errorf("engine not initialized")
    }

    prompt := build_chat_prompt(req)
    generated_text, reasoning_text, err := run_reasoned_generation(ve, req, prompt)
    if err != nil {
        return nil, err
    }

    response := *v1_response{
        id:      req.request_id,
        object:  "chat.completion",
        created: core.CurrentTimeMs(),
        model:   req.model,
        content: []map[string]interface{}{
            {
                "type": "text",
                "text": generated_text,
                "reasoning": reasoning_text,
            },
        },
        stop_reason: "stop",
        usage: map[string]int32{
            "prompt_tokens":     estimate_tokens(prompt),
            "completion_tokens": estimate_tokens(generated_text),
            "total_tokens":      estimate_tokens(prompt) + estimate_tokens(generated_text),
        },
    }

    ve.request_pool.remove(req.request_id)

    return response, nil
}

func (v1_engine* ve) execute_stream(v1_request* req) (chan *v1_stream_response, error) {
    if !ve.is_initialized {
        resp_chan := make(v1_stream_response* chan)
        close(resp_chan)
        return resp_chan, core.Errorf("engine not initialized")
    }

    resp_chan := make(chan *v1_stream_response, 100)

    go func() {
        defer close(resp_chan)
        defer ve.request_pool.remove(req.request_id)

        prompt := build_chat_prompt(req)
        generated_text, _, err := run_reasoned_generation(ve, req, prompt)
        if err != nil {
            return
        }

        resp_chan <- *v1_stream_response{
            id:      req.request_id,
            object:  "chat.completion.chunk",
            created: core.CurrentTimeMs(),
            model:   req.model,
            choices: []map[string]interface{}{
                {
                    "index": 0,
                    "delta": map[string]interface{}{
                        "role":    "assistant",
                        "content": "",
                    },
                },
            },
        }

        for i := 0; i < len(generated_text); i++ {
            token := string(generated_text[i])

            resp_chan <- *v1_stream_response{
                id:      req.request_id,
                object:  "chat.completion.chunk",
                created: core.CurrentTimeMs(),
                model:   req.model,
                choices: []map[string]interface{}{
                    {
                        "index": 0,
                        "delta": map[string]interface{}{
                            "content": token,
                        },
                    },
                },
            }
        }

        resp_chan <- *v1_stream_response{
            id:      req.request_id,
            object:  "chat.completion.chunk",
            created: core.CurrentTimeMs(),
            model:   req.model,
            choices: []map[string]interface{}{
                {
                    "index":        0,
                    "delta":        map[string]interface{}{},
                    "finish_reason": "stop",
                },
            },
            usage: map[string]int32{
                "prompt_tokens":     estimate_tokens(prompt),
                "completion_tokens": estimate_tokens(generated_text),
                "total_tokens":      estimate_tokens(prompt) + estimate_tokens(generated_text),
            },
        }
    }()

    return resp_chan, nil
}

func (v1_engine* ve) execute_async(req *v1_request, callback func(*v1_response, error)) error {
    if !ve.is_initialized {
        return core.Errorf("engine not initialized")
    }

    prompt := build_chat_prompt(req)
    generated_text, reasoning_text, err := run_reasoned_generation(ve, req, prompt)
    if err != nil {
        callback(nil, err)
        ve.request_pool.remove(req.request_id)
        return err
    }

    resp := *v1_response{
        id:      req.request_id,
        object:  "chat.completion",
        created: core.CurrentTimeMs(),
        model:   req.model,
        content: []map[string]interface{}{
            {
                "type": "text",
                "text": generated_text,
                "reasoning": reasoning_text,
            },
        },
        stop_reason: "stop",
        usage: map[string]int32{
            "prompt_tokens":     estimate_tokens(prompt),
            "completion_tokens": estimate_tokens(generated_text),
            "total_tokens":      estimate_tokens(prompt) + estimate_tokens(generated_text),
        },
    }

    callback(resp, nil)
    ve.request_pool.remove(req.request_id)
    return nil
}

func (v1_engine* ve) get_stats() map[string]interface{} {
    stats := make(map[string]interface{})

    if ve.engine != nil {
        engine_stats := ve.engine.get_stats()
        for key, value := range engine_stats {
            stats[key] = value
        }
    }

    stats["request_pool_size"] = ve.request_pool.size()

    return stats
}
