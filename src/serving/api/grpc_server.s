package api.grpc
import "core"
import "api"
struct grpc_server_config {
    int32 port
    string host
    int32 max_concurrent_streams
    int64 max_message_size
    bool enable_tls
    string tls_cert_path
    string tls_key_path
    int32 worker_threads
}
struct completion_request_pb {
    string model_id
    string prompt
    int32 max_tokens
    float32 temperature
}
struct token {
    int32 id
    string text
    float32 log_prob
}
struct completion_response_pb {
    string request_id
    []token* tokens
    int32 num_prompt_tokens
    int32 num_completion_tokens
}
struct chat_message_pb {
    string role
    string content
}
struct chat_completion_request_pb {
    string model_id
    []chat_message_pb* messages
    int32 max_tokens
    float32 temperature
    bool stream
}
struct chat_completion_choice_pb {
    int32 index
    chat_message_pb* message
    string finish_reason
}
struct chat_completion_response_pb {
    string request_id
    []chat_completion_choice_pb* choices
    int32 num_prompt_tokens
    int32 num_completion_tokens
}
struct embedding_request_pb {
    string model_id
    string[] texts
}
struct embedding_pb {
    int32 index
    float[]32 values
}
struct embedding_response_pb {
    string model
    []embedding_pb* data
}
struct grpc_server {
    grpc_server_config config
    llm_engine* engine
    bool running
    interface{} server_impl
}
struct grpc_stream_context {
    string stream_id
    interface{} send_channel
    interface{} recv_channel
    bool active
}
func create_grpc_server(grpc_server_config* config, llm_engine* engine) grpc_server* {
    return *grpc_server{
        config: *config,
        engine: engine,
        running: false,
        server_impl: nil,
    }
}
func (grpc_server* srv) start() error {
    srv.running = true
    return nil
}
func (grpc_server* srv) stop() error {
    srv.running = false
    return nil
}
func (grpc_server* srv) complete(completion_request_pb* req) (completion_response_pb*, error) {
    api_req := *completion_request{
        prompt: req.prompt,
        model_id: req.model_id,
        config: generation_config{
            max_new_tokens: req.max_tokens,
            temperature: req.temperature,
        },
    }
    resp, err := srv.engine.complete(api_req)
    if err != nil {
        return nil, err
    }
    tokens := make([]token*, 0)
    for _, text := range resp.generated_text {
        tokens = append(tokens, *token{
            id: 0,
            text: text,
            log_prob: 0.0,
        })
    }
    pb_resp := *completion_response_pb{
        request_id: resp.id,
        tokens: tokens,
        num_prompt_tokens: resp.input_tokens,
        num_completion_tokens: resp.output_tokens,
    }
    return pb_resp, nil
}
func (grpc_server* srv) complete_stream(completion_request_pb* req) streaming_response* {
    api_req := *completion_request{
        prompt: req.prompt,
        model_id: req.model_id,
        config: generation_config{
            max_new_tokens: req.max_tokens,
            temperature: req.temperature,
        },
    }
    return srv.engine.complete_stream(api_req)
}
func (grpc_server* srv) chat_completion(chat_completion_request_pb* req) (chat_completion_response_pb*, error) {
    api_req := *completion_request{
        prompt: "",
        model_id: req.model_id,
        config: generation_config{
            max_new_tokens: req.max_tokens,
            temperature: req.temperature,
        },
    }
    resp, err := srv.engine.complete(api_req)
    if err != nil {
        return nil, err
    }
    choice := *chat_completion_choice_pb{
        index: 0,
        message: *chat_message_pb{
            role: "assistant",
            content: "",
        },
        finish_reason: "stop",
    }
    pb_resp := *chat_completion_response_pb{
        request_id: resp.id,
        choices: []*chat_completion_choice_pb{choice},
        num_prompt_tokens: resp.input_tokens,
        num_completion_tokens: resp.output_tokens,
    }
    return pb_resp, nil
}
func (grpc_server* srv) chat_completion_stream(chat_completion_request_pb* req) streaming_response* {
    api_req := *completion_request{
        prompt: "",
        model_id: req.model_id,
        config: generation_config{
            max_new_tokens: req.max_tokens,
            temperature: req.temperature,
        },
    }
    return srv.engine.complete_stream(api_req)
}
func (grpc_server* srv) embed(embedding_request_pb* req) (embedding_response_pb*, error) {
    embeddings := make([]embedding_pb*, 0)
    for i, _ := range req.texts {
        emb := *embedding_pb{
            index: int32(i),
            values: make(float[]32, 0),
        }
        embeddings = append(embeddings, emb)
    }
    pb_resp := *embedding_response_pb{
        model: req.model_id,
        data: embeddings,
    }
    return pb_resp, nil
}
func (grpc_server* srv) is_running() bool {
    return srv.running
}
func (grpc_server* srv) get_port() int32 {
    return srv.config.port
}
func (grpc_server* srv) get_host() string {
    return srv.config.host
}
func (grpc_server* srv) health_check() bool {
    return srv.running && srv.engine.is_initialized()
}
func (grpc_server* srv) create_stream_context() grpc_stream_context* {
    return *grpc_stream_context{
        stream_id: core.generate_uuid(),
        send_channel: nil,
        recv_channel: nil,
        active: true,
    }
}
func (grpc_server* srv) close_stream_context(grpc_stream_context* ctx) {
    ctx.active = false
}
