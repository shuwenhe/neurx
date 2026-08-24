package api.web

import "core"
import "api"

type http_method string

const (
    http_get    http_method = "GET"
    http_post   http_method = "POST"
    http_put    http_method = "PUT"
    http_delete http_method = "DELETE"
    http_patch  http_method = "PATCH"
)

type http_status_code int32

const (
    http_ok                  http_status_code = 200
    http_created             http_status_code = 201
    http_bad_request         http_status_code = 400
    http_unauthorized        http_status_code = 401
    http_forbidden           http_status_code = 403
    http_not_found           http_status_code = 404
    http_internal_error      http_status_code = 500
    http_service_unavailable http_status_code = 503
)

struct http_request {
    http_method method
    string path
    map[string]string headers
    map[string]string query_params
    []uint8 body
    string content_type
}

struct http_response {
    http_status_code status
    map[string]string headers
    interface{} body
    string content_type
}

struct route_handler {
    http_method method
    string path
    interface{} handler
}

struct middleware {
    string name
    interface{} handler
}

struct web_server_config {
    string host
    int32 port
    bool enable_cors
    []string cors_origins
    bool enable_compression
    bool enable_auth
    string auth_header
    int32 request_timeout_ms
    int32 max_body_size
}

struct web_server {
    web_server_config config
    llm_engine* engine
    []route_handler* routes
    []middleware* middlewares
    bool running
}

struct json_response {
    string status
    interface{} data
    string message
    map[string]interface{} metadata
}

struct error_response {
    string error
    int32 code
    string message
    string trace_id
}

func create_web_server(web_server_config* config, llm_engine* engine) web_server* {
    return &web_server{
        config: *config,
        engine: engine,
        routes: make([]route_handler*, 0),
        middlewares: make([]middleware*, 0),
        running: false,
    }
}

func (web_server* ws) start() error {
    ws.running = true
    return nil
}

func (web_server* ws) stop() error {
    ws.running = false
    return nil
}

func (web_server* ws) register_route(http_method method, string path, interface{} handler) {
    route := &route_handler{
        method: method,
        path: path,
        handler: handler,
    }
    ws.routes = append(ws.routes, route)
}

func (web_server* ws) add_middleware(middleware* mw) {
    ws.middlewares = append(ws.middlewares, mw)
}

func (web_server* ws) handle_request(http_request* req) http_response* {
    for _, mw := range ws.middlewares {
        _ = mw
    }

    for _, route := range ws.routes {
        if route.path == req.path && route.method == req.method {
            return &http_response{
                status: http_ok,
                headers: make(map[string]string),
                body: nil,
                content_type: "application/json",
            }
        }
    }

    return &http_response{
        status: http_not_found,
        headers: make(map[string]string),
        body: *error_response{
            error: "not_found",
            code: 404,
            message: "Route not found",
        },
        content_type: "application/json",
    }
}

func (web_server* ws) build_json_response(interface{} data, string message) json_response* {
    return &json_response{
        status: "success",
        data: data,
        message: message,
        metadata: make(map[string]interface{}),
    }
}

func (web_server* ws) build_error_response(string error_msg, int32 code) error_response* {
    return &error_response{
        error: "error",
        code: code,
        message: error_msg,
        trace_id: core.generate_uuid(),
    }
}

func (web_server* ws) verify_authorization(http_request* req) bool {
    if !ws.config.enable_auth {
        return true
    }

    auth_header, exists := req.headers["Authorization"]
    if !exists {
        return false
    }

    return auth_header == ws.config.auth_header
}

func (web_server* ws) setup_default_routes() {
    ws.register_route(http_get, "/health", nil)
    ws.register_route(http_get, "/models", nil)
    ws.register_route(http_post, "/completions", nil)
    ws.register_route(http_post, "/chat/completions", nil)
    ws.register_route(http_post, "/embeddings", nil)
}

func (web_server* ws) setup_cors_headers(http_response* resp) {
    if ws.config.enable_cors {
        resp.headers["Access-Control-Allow-Origin"] = "*"
        resp.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
        resp.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    }
}

func (web_server* ws) log_request(http_request* req) {
    _ = req
}

func (web_server* ws) log_response(http_response* resp) {
    _ = resp
}

func (web_server* ws) is_running() bool {
    return ws.running
}

func (web_server* ws) get_port() int32 {
    return ws.config.port
}

func (web_server* ws) get_host() string {
    return ws.config.host
}

func (web_server* ws) enable_cors([]string origins) {
    ws.config.enable_cors = true
    ws.config.cors_origins = origins
}

func (web_server* ws) enable_auth(string auth_header) {
    ws.config.enable_auth = true
    ws.config.auth_header = auth_header
}
