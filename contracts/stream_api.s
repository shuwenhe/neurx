import "device_api"
import "event_api"

enum StreamPriority {
    High
    Normal
    Low
}

enum StreamType {
    Compute
    Transfer
    Communication
    Default
}

struct Stream {
    id: i64
    device: Device
    stream_type: StreamType
    priority: StreamPriority
    is_blocking: bool
}

interface IStream {

    stream_id() -> i64
    device() -> Device
    stream_type() -> StreamType
    priority() -> StreamPriority
    is_blocking() -> bool

    synchronize() -> void
    is_ready() -> bool

    record_event() -> Event
    wait_event(event: Event) -> void

    wait_stream(other_stream: Stream) -> void

    query() -> bool
}

interface IStreamManager {

    create_stream(device: Device, stream_type: StreamType) -> Stream
    get_stream(device: Device, stream_type: StreamType) -> Stream

    get_default_stream(device: Device) -> Stream

    create_priority_stream(device: Device, priority: StreamPriority) -> Stream

    destroy_stream(stream: Stream) -> void

    list_streams(device: Device) -> []Stream

    synchronize_all(device: Device) -> void

    set_current_stream(stream: Stream) -> void
    get_current_stream(device: Device) -> Stream
}

interface IStreamSynchronization {

    stream_synchronize(stream: Stream) -> void

    stream_query(stream: Stream) -> bool

    stream_wait_until(stream: Stream, event: Event) -> void
}

interface IStreamCallback {

    add_callback(stream: Stream, callback: func() -> void) -> void

    add_callback_with_data(stream: Stream, callback: func(data: i64) -> void, data: i64) -> void
}

interface IStreamManagerSingleton {

    instance() -> IStreamManager

    initialize(device: Device) -> void

    finalize(device: Device) -> void
}
