package api.gateway

import "core"
import "api"
import "api.openai"
import "api.anthropic"
import "api.cohere"
import "api.grpc"
import "api.mcp"
import "api.speech"
import "api.generate"
import "api.web"

type api_protocol string

const (
    protocol_openai      api_protocol = "openai"
    protocol_anthropic   api_protocol = "anthropic"
    protocol_cohere      api_protocol = "cohere"
    protocol_grpc        api_protocol = "grpc"
    protocol_mcp         api_protocol = "mcp"
    protocol_speech      api_protocol = "speech"
    protocol_rest        api_protocol = "rest"
)

struct api_gateway_config {
    string gateway_name
    int32 base_port
    bool enable_openai
    bool enable_anthropic
    bool enable_cohere
    bool enable_grpc
    bool enable_mcp
    bool enable_speech
    bool enable_rest
    bool enable_load_balancing
    int32 max_requests_per_second
    bool enable_request_logging
    bool enable_response_caching
}

struct api_server_info {
    api_protocol protocol
    int32 port
    bool running
    int64 num_requests
    int64 total_processing_time_ms
}

struct api_gateway {
    api_gateway_config config
    llm_engine* engine

    openai_api_server* openai_srv
    anthropic_api_server* anthropic_srv
    cohere_api_server* cohere_srv
    grpc_server* grpc_srv
    mcp_server* mcp_srv
    speech_to_text_server* speech_srv
    generate_engine* gen_engine
    web_server* web_srv

    map[api_protocol]api_server_info* server_info
    bool running
}

struct api_request_wrapper {
    api_protocol protocol
    string request_id
    int64 timestamp_ms
    interface{} request_data
}

struct api_response_wrapper {
    string request_id
    api_protocol protocol
    int64 processing_time_ms
    interface{} response_data
    string error_message
}

struct gateway_stats {
    int64 total_requests
    int64 total_responses
    int64 total_errors
    float32 avg_response_time_ms
    map[string]int64 requests_per_protocol
    map[string]int64 errors_per_protocol
}

func create_api_gateway(api_gateway_config* config, llm_engine* engine) api_gateway* {
    return &api_gateway{
        config: *config,
        engine: engine,
        openai_srv: nil,
        anthropic_srv: nil,
        cohere_srv: nil,
        grpc_srv: nil,
        mcp_srv: nil,
        speech_srv: nil,
        gen_engine: nil,
        web_srv: nil,
        server_info: make(map[api_protocol]api_server_info*),
        running: false,
    }
}

func (api_gateway* gw) initialize() error {
    if gw.config.enable_openai {
        gw.openai_srv = create_openai_api_server(gw.engine, gw.config.base_port + 1000)
        gw.server_info[protocol_openai] = &api_server_info{
            protocol: protocol_openai,
            port: gw.config.base_port + 1000,
            running: false,
            num_requests: 0,
            total_processing_time_ms: 0,
        }
    }

    if gw.config.enable_anthropic {
        gw.anthropic_srv = create_anthropic_api_server(gw.engine, gw.config.base_port + 1001)
        gw.server_info[protocol_anthropic] = &api_server_info{
            protocol: protocol_anthropic,
            port: gw.config.base_port + 1001,
            running: false,
            num_requests: 0,
            total_processing_time_ms: 0,
        }
    }

    if gw.config.enable_cohere {
        gw.cohere_srv = create_cohere_api_server(gw.engine, gw.config.base_port + 1002)
        gw.server_info[protocol_cohere] = &api_server_info{
            protocol: protocol_cohere,
            port: gw.config.base_port + 1002,
            running: false,
            num_requests: 0,
            total_processing_time_ms: 0,
        }
    }

    if gw.config.enable_grpc {
        grpc_cfg := &grpc_server_config{
            port: gw.config.base_port + 1003,
            host: "0.0.0.0",
            max_concurrent_streams: 1000,
            max_message_size: int64(10) * int64(1024) * int64(1024),
            worker_threads: 16,
        }
        gw.grpc_srv = create_grpc_server(grpc_cfg, gw.engine)
        gw.server_info[protocol_grpc] = &api_server_info{
            protocol: protocol_grpc,
            port: gw.config.base_port + 1003,
            running: false,
            num_requests: 0,
            total_processing_time_ms: 0,
        }
    }

    if gw.config.enable_mcp {
        gw.mcp_srv = create_mcp_server(gw.engine, gw.config.base_port + 1004)
        gw.server_info[protocol_mcp] = &api_server_info{
            protocol: protocol_mcp,
            port: gw.config.base_port + 1004,
            running: false,
            num_requests: 0,
            total_processing_time_ms: 0,
        }
    }

    if gw.config.enable_speech {
        gw.speech_srv = create_speech_to_text_server(gw.engine, gw.config.base_port + 1005)
        gw.server_info[protocol_speech] = &api_server_info{
            protocol: protocol_speech,
            port: gw.config.base_port + 1005,
            running: false,
            num_requests: 0,
            total_processing_time_ms: 0,
        }
    }

    gw.gen_engine = create_generate_engine(gw.engine)
    gw.gen_engine.initialize()

    if gw.config.enable_rest {
        web_cfg := &web_server_config{
            host: "0.0.0.0",
            port: gw.config.base_port,
            enable_cors: true,
            enable_compression: true,
            enable_auth: false,
            request_timeout_ms: 30000,
            max_body_size: int32(10) * int32(1024) * int32(1024),
        }
        gw.web_srv = create_web_server(web_cfg, gw.engine)
        gw.web_srv.setup_default_routes()
        gw.server_info[protocol_rest] = &api_server_info{
            protocol: protocol_rest,
            port: gw.config.base_port,
            running: false,
            num_requests: 0,
            total_processing_time_ms: 0,
        }
    }

    return nil
}

func (api_gateway* gw) start() error {
    gw.running = true

    if gw.openai_srv != nil {
        err := gw.openai_srv.start()
        if err != nil {
            return err
        }
        gw.server_info[protocol_openai].running = true
    }

    if gw.anthropic_srv != nil {
        err := gw.anthropic_srv.start()
        if err != nil {
            return err
        }
        gw.server_info[protocol_anthropic].running = true
    }

    if gw.cohere_srv != nil {
        err := gw.cohere_srv.start()
        if err != nil {
            return err
        }
        gw.server_info[protocol_cohere].running = true
    }

    if gw.grpc_srv != nil {
        err := gw.grpc_srv.start()
        if err != nil {
            return err
        }
        gw.server_info[protocol_grpc].running = true
    }

    if gw.mcp_srv != nil {
        err := gw.mcp_srv.start()
        if err != nil {
            return err
        }
        gw.server_info[protocol_mcp].running = true
    }

    if gw.speech_srv != nil {
        err := gw.speech_srv.start()
        if err != nil {
            return err
        }
        gw.server_info[protocol_speech].running = true
    }

    if gw.web_srv != nil {
        err := gw.web_srv.start()
        if err != nil {
            return err
        }
        gw.server_info[protocol_rest].running = true
    }

    return nil
}

func (api_gateway* gw) stop() error {
    gw.running = false

    if gw.openai_srv != nil {
        gw.openai_srv.stop()
    }
    if gw.anthropic_srv != nil {
        gw.anthropic_srv.stop()
    }
    if gw.cohere_srv != nil {
        gw.cohere_srv.stop()
    }
    if gw.grpc_srv != nil {
        gw.grpc_srv.stop()
    }
    if gw.mcp_srv != nil {
        gw.mcp_srv.stop()
    }
    if gw.speech_srv != nil {
        gw.speech_srv.stop()
    }
    if gw.web_srv != nil {
        gw.web_srv.stop()
    }

    return nil
}

func (api_gateway* gw) route_request(api_request_wrapper* req) (api_response_wrapper*, error) {
    start_time := core.current_time_ms()

    resp := &api_response_wrapper{
        request_id: req.request_id,
        protocol: req.protocol,
        processing_time_ms: 0,
        response_data: nil,
        error_message: "",
    }

    switch req.protocol {
    case protocol_openai:
        _ = gw.openai_srv
    case protocol_anthropic:
        _ = gw.anthropic_srv
    case protocol_cohere:
        _ = gw.cohere_srv
    case protocol_grpc:
        _ = gw.grpc_srv
    case protocol_mcp:
        _ = gw.mcp_srv
    case protocol_speech:
        _ = gw.speech_srv
    default:
        resp.error_message = "Unknown protocol"
    }

    end_time := core.current_time_ms()
    resp.processing_time_ms = end_time - start_time

    return resp, nil
}

func (api_gateway* gw) get_server_info(api_protocol protocol) (api_server_info*, bool) {
    info, exists := gw.server_info[protocol]
    return info, exists
}

func (api_gateway* gw) get_all_server_info() map[api_protocol]api_server_info* {
    return gw.server_info
}

func (api_gateway* gw) get_gateway_stats() gateway_stats* {
    stats := &gateway_stats{
        total_requests: 0,
        total_responses: 0,
        total_errors: 0,
        avg_response_time_ms: 0.0,
        requests_per_protocol: make(map[string]int64),
        errors_per_protocol: make(map[string]int64),
    }

    for protocol, info := range gw.server_info {
        stats.total_requests = stats.total_requests + info.num_requests
        stats.requests_per_protocol[string(protocol)] = info.num_requests
    }

    return stats
}

func (api_gateway* gw) is_running() bool {
    return gw.running
}

func (api_gateway* gw) health_check() bool {
    if !gw.running {
        return false
    }

    for _, info := range gw.server_info {
        if !info.running {
            return false
        }
    }

    return true
}

func (api_gateway* gw) list_available_apis() []api_protocol {
    apis := make([]api_protocol, 0)
    for protocol, _ := range gw.server_info {
        apis = append(apis, protocol)
    }
    return apis
}
