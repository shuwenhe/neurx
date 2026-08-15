package api

import "core"
import "engine"

struct anthropic_message {
    role    string
    content string
}

struct anthropic_request {
    model             string
    messages          []anthropic_message
    max_tokens         int32
    temperature       float32
    top_p              float32
    top_k              int32
    stop_sequences     []string
    system_prompt      string
    stream            bool
}

struct anthropic_response {
    id        string
    type      string
    role      string
    content   []map[string]interface{}
    model     string
    stop_reason string
    usage     map[string]int32
}

struct cohere_request {
    model             string
    prompt            string
    max_tokens         int32
    temperature       float32
    k                 int32
    p                 float32
    frequency_penalty  float32
    presence_penalty   float32
    stop_sequences     []string
    return_likelihoods string
    stream            bool
}

struct cohere_response {
    generations       []map[string]interface{}
    id                string
}

struct anthropic_api {
    engine            *engine.llm_engine
    api_key            string
    api_version        string
}

struct cohere_api {
    engine            *engine.llm_engine
    api_key            string
    api_version        string
}

func new_anthropic_api(eng *engine.llm_engine) *anthropic_api {
    return &anthropic_api{
        engine:     eng,
        api_version: "2023-06-01",
    }
}

func (aa *anthropic_api) set_api_key(api_key string) {
    aa.api_key = api_key
}

func (aa *anthropic_api) create_message(req anthropic_request) (*anthropic_response, error) {
    if req.model == "" {
        return nil, core.Errorf("model not specified")
    }

    prompt := ""
    for _, msg := range req.messages {
        if msg.role == "user" {
            prompt = prompt + "User: " + msg.content + "\n"
        } else if msg.role == "assistant" {
            prompt = prompt + "Assistant: " + msg.content + "\n"
        }
    }

    if req.system_prompt != "" {
        prompt = "System: " + req.system_prompt + "\n" + prompt
    }

    prompt = prompt + "Assistant:"

    sampling_params := engine.sampling_params{
        temperature:    req.temperature,
        top_p:          req.top_p,
        top_k:          req.top_k,
        max_tokens:     req.max_tokens,
        stop:          req.stop_sequences,
    }

    output, err := aa.engine.get_output(core.GenerateId())
    if err != nil {
        return nil, err
    }

    response := &anthropic_response{
        id:         core.GenerateId(),
        type:       "message",
        role:       "assistant",
        model:      req.model,
        stop_reason: "end_turn",
        usage: map[string]int32{
            "input_tokens":  0,
            "output_tokens": 0,
        },
    }

    if output != nil && len(output.text) > 0 {
        response.content = []map[string]interface{}{
            {
                "type": "text",
                "text": output.text[0],
            },
        }
    }

    return response, nil
}

func (aa *anthropic_api) create_message_stream(req anthropic_request) (chan *anthropic_response, error) {
    resp_chan := make(chan *anthropic_response, 100)

    go func() {
        defer close(resp_chan)

        prompt := ""
        for _, msg := range req.messages {
            if msg.role == "user" {
                prompt = prompt + "User: " + msg.content + "\n"
            } else if msg.role == "assistant" {
                prompt = prompt + "Assistant: " + msg.content + "\n"
            }
        }

        if req.system_prompt != "" {
            prompt = "System: " + req.system_prompt + "\n" + prompt
        }

        prompt = prompt + "Assistant:"

        resp_chan <- &anthropic_response{
            id:    core.GenerateId(),
            type:  "content_block_start",
            role:  "assistant",
            model: req.model,
        }
    }()

    return resp_chan, nil
}

func new_cohere_api(eng *engine.llm_engine) *cohere_api {
    return &cohere_api{
        engine:     eng,
        api_version: "2024-08-01",
    }
}

func (ca *cohere_api) set_api_key(api_key string) {
    ca.api_key = api_key
}

func (ca *cohere_api) generate(req cohere_request) (*cohere_response, error) {
    if req.model == "" {
        return nil, core.Errorf("model not specified")
    }

    sampling_params := engine.sampling_params{
        temperature:       req.temperature,
        top_p:             req.p,
        top_k:             req.k,
        max_tokens:        req.max_tokens,
        stop:             req.stop_sequences,
        frequency_penalty: req.frequency_penalty,
        presence_penalty:  req.presence_penalty,
    }

    output, err := ca.engine.get_output(core.GenerateId())
    if err != nil {
        return nil, err
    }

    generations := make([]map[string]interface{}, 0)
    if output != nil && len(output.text) > 0 {
        generation := make(map[string]interface{})
        generation["text"] = output.text[0]
        generation["finish_reason"] = output.finish_reason
        if req.return_likelihoods != "" {
            generation["token_likelihoods"] = nil
        }
        generations = append(generations, generation)
    }

    response := &cohere_response{
        id:          core.GenerateId(),
        generations: generations,
    }

    return response, nil
}

func (ca *cohere_api) generate_stream(req cohere_request) (chan *cohere_response, error) {
    resp_chan := make(chan *cohere_response, 100)

    go func() {
        defer close(resp_chan)

        resp_chan <- &cohere_response{
            id:          core.GenerateId(),
            generations: make([]map[string]interface{}, 0),
        }
    }()

    return resp_chan, nil
}

func convert_openai_to_anthropic(messages []interface{}, model string) anthropic_request {
    anthropic_messages := make([]anthropic_message, 0)

    for _, msg := range messages {
        msg_map := msg.(map[string]interface{})
        anthropic_messages = append(anthropic_messages, anthropic_message{
            role:    msg_map["role"].(string),
            content: msg_map["content"].(string),
        })
    }

    return anthropic_request{
        model:    model,
        messages: anthropic_messages,
    }
}

func convert_openai_to_cohere(prompt string, model string) cohere_request {
    return cohere_request{
        model:  model,
        prompt: prompt,
    }
}

func convert_anthropic_to_openai(resp *anthropic_response) map[string]interface{} {
    result := make(map[string]interface{})
    result["id"] = resp.id
    result["object"] = "chat.completion"
    result["created"] = core.CurrentTimeMs()
    result["model"] = resp.model

    choices := make([]map[string]interface{}, 0)
    if len(resp.content) > 0 {
        choice := make(map[string]interface{})
        choice["index"] = 0
        choice["message"] = map[string]interface{}{
            "role":    resp.role,
            "content": resp.content[0]["text"],
        }
        choice["finish_reason"] = resp.stop_reason
        choices = append(choices, choice)
    }

    result["choices"] = choices
    result["usage"] = resp.usage

    return result
}

func convert_cohere_to_openai(resp *cohere_response, model string) map[string]interface{} {
    result := make(map[string]interface{})
    result["id"] = resp.id
    result["object"] = "chat.completion"
    result["created"] = core.CurrentTimeMs()
    result["model"] = model

    choices := make([]map[string]interface{}, 0)
    if len(resp.generations) > 0 {
        choice := make(map[string]interface{})
        choice["index"] = 0
        gen := resp.generations[0]
        choice["message"] = map[string]interface{}{
            "role":    "assistant",
            "content": gen["text"],
        }
        choice["finish_reason"] = gen["finish_reason"]
        choices = append(choices, choice)
    }

    result["choices"] = choices
    result["usage"] = map[string]int32{
        "prompt_tokens":     0,
        "completion_tokens": 0,
        "total_tokens":      0,
    }

    return result
}
