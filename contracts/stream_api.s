// Stream API - Asynchronous execution and synchronization
//
// Stream is NOT part of Device.
// StreamManager is the single source of truth.
//
// StreamManager -> Stream -> Event -> Device
//
// This allows:
// - Multiple streams per device (compute, copy, communication)
// - Unified priority handling
// - Clear synchronization points
// - Device implementation stays simple

import "device_api"
import "event_api"

enum StreamPriority {
    High
    Normal
    Low
}

enum StreamType {
    Compute              // General computation
    Transfer            // Host-Device copy
    Communication       // AllReduce, AllGather, etc.
    Default             // Default stream
}

struct Stream {
    id: i64
    device: Device
    stream_type: StreamType
    priority: StreamPriority
    is_blocking: bool   // Blocking vs non-blocking
}

interface IStream {
    // Properties
    stream_id() -> i64
    device() -> Device
    stream_type() -> StreamType
    priority() -> StreamPriority
    is_blocking() -> bool
    
    // Synchronization
    synchronize() -> void
    is_ready() -> bool
    
    // Event recording
    record_event() -> Event
    wait_event(event: Event) -> void
    
    // Stream dependencies
    wait_stream(other_stream: Stream) -> void
    
    // Query
    query() -> bool  // true if all work is done
}

interface IStreamManager {
    // Create/get streams
    create_stream(device: Device, stream_type: StreamType) -> Stream
    get_stream(device: Device, stream_type: StreamType) -> Stream
    
    // Default stream (guaranteed to exist)
    get_default_stream(device: Device) -> Stream
    
    // Priority stream
    create_priority_stream(device: Device, priority: StreamPriority) -> Stream
    
    // Destroy stream
    destroy_stream(stream: Stream) -> void
    
    // Get all streams for device
    list_streams(device: Device) -> []Stream
    
    // Synchronize all streams on device
    synchronize_all(device: Device) -> void
    
    // Set current stream (thread-local context)
    set_current_stream(stream: Stream) -> void
    get_current_stream(device: Device) -> Stream
}

interface IStreamSynchronization {
    // Wait for stream to complete
    stream_synchronize(stream: Stream) -> void
    
    // Query if stream is idle
    stream_query(stream: Stream) -> bool
    
    // Wait until condition (for async operations)
    stream_wait_until(stream: Stream, event: Event) -> void
}

interface IStreamCallback {
    // Register callback to run after stream operations complete
    add_callback(stream: Stream, callback: func() -> void) -> void
    
    // Callback with user data
    add_callback_with_data(stream: Stream, callback: func(data: i64) -> void, data: i64) -> void
}

// Global stream manager instance
interface IStreamManagerSingleton {
    // Get global stream manager
    instance() -> IStreamManager
    
    // Initialize stream manager for device
    initialize(device: Device) -> void
    
    // Finalize stream manager
    finalize(device: Device) -> void
}
