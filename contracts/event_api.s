// Event API - Synchronization and timing
//
// Event represents a point in Stream execution.
// Used for:
// - Synchronization between streams
// - Profiling (kernel timing)
// - Dependency tracking
//
// Stream -> Event -> Timer

struct Event {
    id: i64
    stream: Stream      // which stream this event is on
    is_recorded: bool
    timestamp_us: i64   // microseconds
}

interface IEvent {
    // Properties
    event_id() -> i64
    stream() -> Stream
    is_recorded() -> bool
    
    // Record event on stream (marks a point)
    record() -> void
    
    // Synchronization
    synchronize() -> void
    is_ready() -> bool
    
    // Timing
    elapsed_time_since(other_event: Event) -> f64  // milliseconds
    timestamp() -> i64  // microseconds
}

interface IStreamEventSynchronization {
    // Wait until event is ready
    wait_event(stream: Stream, event: Event) -> void
    
    // Record event on stream
    record_event(stream: Stream) -> Event
    
    // Synchronize event
    synchronize_event(event: Event) -> void
}

interface IEventTiming {
    // Get elapsed time between two events (must be on same stream or synchronized)
    event_elapsed_time(start: Event, end: Event) -> f64  // milliseconds
    
    // Get absolute timestamp
    event_timestamp(event: Event) -> i64  // microseconds
    
    // Convert to nanoseconds (for profiler)
    timestamp_ns() -> i64
}

interface IEventPool {
    // Allocate event from pool
    allocate_event(stream: Stream) -> Event
    
    // Release event back to pool
    release_event(event: Event) -> void
    
    // Clear all events in pool
    clear_pool() -> void
    
    // Pool statistics
    pool_size() -> i64
    available_events() -> i64
}

interface IMultiStreamSynchronization {
    // Wait for multiple events
    wait_multiple_events(stream: Stream, events: []Event) -> void
    
    // Wait for any event (similar to Unix select)
    wait_any_event(stream: Stream, events: []Event) -> i64  // returns index of first ready event
}
