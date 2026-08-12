import "device_api"
import "event_api"
enum stream_priority {
    high
    normal
    low
}
enum stream_type {
    compute
    transfer
    communication
    default
}

struct stream {
    id: i64
    device: device
    stream_type: StreamType
    priority: StreamPriority
    is_blocking: bool
}
interface i_stream {
    stream_id() -> i64
    device() -> device
    stream_type() -> StreamType
    priority() -> StreamPriority
    is_blocking() -> bool
    synchronize() -> void
    is_ready() -> bool
    record_event() -> event
    wait_event(event: event) -> void
    wait_stream(other_stream: stream) -> void
    query() -> bool
}
interface i_stream_manager {
    create_stream(device: device, stream_type: StreamType) -> stream
    get_stream(device: device, stream_type: StreamType) -> stream
    get_default_stream(device: device) -> stream
    create_priority_stream(device: device, priority: StreamPriority) -> stream
    destroy_stream(stream: stream) -> void
    list_streams(device: device) -> []stream
    synchronize_all(device: device) -> void
    set_current_stream(stream: stream) -> void
    get_current_stream(device: device) -> stream
}
interface i_stream_synchronization {
    stream_synchronize(stream: stream) -> void
    stream_query(stream: stream) -> bool
    stream_wait_until(stream: stream, event: event) -> void
}
interface i_stream_callback {
    add_callback(stream: stream, callback: func() -> void) -> void
    add_callback_with_data(stream: stream, callback: func(i64 data) -> void, i64 data) -> void
}
interface i_stream_manager_singleton {
    instance() -> IStreamManager
    initialize(device: device) -> void
    finalize(device: device) -> void
}

