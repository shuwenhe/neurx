package neurx.parser.types


    SUCCESS = 0
    PARTIAL = 1
    INCOMPLETE = 2
    ERROR = 3
    RECOVERED = 4
}


    TEXT = 0
    JSON = 1
    XML = 2
    MARKDOWN = 3
    YAML = 4
    CSV = 5
    HTML = 6
    MIXED = 7
}


    STRICT = 0
    LENIENT = 1
    STREAMING = 2
    CACHED = 3
}


    NONE = 0
    SKIP_INVALID = 1
    ATTEMPT_FIX = 2
    TRUNCATE = 3
    FALLBACK_TEXT = 4
}

struct ParsedValue {
    type: int
    string_value: string
    number_value: float
    bool_value: bool
    array_values: []ParsedValue
    object_keys: []string
    object_values: []ParsedValue
    raw_text: string
}

struct ParseResult {
    status: int
    value: ParsedValue
    format: int
    raw_output: string
    parsed_output: string
    error_msg: string
    error_pos: int
    recovery_applied: bool
    recovery_method: string
    parse_time_ms: int
    confidence: float
    warnings: []string
    metadata: map[string]string
}

struct IncrementalParseState {
    buffer: string
    position: int
    format_detected: int
    depth: int
    in_string: bool
    escape_char: string
    partial_value: ParsedValue
    is_complete: bool
    last_token: string
}

struct ParserConfig {
    mode: int
    format: int
    max_depth: int
    strict_mode: bool
    auto_format_detect: bool
    stream_mode: bool
    error_recovery: int
    max_error_recovery_attempts: int
    timeout_ms: int
    max_size_bytes: int
    preserve_whitespace: bool
    case_sensitive: bool
    normalize_output: bool
    cache_intermediate: bool
}

struct TokenBuffer {
    tokens: []string
    positions: []int
    types: []int
    confidence: []float
    buffer_size: int
}

struct ParseContext {
    input: string
    position: int
    line: int
    column: int
    config: ParseConfig
    state: IncrementalParseState
    token_buffer: TokenBuffer
    scope_stack: []string
    format_hints: []string
    errors: []string
    warnings: []string
}

struct FormatDetectionResult {
    detected_format: int
    confidence: float
    indicators: []string
    metadata: map[string]string
}

struct StreamChunk {
    data: string
    position: int
    is_complete: bool
    format_hint: int
    partial_parse: ParsedValue
    error: string
}

struct ParserStats {
    total_parses: int
    successful_parses: int
    failed_parses: int
    recovered_parses: int
    avg_parse_time_ms: float
    total_bytes_parsed: int
    cache_hits: int
    cache_misses: int
    formats_detected: map[string]int
}

func create_parse_result() ParseResult {
    return ParseResult{
        status: 3,
        value: create_null_value(),
        format: 0,
        raw_output: "",
        parsed_output: "",
        error_msg: "",
        error_pos: 0,
        recovery_applied: false,
        recovery_method: "",
        parse_time_ms: 0,
        confidence: 0.0,
        warnings: []string{},
        metadata: map[string]string{},
    }
}

func create_null_value() ParsedValue {
    return ParsedValue{
        type: 0,
        string_value: "",
        number_value: 0.0,
        bool_value: false,
        array_values: []ParsedValue{},
        object_keys: []string{},
        object_values: []ParsedValue{},
        raw_text: "null",
    }
}

func create_string_value(string s) ParsedValue {
    return ParsedValue{
        type: 3,
        string_value: s,
        number_value: 0.0,
        bool_value: false,
        array_values: []ParsedValue{},
        object_keys: []string{},
        object_values: []ParsedValue{},
        raw_text: "\"" + s + "\"",
    }
}

func create_number_value(float n) ParsedValue {
    str_val := ""
    int_n := int(n)
    if float(int_n) == n {
        str_val = string(int_n)
    } else {
        str_val = string(n)
    }
    return ParsedValue{
        type: 2,
        string_value: str_val,
        number_value: n,
        bool_value: false,
        array_values: []ParsedValue{},
        object_keys: []string{},
        object_values: []ParsedValue{},
        raw_text: str_val,
    }
}

func create_bool_value(bool b) ParsedValue {
    str_val := if b { "true" } else { "false" }
    return ParsedValue{
        type: 1,
        string_value: str_val,
        number_value: 0.0,
        bool_value: b,
        array_values: []ParsedValue{},
        object_keys: []string{},
        object_values: []ParsedValue{},
        raw_text: str_val,
    }
}

func create_array_value([]ParsedValue items) ParsedValue {
    return ParsedValue{
        type: 4,
        string_value: "",
        number_value: 0.0,
        bool_value: false,
        array_values: items,
        object_keys: []string{},
        object_values: []ParsedValue{},
        raw_text: "[...]",
    }
}

func create_object_value([]string keys, []ParsedValue values) ParsedValue {
    return ParsedValue{
        type: 5,
        string_value: "",
        number_value: 0.0,
        bool_value: false,
        array_values: []ParsedValue{},
        object_keys: keys,
        object_values: values,
        raw_text: "{...}",
    }
}

func create_default_config() ParserConfig {
    return ParserConfig{
        mode: 1,
        format: 7,
        max_depth: 100,
        strict_mode: false,
        auto_format_detect: true,
        stream_mode: false,
        error_recovery: 2,
        max_error_recovery_attempts: 3,
        timeout_ms: 5000,
        max_size_bytes: 10485760,
        preserve_whitespace: false,
        case_sensitive: true,
        normalize_output: true,
        cache_intermediate: true,
    }
}

func create_parser_context(string input, ParseConfig config) ParseContext {
    return ParseContext{
        input: input,
        position: 0,
        line: 1,
        column: 1,
        config: config,
        state: IncrementalParseState{
            buffer: "",
            position: 0,
            format_detected: 0,
            depth: 0,
            in_string: false,
            escape_char: "",
            partial_value: create_null_value(),
            is_complete: false,
            last_token: "",
        },
        token_buffer: TokenBuffer{
            tokens: []string{},
            positions: []int{},
            types: []int{},
            confidence: []float{},
            buffer_size: 0,
        },
        scope_stack: []string{},
        format_hints: []string{},
        errors: []string{},
        warnings: []string{},
    }
}

func (ParsedValue v) is_null() bool {
    return v.type == 0
}

func (ParsedValue v) is_bool() bool {
    return v.type == 1
}

func (ParsedValue v) is_number() bool {
    return v.type == 2
}

func (ParsedValue v) is_string() bool {
    return v.type == 3
}

func (ParsedValue v) is_array() bool {
    return v.type == 4
}

func (ParsedValue v) is_object() bool {
    return v.type == 5
}

func create_parser_stats() ParserStats {
    formats := map[string]int{}
    return ParserStats{
        total_parses: 0,
        successful_parses: 0,
        failed_parses: 0,
        recovered_parses: 0,
        avg_parse_time_ms: 0.0,
        total_bytes_parsed: 0,
        cache_hits: 0,
        cache_misses: 0,
        formats_detected: formats,
    }
}
