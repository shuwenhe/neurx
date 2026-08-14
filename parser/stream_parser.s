
package neurx.parser.stream_parser

use neurx.parser.types
use neurx.parser.text_parser
use neurx.parser.format_parser

func create_stream_state() IncrementalParseState {
    return IncrementalParseState{
        buffer: "",
        position: 0,
        format_detected: 0,
        depth: 0,
        in_string: false,
        escape_char: "",
        partial_value: create_null_value(),
        is_complete: false,
        last_token: "",
    }
}

func process_stream_chunk(state: &IncrementalParseState, chunk: string) StreamChunk {

    state.buffer = state.buffer + chunk

    if state.format_detected == 0 && len(state.buffer) > 10 {
        let detection = detect_format(state.buffer)
        state.format_detected = detection.detected_format
    }

    let parse_result = incremental_parse(state)

    let chunk_result = StreamChunk{
        data: chunk,
        position: state.position,
        is_complete: state.is_complete,
        format_hint: state.format_detected,
        partial_parse: state.partial_value,
        error: "",
    }

    return chunk_result
}

func incremental_parse(state: &IncrementalParseState) ParseResult {
    let result = create_parse_result()
    result.format = state.format_detected
    result.raw_output = state.buffer

    if state.format_detected == 1 {
        parse_json_incremental(state)
    } else if state.format_detected == 2 {
        parse_xml_incremental(state)
    } else if state.format_detected == 3 {
        parse_markdown_incremental(state)
    } else {
        parse_text_incremental(state)
    }

    result.status = if state.is_complete { 0 } else { 1 }
    result.value = state.partial_value
    result.parsed_output = state.buffer[0:state.position]

    return result
}

func parse_json_incremental(state: &IncrementalParseState) {
    let buffer = state.buffer
    let pos = state.position

    while pos < len(buffer) {
        let ch = buffer[pos]

        if ch == '{' || ch == '[' {
            state.depth = state.depth + 1
        } else if ch == '}' || ch == ']' {
            state.depth = state.depth - 1
            if state.depth == 0 {
                state.is_complete = true
                state.position = pos + 1
                return
            }
        } else if ch == '"' && (pos == 0 || buffer[pos - 1] != '\\') {
            state.in_string = !state.in_string
        }

        state.last_token = string(ch)
        pos = pos + 1
    }

    state.position = pos
}

func parse_xml_incremental(state: &IncrementalParseState) {
    let buffer = state.buffer
    let pos = state.position
    let in_tag = false
    let tag_depth = 0

    while pos < len(buffer) {
        let ch = buffer[pos]

        if ch == '<' {
            in_tag = true
            if len(buffer) > pos + 1 && buffer[pos + 1] != '/' {
                tag_depth = tag_depth + 1
            }
        } else if ch == '>' {
            in_tag = false
            if len(buffer) > pos && buffer[pos - 1] != '/' {
                if len(buffer) > pos + 1 && buffer[pos + 1] != '<' {

                }
            }
        }

        state.last_token = string(ch)
        pos = pos + 1
    }

    state.position = pos
    state.is_complete = tag_depth == 0 && !in_tag
}

func parse_markdown_incremental(state: &IncrementalParseState) {
    let buffer = state.buffer
    let pos = state.position

    let line_count = count_character(buffer, '\n')
    state.is_complete = line_count >= 2

    state.position = len(buffer)
}

func parse_text_incremental(state: &IncrementalParseState) {

    state.position = len(state.buffer)

    state.is_complete = len(state.buffer) > 100
}

func count_character(text: string, ch: byte) int {
    let count = 0
    let i = 0

    while i < len(text) {
        if text[i] == ch {
            count = count + 1
        }
        i = i + 1
    }

    return count
}

func get_partial_output(state: IncrementalParseState) string {
    if state.position > len(state.buffer) {
        state.position = len(state.buffer)
    }
    return state.buffer[0:state.position]
}

func get_remaining_output(state: IncrementalParseState) string {
    if state.position > len(state.buffer) {
        state.position = len(state.buffer)
    }
    return state.buffer[state.position:]
}

func is_parse_complete(state: IncrementalParseState) bool {
    return state.is_complete
}

func reset_stream_state(state: &IncrementalParseState) {
    state.buffer = ""
    state.position = 0
    state.format_detected = 0
    state.depth = 0
    state.in_string = false
    state.escape_char = ""
    state.partial_value = create_null_value()
    state.is_complete = false
    state.last_token = ""
}

func finalize_stream(state: IncrementalParseState) ParseResult {
    let result = create_parse_result()
    result.format = state.format_detected
    result.raw_output = state.buffer
    result.parsed_output = state.buffer[0:state.position]
    result.value = state.partial_value

    if state.is_complete || (state.position >= len(state.buffer) - 5) {
        result.status = 0
        result.confidence = 0.9
    } else if state.position > 0 {
        result.status = 1
        result.confidence = 0.6
    } else {
        result.status = 3
        result.error_msg = "No output received"
        result.confidence = 0.0
    }

    return result
}

func extract_lines_from_stream(state: IncrementalParseState, max_lines: int) []string {
    let partial = get_partial_output(state)
    let lines = split_lines(partial)

    if len(lines) <= max_lines {
        return lines
    }

    let result = []string{}
    let i = 0
    while i < max_lines && i < len(lines) {
        result = append(result, lines[i])
        i = i + 1
    }

    return result
}

func estimate_progress(state: IncrementalParseState) float {
    if len(state.buffer) == 0 {
        return 0.0
    }

    let parsed_ratio = float(state.position) / float(len(state.buffer))

    if state.is_complete {
        return 1.0
    }

    return parsed_ratio * 0.9
}

struct StreamBuilder {
    chunks: []StreamChunk
    full_output: string
    current_state: IncrementalParseState
}

func create_stream_builder() StreamBuilder {
    return StreamBuilder{
        chunks: []StreamChunk{},
        full_output: "",
        current_state: create_stream_state(),
    }
}

func (sb: &StreamBuilder) add_chunk(chunk: string) {
    let stream_chunk = process_stream_chunk(&sb.current_state, chunk)
    sb.chunks = append(sb.chunks, stream_chunk)
    sb.full_output = sb.full_output + chunk
}

func (sb: StreamBuilder) get_current_output() string {
    return get_partial_output(sb.current_state)
}

func (sb: StreamBuilder) get_chunks() []StreamChunk {
    return sb.chunks
}

func (sb: StreamBuilder) is_complete() bool {
    return is_parse_complete(sb.current_state)
}

func (sb: StreamBuilder) get_final_result() ParseResult {
    return finalize_stream(sb.current_state)
}

func (sb: StreamBuilder) get_progress() float {
    return estimate_progress(sb.current_state)
}

func (sb: &StreamBuilder) reset() {
    sb.chunks = []StreamChunk{}
    sb.full_output = ""
    reset_stream_state(&sb.current_state)
}
