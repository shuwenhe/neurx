struct Event {
    id: i64
    stream: Stream
    is_recorded: bool
    timestamp_us: i64
}

interface IEvent {

    event_id() -> i64
    stream() -> Stream
    is_recorded() -> bool

    record() -> void

    synchronize() -> void
    is_ready() -> bool

    elapsed_time_since(other_event: Event) -> f64
    timestamp() -> i64
}

interface IStreamEventSynchronization {

    wait_event(stream: Stream, event: Event) -> void

    record_event(stream: Stream) -> Event

    synchronize_event(event: Event) -> void
}

interface IEventTiming {

    event_elapsed_time(start: Event, end: Event) -> f64

    event_timestamp(event: Event) -> i64

    timestamp_ns() -> i64
}

interface IEventPool {

    allocate_event(stream: Stream) -> Event

    release_event(event: Event) -> void

    clear_pool() -> void

    pool_size() -> i64
    available_events() -> i64
}

interface IMultiStreamSynchronization {

    wait_multiple_events(stream: Stream, events: []Event) -> void

    wait_any_event(stream: Stream, events: []Event) -> i64
}
