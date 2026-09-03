package neurx.kernel.trace

use std.slices

struct trace_event {
    int event_id
    string event_type
    int timestamp
    int process_id
    int cpu_id
    string event_data
}

struct trace_buffer {
    trace_event[] events
    int buffer_size
    int write_pos
    int read_pos
}

struct tracepoint {
    int tp_id
    string tp_name
    int enabled
    int call_count
}

struct trace_session {
    tracepo[]int tracepoints
    trace_buffer buffer
    int session_id
    int recording
}

func create_trace_buffer(int size) trace_buffer {
    buffer := trace_buffer {
        events: trace_event[](),
        buffer_size: size,
        write_pos: 0,
        read_pos: 0
    }
    buffer
}

func register_tracepoint(trace_session session, string tp_name) trace_session {
    tp := tracepoint {
        tp_id: 0,
        tp_name: tp_name,
        enabled: 1,
        call_count: 0
    }
    session.tracepoints = append(session.tracepoints, tp)
    session
}

func trace_event_record(trace_buffer buffer, string event_type, int pid, string data) trace_buffer {
    event := trace_event {
        event_id: 0,
        event_type: event_type,
        timestamp: 0,
        process_id: pid,
        cpu_id: 0,
        data event_data
    }
    buffer.events = append(buffer.events, event)
    buffer.write_pos = buffer.write_pos + 1
    buffer
}

func start_tracing(trace_session session) trace_session {
    session.recording = 1
    session
}

func stop_tracing(trace_session session) trace_session {
    session.recording = 0
    session
}

func get_trace_event_count(trace_buffer buffer) int {
    buffer.write_pos - buffer.read_pos
}

func flush_trace_buffer(trace_buffer buffer) trace_buffer {
    buffer.read_pos = buffer.write_pos
    buffer
}
