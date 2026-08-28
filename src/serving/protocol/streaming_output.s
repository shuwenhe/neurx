package v1
struct backpressure_state {
    int32 buffer_capacity
    int32 current_buffer_size
    bool is_saturated
    int32 slowest_consumer_rate
}
struct token_stream {
    string request_id
    int32[] token_buffer
    int32 buffer_cursor
    bool completed
    backpressure_state bp_state
    int32 tokens_sent
    int32 tokens_received
    int64 last_send_time
}
func (token_stream* ts) next_token() (int32, bool) {
    if ts.buffer_cursor >= len(ts.token_buffer) {
        return -1, false
    }
    token := ts.token_buffer[ts.buffer_cursor]
    ts.buffer_cursor = ts.buffer_cursor + 1
    ts.tokens_sent = ts.tokens_sent + 1
    if ts.buffer_cursor >= len(ts.token_buffer) && ts.completed {
        return token, false
    }
    return token, true
}
func (token_stream* ts) wait_token(int32 timeout_ms) (int32, bool) {
    start := current_time_ns()
    timeout_ns := int64(timeout_ms) * 1000000
    for ts.buffer_cursor >= len(ts.token_buffer) {
        elapsed := current_time_ns() - start
        if elapsed > timeout_ns {
            return -1, false
        }
        if ts.completed && ts.buffer_cursor >= len(ts.token_buffer) {
            return -1, false
        }
        sleep_ms(10)
    }
    token := ts.token_buffer[ts.buffer_cursor]
    ts.buffer_cursor = ts.buffer_cursor + 1
    ts.tokens_sent = ts.tokens_sent + 1
    return token, true
}
func (token_stream* ts) send_token(int32 token_id) bool {
    if ts.bp_state.is_saturated {
        return false
    }
    ts.token_buffer = append(ts.token_buffer, token_id)
    ts.tokens_received = ts.tokens_received + 1
    ts.bp_state.current_buffer_size = ts.bp_state.current_buffer_size + 1
    if ts.bp_state.current_buffer_size >= ts.bp_state.buffer_capacity {
        ts.bp_state.is_saturated = true
        return false
    }
    ts.last_send_time = current_time_ns()
    return true
}
func (token_stream* ts) drain_to_client(int32 count) int32 {
    tokens_drained := 0
    for i := 0; i < count && ts.buffer_cursor < len(ts.token_buffer); i = i + 1 {
        ts.buffer_cursor = ts.buffer_cursor + 1
        tokens_drained = tokens_drained + 1
    }
    ts.bp_state.current_buffer_size = len(ts.token_buffer) - ts.buffer_cursor
    if ts.bp_state.current_buffer_size < (ts.bp_state.buffer_capacity / 2) {
        ts.bp_state.is_saturated = false
    }
    return tokens_drained
}
func (token_stream* ts) mark_completed() bool {
    ts.completed = true
    return true
}
func (token_stream* ts) is_completed() bool {
    return ts.completed && ts.buffer_cursor >= len(ts.token_buffer)
}
func (token_stream* ts) get_buffer_fill_percent() int32 {
    if ts.bp_state.buffer_capacity == 0 {
        return 0
    }
    return (ts.bp_state.current_buffer_size * 100) / ts.bp_state.buffer_capacity
}
func (token_stream* ts) get_tokens_sent() int32 {
    return ts.tokens_sent
}
func (token_stream* ts) get_tokens_pending() int32 {
    return len(ts.token_buffer) - ts.buffer_cursor
}
func (token_stream* ts) reset_backpressure() bool {
    ts.bp_state.is_saturated = false
    ts.bp_state.current_buffer_size = 0
    return true
}
struct stream_batch {
    token_stream*[] streams
    int32 batch_id
    int64 created_at
}
func (stream_batch* sb) add_stream(token_stream* stream) bool {
    sb.streams = append(sb.streams, stream)
    return true
}
func (stream_batch* sb) remove_stream(string request_id) bool {
    for i := 0; i < len(sb.streams); i = i + 1 {
        if sb.streams[i].request_id == request_id {
            sb.streams = append(sb.streams[:i], sb.streams[i+1:]...)
            return true
        }
    }
    return false
}
func (stream_batch* sb) get_stream(string request_id) token_stream* {
    for i := 0; i < len(sb.streams); i = i + 1 {
        if sb.streams[i].request_id == request_id {
            return sb.streams[i]
        }
    }
    return nil
}
func (stream_batch* sb) drain_all(int32 tokens_per_stream) int32 {
    total_drained := 0
    for i := 0; i < len(sb.streams); i = i + 1 {
        drained := sb.streams[i].drain_to_client(tokens_per_stream)
        total_drained = total_drained + drained
    }
    return total_drained
}
func (stream_batch* sb) count_active_streams() int32 {
    count := 0
    for i := 0; i < len(sb.streams); i = i + 1 {
        if !sb.streams[i].is_completed() {
            count = count + 1
        }
    }
    return count
}
struct stream_buffer_manager {
    map[string, token_stream] streams
    int32 max_buffer_size
    int32 total_buffered_tokens
}
func create_stream_buffer_manager(int32 max_buffer) stream_buffer_manager* {
    return *stream_buffer_manager{
        streams: make(map[string, token_stream]),
        max_buffer_size: max_buffer,
        total_buffered_tokens: 0,
    }
}
func (stream_buffer_manager* mgr) register_stream(string request_id) token_stream* {
    stream := token_stream{
        request_id: request_id,
        token_buffer: make(int32[]),
        buffer_cursor: 0,
        completed: false,
        bp_state: backpressure_state{
            buffer_capacity: 256,
            current_buffer_size: 0,
            is_saturated: false,
            slowest_consumer_rate: 1000,
        },
        tokens_sent: 0,
        tokens_received: 0,
        last_send_time: 0,
    }
    mgr.streams[request_id] = stream
    return *stream
}
func (stream_buffer_manager* mgr) unregister_stream(string request_id) bool {
    _, exists := mgr.streams[request_id]
    if !exists {
        return false
    }
    delete(mgr.streams, request_id)
    return true
}
func (stream_buffer_manager* mgr) send_token_to_stream(string request_id, int32 token_id) bool {
    stream, exists := mgr.streams[request_id]
    if !exists {
        return false
    }
    success := stream.send_token(token_id)
    mgr.streams[request_id] = stream
    if success {
        mgr.total_buffered_tokens = mgr.total_buffered_tokens + 1
    }
    return success
}
func (stream_buffer_manager* mgr) mark_stream_completed(string request_id) bool {
    stream, exists := mgr.streams[request_id]
    if !exists {
        return false
    }
    stream.mark_completed()
    mgr.streams[request_id] = stream
    return true
}
func (stream_buffer_manager* mgr) get_total_buffered() int32 {
    return mgr.total_buffered_tokens
}
func (stream_buffer_manager* mgr) get_buffer_pressure() int32 {
    if mgr.max_buffer_size == 0 {
        return 0
    }
    return (mgr.total_buffered_tokens * 100) / mgr.max_buffer_size
}
func sleep_ms(int32 ms) {
}
