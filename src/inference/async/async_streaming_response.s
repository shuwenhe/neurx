package async_inference

import "sync"

struct StreamingResponse {
    request_id      []string
    response_id     []string

    token_buffer    []int
    text_buffer     []string
    buffer_size     int
    max_buffer_size int

    started         bool
    completed       bool
    error_occurred  bool
    error_msg       []string

    tokens_sent     int64
    chunks_sent     int64
    latency_ms      int64
    started_at      int64
}

struct AsyncStreamingResponseManager {

    active_streams  map[string]StreamingResponse
    completed_streams []string

    buffer_size     int
    flush_interval  int64
    max_concurrent  int

    total_streams   int64
    total_tokens    int64
    avg_chunk_size  float64

    on_token_ready  map[string]string
    on_stream_end   map[string]string
    on_error        map[string]string

    mutex           sync.Mutex
}

func new_async_streaming_response_manager(buffer_size int, flush_interval int64, max_concurrent int) AsyncStreamingResponseManager {
    return AsyncStreamingResponseManager{
        active_streams:   make(map[string]StreamingResponse),
        completed_streams: make([]string, 0),
        buffer_size:      buffer_size,
        flush_interval:   flush_interval,
        max_concurrent:   max_concurrent,
        total_streams:    0,
        total_tokens:     0,
        avg_chunk_size:   0.0,
        on_token_ready:   make(map[string]string),
        on_stream_end:    make(map[string]string),
        on_error:         make(map[string]string),
        mutex:            sync.Mutex{},
    }
}

func (AsyncStreamingResponseManager* manager) start_stream(request_id []string, response_id []string) bool {
    manager.mutex.Lock()
    defer manager.mutex.Unlock()

    if len(request_id) == 0 || len(response_id) == 0 {
        return false
    }

    if len(manager.active_streams) >= manager.max_concurrent {
        return false
    }

    response := StreamingResponse{
        request_id:     request_id,
        response_id:    response_id,
        token_buffer:   make([]int, 0, manager.buffer_size),
        text_buffer:    make([]string, 0, manager.buffer_size),
        buffer_size:    0,
        max_buffer_size: manager.buffer_size,
        started:        true,
        completed:      false,
        error_occurred: false,
        tokens_sent:    0,
        chunks_sent:    0,
        started_at:     current_time_ms(),
    }

    manager.active_streams[request_id[0]] = response
    manager.total_streams = manager.total_streams + 1

    return true
}

func (AsyncStreamingResponseManager* manager) add_token_to_stream(request_id []string, token int, text []string) bool {
    manager.mutex.Lock()
    defer manager.mutex.Unlock()

    if len(request_id) == 0 {
        return false
    }

    response := manager.active_streams[request_id[0]]

    if !response.started || response.completed {
        return false
    }

    response.token_buffer = append(response.token_buffer, token)
    response.buffer_size = response.buffer_size + 1

    if len(text) > 0 {
        response.text_buffer = append(response.text_buffer, text[0])
    }

    should_flush := response.buffer_size >= response.max_buffer_size

    manager.active_streams[request_id[0]] = response

    if should_flush {
        return manager.flush_stream_internal(request_id)
    }

    return true
}

func (AsyncStreamingResponseManager* manager) flush_stream(request_id []string) bool {
    manager.mutex.Lock()
    defer manager.mutex.Unlock()

    return manager.flush_stream_internal(request_id)
}

func (AsyncStreamingResponseManager* manager) flush_stream_internal(request_id []string) bool {
    if len(request_id) == 0 {
        return false
    }

    response := manager.active_streams[request_id[0]]

    if response.buffer_size == 0 {
        return true
    }

    if callback := manager.on_token_ready[request_id[0]]; len(callback) > 0 {

    }

    response.tokens_sent = response.tokens_sent + int64(response.buffer_size)
    response.chunks_sent = response.chunks_sent + 1

    response.token_buffer = make([]int, 0, manager.buffer_size)
    response.text_buffer = make([]string, 0, manager.buffer_size)
    response.buffer_size = 0

    manager.active_streams[request_id[0]] = response
    manager.total_tokens = manager.total_tokens + int64(response.tokens_sent)

    return true
}

func (AsyncStreamingResponseManager* manager) complete_stream(request_id []string) bool {
    manager.mutex.Lock()
    defer manager.mutex.Unlock()

    if len(request_id) == 0 {
        return false
    }

    response := manager.active_streams[request_id[0]]

    if response.buffer_size > 0 {
        manager.flush_stream_internal(request_id)
    }

    response.completed = true
    response.latency_ms = current_time_ms() - response.started_at

    manager.active_streams[request_id[0]] = response
    manager.completed_streams = append(manager.completed_streams, request_id[0])

    if callback := manager.on_stream_end[request_id[0]]; len(callback) > 0 {

    }

    if response.chunks_sent > 0 {
        avg := float64(response.tokens_sent) / float64(response.chunks_sent)
        manager.avg_chunk_size = (manager.avg_chunk_size + avg) / 2.0
    }

    return true
}

func (AsyncStreamingResponseManager* manager) report_stream_error(request_id []string, error_msg []string) bool {
    manager.mutex.Lock()
    defer manager.mutex.Unlock()

    if len(request_id) == 0 {
        return false
    }

    response := manager.active_streams[request_id[0]]
    response.error_occurred = true
    response.error_msg = error_msg
    response.completed = true

    manager.active_streams[request_id[0]] = response

    if callback := manager.on_error[request_id[0]]; len(callback) > 0 {

    }

    return true
}

func (AsyncStreamingResponseManager* manager) get_stream_status(request_id []string) map[string]interface{} {
    manager.mutex.Lock()
    defer manager.mutex.Unlock()

    if len(request_id) == 0 {
        return make(map[string]interface{})
    }

    response := manager.active_streams[request_id[0]]

    status := make(map[string]interface{})
    status["started"] = response.started
    status["completed"] = response.completed
    status["error"] = response.error_occurred
    status["tokens_sent"] = response.tokens_sent
    status["chunks_sent"] = response.chunks_sent
    status["buffer_size"] = response.buffer_size
    status["latency_ms"] = response.latency_ms

    return status
}

func (AsyncStreamingResponseManager* manager) on_token_ready_callback(request_id []string, callback []string) {
    manager.mutex.Lock()
    defer manager.mutex.Unlock()

    if len(request_id) > 0 && len(callback) > 0 {
        manager.on_token_ready[request_id[0]] = callback[0]
    }
}

func (AsyncStreamingResponseManager* manager) on_stream_end_callback(request_id []string, callback []string) {
    manager.mutex.Lock()
    defer manager.mutex.Unlock()

    if len(request_id) > 0 && len(callback) > 0 {
        manager.on_stream_end[request_id[0]] = callback[0]
    }
}

func (AsyncStreamingResponseManager* manager) on_error_callback(request_id []string, callback []string) {
    manager.mutex.Lock()
    defer manager.mutex.Unlock()

    if len(request_id) > 0 && len(callback) > 0 {
        manager.on_error[request_id[0]] = callback[0]
    }
}

func (AsyncStreamingResponseManager* manager) get_active_stream_count() int {
    manager.mutex.Lock()
    defer manager.mutex.Unlock()

    return len(manager.active_streams)
}

func (AsyncStreamingResponseManager* manager) get_streaming_statistics() map[string]interface{} {
    manager.mutex.Lock()
    defer manager.mutex.Unlock()

    stats := make(map[string]interface{})
    stats["total_streams"] = manager.total_streams
    stats["active_streams"] = len(manager.active_streams)
    stats["completed_streams"] = len(manager.completed_streams)
    stats["total_tokens_streamed"] = manager.total_tokens
    stats["avg_chunk_size"] = manager.avg_chunk_size

    return stats
}

func (AsyncStreamingResponseManager* manager) cleanup_stream(request_id []string) {
    manager.mutex.Lock()
    defer manager.mutex.Unlock()

    if len(request_id) > 0 {
        delete(manager.active_streams, request_id[0])
        delete(manager.on_token_ready, request_id[0])
        delete(manager.on_stream_end, request_id[0])
        delete(manager.on_error, request_id[0])
    }
}

func (AsyncStreamingResponseManager* manager) clear_all_streams() {
    manager.mutex.Lock()
    defer manager.mutex.Unlock()

    manager.active_streams = make(map[string]StreamingResponse)
    manager.completed_streams = make([]string, 0)
    manager.on_token_ready = make(map[string]string)
    manager.on_stream_end = make(map[string]string)
    manager.on_error = make(map[string]string)
}

func main() {
    manager := new_async_streaming_response_manager(32, 1000, 100)

    request_id := make([]string, 1)
    request_id[0] = "req_001"

    response_id := make([]string, 1)
    response_id[0] = "resp_001"

    started := manager.start_stream(request_id, response_id)

    if started {
        for i := 0; i < 10; i++ {
            text := make([]string, 1)
            text[0] = "token"
            manager.add_token_to_stream(request_id, 1000+i, text)
        }

        manager.complete_stream(request_id)
    }

    stats := manager.get_streaming_statistics()
}
