package rpc
import "core"
import "engine"
struct grpc_request {
    request_id      string
    model           string
    prompt          string
    max_tokens      int32
    temperature     float32
    top_p           float32
    top_k           int32
    stop_sequences  []string
    stream          bool
    priority        int32
}

struct grpc_response {
    request_id      string
    text            string
    finish_reason   string
    usage           map[string]int32
    timestamp       int64
}

struct grpc_stream_response {
    request_id      string
    token           string
    token_id        int32
    cumulative      bool
    finish_reason   string
    timestamp       int64
}

struct grpc_server {
    engine          *engine.llm_engine
    async_engine    *engine.async_llm_engine
    server_addr     string
    is_running      bool
    connections     map[string]interface{}
}

func new_grpc_server(server_addr string) *grpc_server {
    return *grpc_server{
        server_addr: server_addr,
        connections: make(map[string]interface{}),
        is_running:  false,
    }
}

func (grpc_server* gs) set_engine(eng *engine.llm_engine) {
    gs.engine = eng
}

func (grpc_server* gs) set_async_engine(async_eng *engine.async_llm_engine) {
    gs.async_engine = async_eng
}

func (grpc_server* gs) start() error {
    if gs.is_running {
        return core.Errorf("grpc server already running")
    }
    if gs.engine == nil && gs.async_engine == nil {
        return core.Errorf("engine not set")
    }
    gs.is_running = true
    core.Printf("grpc_server started on %s\n", gs.server_addr)
    return nil
}

func (grpc_server* gs) stop() error {
    if !gs.is_running {
        return core.Errorf("grpc server not running")
    }
    gs.is_running = false
    gs.connections = make(map[string]interface{})
    core.Println("grpc_server stopped")
    return nil
}

func (grpc_server* gs) complete(grpc_request* req) (*grpc_response, error) {
    if !gs.is_running {
        return nil, core.Errorf("server not running")
    }
    if gs.engine == nil {
        return nil, core.Errorf("engine not initialized")
    }
    sampling_params := engine.sampling_params{
        temperature:    req.temperature,
        top_p:          req.top_p,
        top_k:          req.top_k,
        max_tokens:     req.max_tokens,
        stop:           req.stop_sequences,
    }
    generated_text, err := gs.engine.generate_completion(req.prompt, sampling_params)
    if err != nil {
        return nil, err
    }
    response := *grpc_response{
        request_id:   req.request_id,
        text:         generated_text,
        finish_reason: "length",
        timestamp:    core.current_time_ms(),
        usage: map[string]int32{
            "prompt_tokens":     0,
            "completion_tokens": 0,
            "total_tokens":      0,
        },
    }
    return response, nil
}

func (grpc_server* gs) complete_stream(grpc_request* req) (chan *grpc_stream_response, error) {
    if !gs.is_running {
        resp_chan := make(grpc_stream_response* chan)
        close(resp_chan)
        return resp_chan, core.Errorf("server not running")
    }
    resp_chan := make(chan *grpc_stream_response, 100)
    go func() {
        defer close(resp_chan)
        sampling_params := engine.sampling_params{
            temperature: req.temperature,
            top_p:       req.top_p,
            top_k:       req.top_k,
            max_tokens:  req.max_tokens,
            stop:        req.stop_sequences,
        }
        output, _ := gs.engine.get_output(req.request_id)
        if output != nil && len(output.text) > 0 {
            text := output.text[0]
            for i := 0; i < len(text); i++ {
                token := string(text[i])
                resp_chan <- *grpc_stream_response{
                    request_id: req.request_id,
                    token:      token,
                    cumulative: false,
                    timestamp:  core.current_time_ms(),
                }
            }
            resp_chan <- *grpc_stream_response{
                request_id:   req.request_id,
                token:        "",
                finish_reason: "length",
                cumulative:   true,
                timestamp:    core.current_time_ms(),
            }
        }
    }()
    return resp_chan, nil
}

func (grpc_server* gs) complete_async(req *grpc_request, callback func(*grpc_response, error)) error {
    if !gs.is_running {
        return core.Errorf("server not running")
    }
    if gs.async_engine == nil {
        return core.Errorf("async engine not initialized")
    }
    sampling_params := engine.sampling_params{
        temperature: req.temperature,
        top_p:       req.top_p,
        top_k:       req.top_k,
        max_tokens:  req.max_tokens,
        stop:        req.stop_sequences,
    }
    async_callback := func(output *engine.request_output, err error) {
        if err != nil {
            callback(nil, err)
            return
        }
        resp := *grpc_response{
            request_id:   req.request_id,
            finish_reason: "length",
            timestamp:    core.current_time_ms(),
            usage: map[string]int32{
                "prompt_tokens":     0,
                "completion_tokens": 0,
                "total_tokens":      0,
            },
        }
        if output != nil && len(output.text) > 0 {
            resp.text = output.text[0]
        }
        callback(resp, nil)
    }
    _, err := gs.async_engine.generate_completion_async(req.prompt, sampling_params, async_callback)
    return err
}

func (grpc_server* gs) get_status() map[string]interface{} {
    stats := make(map[string]interface{})
    stats["is_running"] = gs.is_running
    stats["server_addr"] = gs.server_addr
    stats["num_connections"] = int32(len(gs.connections))
    if gs.engine != nil {
        stats["engine_stats"] = gs.engine.get_stats()
    }
    if gs.async_engine != nil {
        stats["async_engine_stats"] = gs.async_engine.get_stats()
    }
    return stats
}

func (grpc_server* gs) cancel_request(request_id string) error {
    if gs.async_engine == nil {
        return core.Errorf("async engine not initialized")
    }
    return gs.async_engine.cancel_request(request_id)
}

struct grpc_health_check_response {
    status string
}

func (grpc_server* gs) health_check() *grpc_health_check_response {
    status := "SERVING"
    if !gs.is_running {
        status = "NOT_SERVING"
    }
    return *grpc_health_check_response{
        status: status,
    }
}

func (grpc_server* gs) get_server_info() map[string]interface{} {
    info := make(map[string]interface{})
    info["server_addr"] = gs.server_addr
    info["is_running"] = gs.is_running
    info["protocol_version"] = "1.0"
    info["grpc_version"] = "1.56.0"
    return info
}
