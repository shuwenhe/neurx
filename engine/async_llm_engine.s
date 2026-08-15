package engine

import "core"
import "sync"
import "time"

type async_request_callback func(output *request_output, err error)

type async_request_stream_callback func(token string, finish_reason finish_reason)

type async_request_state int32

const (
    async_request_state_queued    async_request_state = iota
    async_request_state_running
    async_request_state_completed
    async_request_state_cancelled
    async_request_state_failed
)

struct async_request_info {
    request_id              string
    state                   async_request_state
    added_time              int64
    start_time              int64
    complete_time           int64
    retry_count             int32
    max_retries             int32
    callback                async_request_callback
    stream_callback         async_request_stream_callback
    error_message           string
    timeout_ms              int64
}

struct async_pool_config {
    max_concurrent_requests int32
    max_request_queue_size  int32
    worker_thread_count     int32
    enable_request_timeout  bool
    request_timeout_ms      int64
    enable_retry            bool
    max_retries             int32
    retry_delay_ms          int64
    enable_profiling        bool
}

struct async_llm_engine {
    config                  engine_config
    engine                  *llm_engine
    pool_config             async_pool_config

    request_callbacks       map[string]*async_request_info
    callback_lock           interface{}

    request_queue           chan *async_request
    output_channel          chan *async_output_event
    event_loop_channel      chan *async_event

    is_running              bool
    stop_signal             chan bool
    workers_stopped         chan bool

    concurrent_requests     int32
    max_concurrent          int32

    total_requests          int64
    completed_requests      int64
    failed_requests         int64
    cancelled_requests      int64

    start_time              int64
}

struct async_request {
    request_id              string
    prompt                  string
    sampling_params         sampling_params
    callback                async_request_callback
    stream_callback         async_request_stream_callback
    timeout_ms              int64
    priority                int32
    request_info            *async_request_info
}

struct async_output_event {
    request_id      string
    output          *request_output
    error           error
    is_final        bool
}

struct async_event {
    event_type      string  // "request_complete", "request_failed", "timeout", "retry"
    request_id      string
    data            interface{}
}

func new_async_pool_config() async_pool_config {
    return async_pool_config{
        max_concurrent_requests: 256,
        max_request_queue_size:  512,
        worker_thread_count:     4,
        enable_request_timeout:  true,
        request_timeout_ms:      60000,
        enable_retry:            true,
        max_retries:             3,
        retry_delay_ms:          1000,
        enable_profiling:        true,
    }
}

func new_async_llm_engine(config engine_config) *async_llm_engine {
    pool_config := new_async_pool_config()

    async_engine := &async_llm_engine{
        config:                  config,
        engine:                  new_llm_engine(config),
        pool_config:             pool_config,
        request_callbacks:       make(map[string]*async_request_info),
        request_queue:           make(chan *async_request, pool_config.max_request_queue_size),
        output_channel:          make(chan *async_output_event, 256),
        event_loop_channel:      make(chan *async_event, 256),
        is_running:              false,
        stop_signal:             make(chan bool, 1),
        workers_stopped:         make(chan bool, pool_config.worker_thread_count),
        concurrent_requests:     0,
        max_concurrent:          pool_config.max_concurrent_requests,
        start_time:              core.CurrentTimeMs(),
    }

    return async_engine
}

func (ae *async_llm_engine) initialize() error {
    if err := ae.engine.initialize(); err != nil {
        return err
    }

    if ae.pool_config.enable_request_timeout {
        core.Printf("async_llm_engine with timeout support enabled (%d ms)\n", ae.pool_config.request_timeout_ms)
    }

    if ae.pool_config.enable_retry {
        core.Printf("async_llm_engine with retry enabled (max retries: %d)\n", ae.pool_config.max_retries)
    }

    return nil
}

func (ae *async_llm_engine) start_workers() error {
    if ae.is_running {
        return core.Errorf("async engine workers already running")
    }

    ae.is_running = true

    for i := int32(0); i < ae.pool_config.worker_thread_count; i++ {
        go ae.worker_loop(i)
    }

    go ae.event_loop()
    go ae.timeout_checker()

    core.Printf("async_llm_engine started with %d workers\n", ae.pool_config.worker_thread_count)
    return nil
}

func (ae *async_llm_engine) worker_loop(worker_id int32) {
    defer func() {
        ae.workers_stopped <- true
    }()

    core.Printf("worker-%d started\n", worker_id)

    for ae.is_running {
        select {
        case <-ae.stop_signal:
            return
        case async_req := <-ae.request_queue:
            if async_req != nil {
                ae.process_async_request(async_req)
            }
        default:
            has_running, _ := ae.engine.step()
            if !has_running {
                core.Sleep(10)
            }

            ae.check_completed_requests()
        }
    }
}

func (ae *async_llm_engine) process_async_request(async_req *async_request) {
    if ae.concurrent_requests >= ae.max_concurrent {
        ae.request_queue <- async_req
        core.Sleep(100)
        return
    }

    async_req.request_info.state = async_request_state_queued
    async_req.request_info.added_time = core.CurrentTimeMs()

    err := ae.engine.add_request(async_req.request_id, async_req.prompt, async_req.sampling_params)
    if err != nil {
        async_req.request_info.state = async_request_state_failed
        async_req.request_info.error_message = err.Error()

        if async_req.callback != nil {
            go async_req.callback(nil, err)
        }

        ae.failed_requests++
        return
    }

    async_req.request_info.state = async_request_state_running
    async_req.request_info.start_time = core.CurrentTimeMs()

    ae.request_callbacks[async_req.request_id] = async_req.request_info

    if async_req.stream_callback != nil {
        ae.engine.register_stream_callback(async_req.request_id, async_req.stream_callback)
    }

    core.Printf("async request started: %s (concurrent: %d)\n", async_req.request_id, ae.concurrent_requests)
}

func (ae *async_llm_engine) check_completed_requests() {
    for request_id, req_info := range ae.request_callbacks {
        if req_info.state != async_request_state_running {
            continue
        }

        output := ae.engine.get_output(request_id)
        if output != nil && output.finish_reason != "" {
            req_info.state = async_request_state_completed
            req_info.complete_time = core.CurrentTimeMs()

            if req_info.callback != nil {
                go func(cb async_request_callback, out *request_output) {
                    cb(out, nil)
                }(req_info.callback, output)
            }

            ae.completed_requests++
            ae.concurrent_requests--
        }
    }
}

func (ae *async_llm_engine) generate_completion_async(
    prompt string,
    sampling_params sampling_params,
    callback async_request_callback) (string, error) {

    return ae.generate_completion_async_advanced(
        prompt,
        sampling_params,
        callback,
        nil,
        ae.pool_config.request_timeout_ms,
        0,
    )
}

func (ae *async_llm_engine) generate_completion_async_advanced(
    prompt string,
    sampling_params sampling_params,
    callback async_request_callback,
    stream_callback async_request_stream_callback,
    timeout_ms int64,
    priority int32) (string, error) {

    if !ae.is_running {
        return "", core.Errorf("async engine workers not running")
    }

    request_id := core.GenerateId()

    if timeout_ms <= 0 {
        timeout_ms = ae.pool_config.request_timeout_ms
    }

    req_info := &async_request_info{
        request_id:      request_id,
        state:           async_request_state_queued,
        added_time:      core.CurrentTimeMs(),
        callback:        callback,
        stream_callback: stream_callback,
        timeout_ms:      timeout_ms,
        max_retries:     ae.pool_config.max_retries,
        retry_count:     0,
    }

    async_req := &async_request{
        request_id:      request_id,
        prompt:          prompt,
        sampling_params: sampling_params,
        callback:        callback,
        stream_callback: stream_callback,
        timeout_ms:      timeout_ms,
        priority:        priority,
        request_info:    req_info,
    }

    select {
    case ae.request_queue <- async_req:
        ae.concurrent_requests++
        ae.total_requests++
        return request_id, nil
    default:
        return "", core.Errorf("request queue full (size limit: %d)", ae.pool_config.max_request_queue_size)
    }
}

func (ae *async_llm_engine) poll_output(request_id string) (*request_output, error) {
    req_info, exists := ae.request_callbacks[request_id]
    if !exists {
        return nil, core.Errorf("request not found: %s", request_id)
    }

    if req_info.state == async_request_state_failed {
        return nil, core.Errorf("request failed: %s", req_info.error_message)
    }

    if req_info.state != async_request_state_completed {
        return nil, core.Errorf("request not completed yet: %s (state: %d)", request_id, req_info.state)
    }

    output := ae.engine.get_output(request_id)
    if output == nil {
        return nil, core.Errorf("output not found for completed request: %s", request_id)
    }

    return output, nil
}

func (ae *async_llm_engine) cancel_request(request_id string) error {
    req_info, exists := ae.request_callbacks[request_id]
    if !exists {
        return core.Errorf("request not found: %s", request_id)
    }

    if req_info.state == async_request_state_completed || req_info.state == async_request_state_cancelled {
        return core.Errorf("cannot cancel request in state: %d", req_info.state)
    }

    req_info.state = async_request_state_cancelled
    ae.cancelled_requests++

    err := ae.engine.abort_request(request_id)
    if err != nil {
        core.Printf("error aborting request in engine: %v\n", err)
    }

    delete(ae.request_callbacks, request_id)

    return nil
}

func (ae *async_llm_engine) abort_request(request_id string) error {
    return ae.cancel_request(request_id)
}

func (ae *async_llm_engine) abort_all() error {
    core.Println("aborting all requests...")

    for request_id := range ae.request_callbacks {
        ae.cancel_request(request_id)
    }

    ae.request_callbacks = make(map[string]*async_request_info)

    return nil
}

func (ae *async_llm_engine) get_request_state(request_id string) async_request_state {
    req_info, exists := ae.request_callbacks[request_id]
    if !exists {
        return -1
    }
    return req_info.state
}

func (ae *async_llm_engine) get_num_unfinished_requests() int32 {
    count := int32(0)

    for _, req_info := range ae.request_callbacks {
        if req_info.state == async_request_state_running || req_info.state == async_request_state_queued {
            count++
        }
    }

    return count
}

func (ae *async_llm_engine) get_num_waiting_requests() int32 {
    count := int32(0)

    for _, req_info := range ae.request_callbacks {
        if req_info.state == async_request_state_queued {
            count++
        }
    }

    return count
}

func (ae *async_llm_engine) get_num_running_requests() int32 {
    count := int32(0)

    for _, req_info := range ae.request_callbacks {
        if req_info.state == async_request_state_running {
            count++
        }
    }

    return count
}

func (ae *async_llm_engine) event_loop() {
    for ae.is_running {
        select {
        case <-ae.stop_signal:
            return
        case event := <-ae.event_loop_channel:
            ae.handle_event(event)
        default:
            core.Sleep(100)
        }
    }
}

func (ae *async_llm_engine) handle_event(event *async_event) {
    if event == nil {
        return
    }

    switch event.event_type {
    case "request_complete":
        core.Printf("event: request %s completed\n", event.request_id)
    case "request_failed":
        core.Printf("event: request %s failed\n", event.request_id)
    case "timeout":
        core.Printf("event: request %s timed out\n", event.request_id)
        ae.cancel_request(event.request_id)
    case "retry":
        core.Printf("event: retrying request %s\n", event.request_id)
    }
}

func (ae *async_llm_engine) timeout_checker() {
    if !ae.pool_config.enable_request_timeout {
        return
    }

    for ae.is_running {
        current_time := core.CurrentTimeMs()

        for request_id, req_info := range ae.request_callbacks {
            if req_info.state != async_request_state_running {
                continue
            }

            elapsed := current_time - req_info.start_time
            if elapsed > req_info.timeout_ms {
                event := &async_event{
                    event_type: "timeout",
                    request_id: request_id,
                }

                select {
                case ae.event_loop_channel <- event:
                default:
                    core.Printf("warning: event loop channel full for timeout\n")
                }
            }
        }

        core.Sleep(1000)
    }
}

func (ae *async_llm_engine) stop_workers() error {
    if !ae.is_running {
        return core.Errorf("async engine workers not running")
    }

    ae.is_running = false

    for i := int32(0); i < ae.pool_config.worker_thread_count; i++ {
        ae.stop_signal <- true
    }

    for i := int32(0); i < ae.pool_config.worker_thread_count; i++ {
        <-ae.workers_stopped
    }

    core.Println("async_llm_engine workers stopped")
    return nil
}

func (ae *async_llm_engine) shutdown() error {
    if ae.is_running {
        ae.abort_all()
        ae.stop_workers()
    }

    ae.engine.print_stats()
    ae.print_async_stats()

    return ae.engine.shutdown()
}

func (ae *async_llm_engine) get_stats() map[string]interface{} {
    stats := make(map[string]interface{})

    engine_stats := ae.engine.get_stats()
    stats["total_requests"] = engine_stats.total_requests
    stats["total_tokens"] = engine_stats.total_tokens
    stats["avg_latency_ms"] = engine_stats.avg_latency_ms
    stats["throughput_tps"] = engine_stats.throughput_tps

    stats["async_total_requests"] = ae.total_requests
    stats["async_completed_requests"] = ae.completed_requests
    stats["async_failed_requests"] = ae.failed_requests
    stats["async_cancelled_requests"] = ae.cancelled_requests

    stats["unfinished_requests"] = ae.get_num_unfinished_requests()
    stats["waiting_requests"] = ae.get_num_waiting_requests()
    stats["running_requests"] = ae.get_num_running_requests()

    stats["concurrent_requests"] = ae.concurrent_requests
    stats["max_concurrent"] = ae.max_concurrent

    return stats
}

func (ae *async_llm_engine) print_async_stats() {
    elapsed := core.CurrentTimeMs() - ae.start_time
    completion_rate := float32(0.0)
    if ae.total_requests > 0 {
        completion_rate = float32(ae.completed_requests) / float32(ae.total_requests) * 100.0
    }

    core.Println("\n" + "="*60)
    core.Println("async_llm_engine Statistics")
    core.Println("="*60)
    core.Printf("Total async requests: %d\n", ae.total_requests)
    core.Printf("Completed: %d (%.1f%%)\n", ae.completed_requests, completion_rate)
    core.Printf("Failed: %d\n", ae.failed_requests)
    core.Printf("Cancelled: %d\n", ae.cancelled_requests)
    core.Printf("Unfinished: %d\n", ae.get_num_unfinished_requests())
    core.Printf("Total elapsed: %d ms (%.2f seconds)\n", elapsed, float32(elapsed)/1000.0)
    core.Printf("Request throughput: %.2f req/s\n", float32(ae.total_requests) / (float32(elapsed) / 1000.0))
    core.Println("="*60 + "\n")
}

func (ae *async_llm_engine) wait_all_completed(timeout_ms int64) error {
    start := core.CurrentTimeMs()

    for {
        if ae.get_num_unfinished_requests() == 0 {
            return nil
        }

        elapsed := core.CurrentTimeMs() - start
        if timeout_ms > 0 && elapsed > timeout_ms {
            return core.Errorf("timeout waiting for all requests to complete (timeout: %d ms, unfinished: %d)",
                timeout_ms, ae.get_num_unfinished_requests())
        }

        core.Sleep(100)
    }
}

func (ae *async_llm_engine) is_request_completed(request_id string) bool {
    req_info, exists := ae.request_callbacks[request_id]
    if !exists {
        return false
    }
    return req_info.state == async_request_state_completed
}

func (ae *async_llm_engine) get_request_latency_ms(request_id string) int64 {
    req_info, exists := ae.request_callbacks[request_id]
    if !exists {
        return 0
    }

    if req_info.complete_time > 0 && req_info.start_time > 0 {
        return req_info.complete_time - req_info.start_time
    }

    if req_info.start_time > 0 {
        return core.CurrentTimeMs() - req_info.start_time
    }

    return 0
}
