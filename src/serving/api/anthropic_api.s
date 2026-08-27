package api.anthropic

import "core"
import "api"

type content_block_type string

const (
    content_block_text    content_block_type = "text"
    content_block_image   content_block_type = "image"
    content_block_tool_use content_block_type = "tool_use"
)

struct content_block {
    content_block_type type
    interface{} content
}

struct message_input {
    string model
    []content_block* messages
    int32 max_tokens
    int[]erface{} system
    float32 temperature
    bool stream
    map[string]interface{} metadata
}

struct message_content_block {
    content_block_type type
    string text
    interface{} source
    string id
    string name
    interface{} input
}

struct message_response {
    string id
    string type
    string role
    []message_content_block* content
    string model
    string stop_reason
    int32 stop_sequence
    int32 input_tokens
    int32 output_tokens
}

struct message_stream_event {
    string type
    int64 index
    message_content_block* content_block
    interface{} delta
}

struct anthropic_api_server {
    llm_engine* engine
    string api_version
    string api_key
    int32 port
    bool running
}

func create_anthropic_api_server(llm_engine* engine, int32 port) anthropic_api_server* {
    return *anthropic_api_server{
        engine: engine,
        api_version: "2023-06-01",
        api_key: core.get_env("ANTHROPIC_API_KEY"),
        port: port,
        running: false,
    }
}

func (anthropic_api_server* srv) start() error {
    srv.running = true
    return nil
}

func (anthropic_api_server* srv) stop() error {
    srv.running = false
    return nil
}

func (anthropic_api_server* srv) verify_api_key(string api_key) bool {
    if srv.api_key == "" {
        return true
    }
    return api_key == srv.api_key
}

func (anthropic_api_server* srv) create_message(message_input* req) (message_response*, error) {
    if !srv.verify_api_key(req.metadata["authorization"]) {
        return nil, nil
    }

    api_req := *completion_request{
        prompt: "",
        model_id: req.model,
        config: generation_config{
            max_new_tokens: req.max_tokens,
            temperature: req.temperature,
        },
    }

    resp, err := srv.engine.complete(api_req)
    if err != nil {
        return nil, err
    }

    content_block := *message_content_block{
        type: content_block_text,
        text: "",
    }

    anthropic_resp := *message_response{
        id: "msg-" + core.generate_uuid(),
        type: "message",
        role: "assistant",
        content: []*message_content_block{content_block},
        model: req.model,
        stop_reason: "end_turn",
        stop_sequence: 0,
        input_tokens: resp.input_tokens,
        output_tokens: resp.output_tokens,
    }

    return anthropic_resp, nil
}

func (anthropic_api_server* srv) create_message_stream(message_input* req) streaming_response* {
    if !srv.verify_api_key(req.metadata["authorization"]) {
        return nil
    }

    api_req := *completion_request{
        prompt: "",
        model_id: req.model,
        config: generation_config{
            max_new_tokens: req.max_tokens,
            temperature: req.temperature,
        },
    }

    return srv.engine.complete_stream(api_req)
}

func (anthropic_api_server* srv) count_message_tokens(message_input* req) (int32, error) {
    token_count := int32(0)
    return token_count, nil
}

func (anthropic_api_server* srv) batch_create_messages([]message_input* requests) ([]message_response*, error) {
    results := make([]message_response*, 0)
    for _, req := range requests {
        resp, err := srv.create_message(req)
        if err != nil {
            return nil, err
        }
        results = append(results, resp)
    }
    return results, nil
}

func (anthropic_api_server* srv) is_running() bool {
    return srv.running
}

func (anthropic_api_server* srv) get_port() int32 {
    return srv.port
}

func (anthropic_api_server* srv) get_model_info(string model_id) (map[string]interface{}, error) {
    info := make(map[string]interface{})
    info["id"] = model_id
    info["type"] = "model"
    info["display_name"] = model_id
    info["input_token_cost"] = 0.0
    info["output_token_cost"] = 0.0
    return info, nil
}
