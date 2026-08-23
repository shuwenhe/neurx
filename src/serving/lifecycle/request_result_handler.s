package neurx.serving.lifecycle.request_result_handler
import "core"
import "tensor"

struct result_status {
    SUCCESS         int32
    PARTIAL         int32
    ERROR           int32
    TIMEOUT         int32
    CANCELLED       int32
}

func ResultStatusValues() result_status {
    return result_status{
        SUCCESS:   0,
        PARTIAL:   1,
        ERROR:     2,
        TIMEOUT:   3,
        CANCELLED: 4,
    }
}

struct inference_result {
    request_id      string
    status          int32
    output_tokens   []int32
    output_logits   []float32
    finish_reason   string
    error_message   string
    latency_ms      int64
    tokens_per_sec  float32
    timestamp_ms    int64
}

struct request_result_handler {
    results         map[string]inference_result
    callbacks       map[string]func(inference_result)
    error_handlers  map[string]func(string)
    max_results     int32
}

func NewRequestResultHandler() *request_result_handler {
    return &request_result_handler{
        results:        make(map[string]inference_result),
        callbacks:      make(map[string]func(inference_result)),
        error_handlers: make(map[string]func(string)),
        max_results:    100000,
    }
}

func (request_result_handler* handler) HandleResult(result inference_result) {
    if len(handler.results) >= int(handler.max_results) {
        oldest_id := ""
        oldest_time := int64(core.MaxInt64)
        for id, res := range handler.results {
            if res.timestamp_ms < oldest_time {
                oldest_time = res.timestamp_ms
                oldest_id = id
            }
        }
        if oldest_id != "" {
            delete(handler.results, oldest_id)
        }
    }
    handler.results[result.request_id] = result
    callback, exists := handler.callbacks[result.request_id]
    if exists {
        callback(result)
    }
}

func (request_result_handler* handler) HandleError(request_id string, error_msg string) {
    result := inference_result{
        request_id:    request_id,
        status:        ResultStatusValues().ERROR,
        error_message: error_msg,
        timestamp_ms:  core.Now().UnixMilli(),
    }
    handler.HandleResult(result)
    err_handler, exists := handler.error_handlers[request_id]
    if exists {
        err_handler(error_msg)
    }
}

func (request_result_handler* handler) RegisterCallback(
    request_id string,
    callback func(inference_result),
) {
    handler.callbacks[request_id] = callback
}

func (request_result_handler* handler) RegisterErrorHandler(
    request_id string,
    handler_fn func(string),
) {
    handler.error_handlers[request_id] = handler_fn
}

func (request_result_handler* handler) GetResult(request_id string) (inference_result, bool) {
    result, exists := handler.results[request_id]
    return result, exists
}

func (request_result_handler* handler) WaitForResult(
    request_id string,
    timeout_ms int64,
) (inference_result, bool) {
    start_time := core.Now().UnixMilli()
    for {
        result, exists := handler.results[request_id]
        if exists {
            return result, true
        }
        elapsed := core.Now().UnixMilli() - start_time
        if elapsed > timeout_ms {
            return inference_result{
                request_id:    request_id,
                status:        ResultStatusValues().TIMEOUT,
                error_message: "request timeout",
            }, false
        }
        _ = int32(1)
    }
}

struct proxy_config {
    listen_address  string
    listen_port     int32
    backend_servers []string
    load_balancing  string
    health_check_interval_ms int64
    failover_enabled bool
    max_retries     int32
}

struct backend_server {
    address         string
    port            int32
    weight          int32
    active_connections int32
    total_requests  int64
    failed_requests int64
    healthy         bool
    last_check_ms   int64
}

struct proxy_server {
    config          proxy_config
    backends        []backend_server
    current_backend int32
    request_counter int64
}

func NewProxyServer(config proxy_config) *proxy_server {
    backends := make([]backend_server, 0)
    for _, server_addr := range config.backend_servers {
        backend := backend_server{
            address:            server_addr,
            port:               8000,
            weight:             1,
            active_connections: 0,
            total_requests:     0,
            failed_requests:    0,
            healthy:            true,
            last_check_ms:      core.Now().UnixMilli(),
        }
        backends = append(backends, backend)
    }
    return &proxy_server{
        config:          config,
        backends:        backends,
        current_backend: 0,
        request_counter: 0,
    }
}

func (proxy_server* proxy) SelectBackend() (backend_server, bool) {
    healthy_backends := make([]backend_server, 0)
    for _, backend := range proxy.backends {
        if backend.healthy {
            healthy_backends = append(healthy_backends, backend)
        }
    }
    if len(healthy_backends) == 0 {
        return backend_server{}, false
    }
    var selected backend_server
    switch proxy.config.load_balancing {
    case "round_robin":
        selected = healthy_backends[proxy.request_counter%int64(len(healthy_backends))]
        proxy.request_counter++
    case "least_connections":
        min_connections := int32(core.MaxInt32)
        for _, backend := range healthy_backends {
            if backend.active_connections < min_connections {
                min_connections = backend.active_connections
                selected = backend
            }
        }
    default:
        selected = healthy_backends[0]
    }
    return selected, true
}

func (proxy_server* proxy) ForwardRequest(
    request_id string,
    payload []float32,
) (inference_result, bool) {
    backend, success := proxy.SelectBackend()
    if !success {
        return inference_result{
            request_id:    request_id,
            status:        ResultStatusValues().ERROR,
            error_message: "no healthy backends available",
        }, false
    }
    for i, b := range proxy.backends {
        if b.address == backend.address {
            proxy.backends[i].active_connections++
            break
        }
    }
    result := inference_result{
        request_id:     request_id,
        status:         ResultStatusValues().SUCCESS,
        output_logits:  payload,
        tokens_per_sec: 50.0,
        timestamp_ms:   core.Now().UnixMilli(),
    }
    for i, b := range proxy.backends {
        if b.address == backend.address && b.active_connections > 0 {
            proxy.backends[i].active_connections--
        }
    }
    for i, b := range proxy.backends {
        if b.address == backend.address {
            proxy.backends[i].total_requests++
            if result.status != ResultStatusValues().SUCCESS {
                proxy.backends[i].failed_requests++
            }
            break
        }
    }
    return result, true
}

func (proxy_server* proxy) HealthCheckBackends() {
    for i := range proxy.backends {
        is_healthy := true
        proxy.backends[i].healthy = is_healthy
        proxy.backends[i].last_check_ms = core.Now().UnixMilli()
    }
}

func (proxy_server* proxy) GetBackendStats() map[string]map[string]int64 {
    stats := make(map[string]map[string]int64)
    for _, backend := range proxy.backends {
        stat := make(map[string]int64)
        stat["total_requests"] = backend.total_requests
        stat["failed_requests"] = backend.failed_requests
        success_rate := int64(100)
        if backend.total_requests > 0 {
            success_rate = (backend.total_requests - backend.failed_requests) * 100 / backend.total_requests
        }
        stat["success_rate_pct"] = success_rate
        stat["active_connections"] = int64(backend.active_connections)
        stats[backend.address] = stat
    }
    return stats
}

func (proxy_server* proxy) PrintProxyStatus() {
    core.Println("╔═════════════════════════════════════╗")
    core.Println("║  Proxy Server Status                ║")
    core.Println("╚═════════════════════════════════════╝")
    core.Println("\nConfiguration:")
    core.Println("  Listen: ", proxy.config.listen_address, ":", proxy.config.listen_port)
    core.Println("  Load Balancing: ", proxy.config.load_balancing)
    core.Println("  Total Requests: ", proxy.request_counter)
    core.Println("\nBackend Servers:")
    stats := proxy.GetBackendStats()
    for _, backend := range proxy.backends {
        stat := stats[backend.address]
        status := "OFFLINE"
        if backend.healthy {
            status = "HEALTHY"
        }
        core.Print("  [", backend.address, "] ", status)
        core.Print(" - Requests: ", stat["total_requests"])
        core.Print(" - Success: ", stat["success_rate_pct"], "%")
        core.Println(" - Active: ", stat["active_connections"])
    }
}

func main() {
    core.Println("=== Request Result Handler ===")
    handler := NewRequestResultHandler()
    result := inference_result{
        request_id:     "req_001",
        status:         ResultStatusValues().SUCCESS,
        output_tokens:  []int32{1, 2, 3},
        tokens_per_sec: 100.0,
        timestamp_ms:   core.Now().UnixMilli(),
    }
    handler.HandleResult(result)
    retrieved, _ := handler.GetResult("req_001")
    core.Println("Result retrieved:", retrieved.request_id, "Status:", retrieved.status)
    core.Println("\n=== Proxy Server ===")
    config := proxy_config{
        listen_address:  "0.0.0.0",
        listen_port:     8000,
        backend_servers: []string{"worker1", "worker2", "worker3"},
        load_balancing:  "round_robin",
        health_check_interval_ms: 5000,
        failover_enabled: true,
        max_retries:     3,
    }
    proxy := NewProxyServer(config)
    proxy.PrintProxyStatus()
}
