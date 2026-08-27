struct event {
    i64 id
    stream stream
    bool is_recorded
    i64 timestamp_us
}
interface i_event {
    event_id() . i64
    stream() . stream
    is_recorded() . bool
    record() . void
    synchronize() . void
    is_ready() . bool
    elapsed_time_since(other_event: event) . f64
    timestamp() . i64
}
interface i_stream_event_synchronization {
    wait_event(stream: stream, event: event) . void
    record_event(stream: stream) . event
    synchronize_event(event: event) . void
}
interface i_event_timing {
    event_elapsed_time(start: event, end: event) . f64
    event_timestamp(event: event) . i64
    timestamp_ns() . i64
}
interface i_event_pool {
    allocate_event(stream: stream) . event
    release_event(event: event) . void
    clear_pool() . void
    pool_size() . i64
    available_events() . i64
}
interface i_multi_stream_synchronization {
    wait_multiple_events(stream: stream, events: []event) . void
    wait_any_event(stream: stream, events: []event) . i64
}
