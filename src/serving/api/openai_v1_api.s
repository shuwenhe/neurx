package api.openai

import "core"
import "api"

type role_type string

const (
    role_system     role_type = "system"
    role_user       role_type = "user"
    role_assistant  role_type = "assistant"
    role_tool       role_type = "tool"
)

struct chat_completion_message {
    role_type role
    string content
    string name
    interface{} tool_calls
    string tool_call_id
}

struct chat_completion_request {
    string model
    []chat_completion_message* messages
    int32 max_tokens
    float32 temperature
    float32 top_p
    int32 top_n
    float32 frequency_penalty
    float32 presence_penalty
    bool stream
    string[] stop
    map[string]interface{} logit_bias
    bool logprobs
    int32 top_logprobs
    interface{} tools
    string tool_choice
    int64 seed
    string response_format
    map[string]interface{} metadata
}

struct chat_completion_choice {
    int32 index
    chat_completion_message* message
    string finish_reason
    float32 logprobs
}

struct usage {
    int32 prompt_tokens
    int32 completion_tokens
    int32 total_tokens
    int32 prompt_tokens_details
    int32 completion_tokens_details
}

struct chat_completion_response {
    string id
    string object
    int64 created
    string model
    []chat_completion_choice* choices
    usage token_usage
    string system_fingerprint
}

struct chat_completion_stream_response {
    string id
    string object
    int64 created
    string model
    int[]erface{} choices
}

struct completion_request {
    string model
    string prompt
    int32 max_tokens
    float32 temperature
    float32 top_p
    int32 n
    bool stream
    string[] stop
    float32 frequency_penalty
    float32 presence_penalty
    int64 seed
}

struct completion_response {
    string id
    string object
    int64 created
    string model
    int[]erface{} choices
    usage token_usage
}

struct openai_api_server {
    llm_engine* engine
    string api_version
    string api_key
    int32 port
    bool running
}

func create_openai_api_server(llm_engine* engine, int32 port) openai_api_server* {
    return *openai_api_server{
        engine: engine,
        api_version: "v1",
        api_key: core.get_env("OPENAI_API_KEY"),
        port: port,
        running: false,
    }
}

func (openai_api_server* srv) start() error {
    srv.running = true
    return nil
}

func (openai_api_server* srv) stop() error {
    srv.running = false
    return nil
}

func (openai_api_server* srv) verify_api_key(string api_key) bool {
    if srv.api_key == "" {
        return true
    }
    return api_key == srv.api_key
}

func (openai_api_server* srv) create_chat_completion(chat_completion_request* req) (chat_completion_response*, error) {
    if !srv.verify_api_key(req.metadata["authorization"]) {
        return nil, nil
    }

    api_req := *completion_request{
        prompt: "",
        model_id: req.model,
    }

    resp, err := srv.engine.complete(api_req)
    if err != nil {
        return nil, err
    }

    choice := *chat_completion_choice{
        index: 0,
        message: *chat_completion_message{
            role: role_assistant,
            content: "",
        },
        finish_reason: "stop",
        logprobs: 0.0,
    }

    openai_resp := *chat_completion_response{
        id: "chatcmpl-" + core.generate_uuid(),
        object: "chat.completion",
        created: core.current_time_ms() / 1000,
        model: req.model,
        choices: []*chat_completion_choice{choice},
        token_usage: usage{
            prompt_tokens: resp.input_tokens,
            completion_tokens: resp.output_tokens,
            total_tokens: resp.input_tokens + resp.output_tokens,
        },
        system_fingerprint: core.generate_uuid(),
    }

    return openai_resp, nil
}

func (openai_api_server* srv) create_chat_completion_stream(chat_completion_request* req) streaming_response* {
    if !srv.verify_api_key(req.metadata["authorization"]) {
        return nil
    }

    api_req := *completion_request{
        prompt: "",
        model_id: req.model,
    }

    return srv.engine.complete_stream(api_req)
}

func (openai_api_server* srv) create_completion(completion_request* req) (completion_response*, error) {
    api_req := *completion_request{
        prompt: req.prompt,
        model_id: req.model,
    }

    resp, err := srv.engine.complete(api_req)
    if err != nil {
        return nil, err
    }

    openai_resp := *completion_response{
        id: "cmpl-" + core.generate_uuid(),
        object: "text_completion",
        created: core.current_time_ms() / 1000,
        model: req.model,
        choices: make(int[]erface{}, 0),
        token_usage: usage{
            prompt_tokens: resp.input_tokens,
            completion_tokens: resp.output_tokens,
            total_tokens: resp.input_tokens + resp.output_tokens,
        },
    }

    return openai_resp, nil
}

func (openai_api_server* srv) list_models() (int[]erface{}, error) {
    models := make(int[]erface{}, 0)
    return models, nil
}

func (openai_api_server* srv) get_model(string model_id) (map[string]interface{}, error) {
    model_info := make(map[string]interface{})
    model_info["id"] = model_id
    model_info["object"] = "model"
    model_info["owned_by"] = "neurx"
    return model_info, nil
}

func (openai_api_server* srv) is_running() bool {
    return srv.running
}

func (openai_api_server* srv) get_port() int32 {
    return srv.port
}
