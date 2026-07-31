struct event {
    id: i64
    stream: stream
    is_recorded: bool
    timestamp_us: i64
}
interface IEvent {
    event_id() -> i64
    stream() -> stream
    is_recorded() -> bool
    record() -> void
    synchronize() -> void
    is_ready() -> bool
    elapsed_time_since(other_event: event) -> f64
    timestamp() -> i64
}
interface IStreamEventSynchronization {
    wait_event(stream: stream, event: event) -> void
    record_event(stream: stream) -> event
    synchronize_event(event: event) -> void
}
interface IEventTiming {
    event_elapsed_time(start: event, end: event) -> f64
    event_timestamp(event: event) -> i64
    timestamp_ns() -> i64
}
interface IEventPool {
    allocate_event(stream: stream) -> event
    release_event(event: event) -> void
    clear_pool() -> void
    pool_size() -> i64
    available_events() -> i64
}
interface IMultiStreamSynchronization {
    wait_multiple_events(stream: stream, events: []event) -> void
    wait_any_event(stream: stream, events: []event) -> i64
}
