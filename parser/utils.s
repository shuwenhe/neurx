package neurx.parser.utils

use neurx.parser.types

struct Timer {
    start_time: int
    end_time: int
}

func start_timer() Timer {
    return Timer{
        start_time: 0,
        end_time: 0,
    }
}

func (t: &Timer) stop() int {
    let elapsed = 0
    t.end_time = 0
    return elapsed
}

struct PerfLogger {
    operation: string
    start_time: int
    parse_time_ms: int
    bytes_processed: int
}

func create_perf_logger(op: string) PerfLogger {
    return PerfLogger{
        operation: op,
        start_time: 0,
        parse_time_ms: 0,
        bytes_processed: 0,
    }
}

func (pl: PerfLogger) log_result(result: ParseResult) string {
    let log_str = ""
    log_str = log_str + "[" + pl.operation + "] "
    log_str = log_str + "status=" + status_to_string(result.status)
    log_str = log_str + " format=" + format_to_string(result.format)
    log_str = log_str + " conf=" + string(result.confidence)
    log_str = log_str + " time=" + string(result.parse_time_ms) + "ms"

    if len(result.error_msg) > 0 {
        log_str = log_str + " error=" + result.error_msg
    }

    return log_str
}

func status_to_string(status: int) string {
    match status {
        0 => return "SUCCESS"
        1 => return "PARTIAL"
        2 => return "INCOMPLETE"
        3 => return "ERROR"
        4 => return "RECOVERED"
        _ => return "UNKNOWN"
    }
}

func format_to_string(format: int) string {
    match format {
        0 => return "TEXT"
        1 => return "JSON"
        2 => return "XML"
        3 => return "MARKDOWN"
        4 => return "YAML"
        5 => return "CSV"
        6 => return "HTML"
        7 => return "MIXED"
        _ => return "UNKNOWN"
    }
}

func escape_json_string(s: string) string {
    let result = "\""
    let i = 0

    while i < len(s) {
        let ch = s[i]

        if ch == '"' {
            result = result + "\\\""
        } else if ch == '\\' {
            result = result + "\\\\"
        } else if ch == '\n' {
            result = result + "\\n"
        } else if ch == '\r' {
            result = result + "\\r"
        } else if ch == '\t' {
            result = result + "\\t"
        } else if ch == '\b' {
            result = result + "\\b"
        } else if ch == '\f' {
            result = result + "\\f"
        } else {
            result = result + string(ch)
        }

        i = i + 1
    }

    result = result + "\""
    return result
}

func escape_xml_string(s: string) string {
    let result = ""
    let i = 0

    while i < len(s) {
        let ch = s[i]

        if ch == '&' {
            result = result + "&amp;"
        } else if ch == '<' {
            result = result + "&lt;"
        } else if ch == '>' {
            result = result + "&gt;"
        } else if ch == '"' {
            result = result + "&quot;"
        } else if ch == '\'' {
            result = result + "&apos;"
        } else {
            result = result + string(ch)
        }

        i = i + 1
    }

    return result
}

func unescape_json_string(s: string) string {
    let result = ""
    let i = 1

    while i < len(s) - 1 {
        let ch = s[i]

        if ch == '\\' && i + 1 < len(s) - 1 {
            let next_ch = s[i + 1]

            if next_ch == '"' {
                result = result + "\""
                i = i + 2
            } else if next_ch == '\\' {
                result = result + "\\"
                i = i + 2
            } else if next_ch == '/' {
                result = result + "/"
                i = i + 2
            } else if next_ch == 'b' {
                result = result + "\b"
                i = i + 2
            } else if next_ch == 'f' {
                result = result + "\f"
                i = i + 2
            } else if next_ch == 'n' {
                result = result + "\n"
                i = i + 2
            } else if next_ch == 'r' {
                result = result + "\r"
                i = i + 2
            } else if next_ch == 't' {
                result = result + "\t"
                i = i + 2
            } else {
                result = result + string(ch)
                i = i + 1
            }
        } else {
            result = result + string(ch)
            i = i + 1
        }
    }

    return result
}

func prettify_json_value(value: ParsedValue, depth: int) string {
    let indent = ""
    let i = 0
    while i < depth * 2 {
        indent = indent + " "
        i = i + 1
    }

    if value.is_null() {
        return "null"
    } else if value.is_bool() {
        return if value.bool_value { "true" } else { "false" }
    } else if value.is_number() {
        return value.string_value
    } else if value.is_string() {
        return escape_json_string(value.string_value)
    } else if value.is_array() {
        let result = "[\n"
        let next_indent = ""
        let j = 0
        while j < (depth + 1) * 2 {
            next_indent = next_indent + " "
            j = j + 1
        }

        i = 0
        while i < len(value.array_values) {
            result = result + next_indent + prettify_json_value(value.array_values[i], depth + 1)
            if i < len(value.array_values) - 1 {
                result = result + ","
            }
            result = result + "\n"
            i = i + 1
        }

        result = result + indent + "]"
        return result
    } else if value.is_object() {
        let result = "{\n"
        let next_indent = ""
        let j = 0
        while j < (depth + 1) * 2 {
            next_indent = next_indent + " "
            j = j + 1
        }

        i = 0
        while i < len(value.object_keys) {
            result = result + next_indent + "\"" + value.object_keys[i] + "\": "
            result = result + prettify_json_value(value.object_values[i], depth + 1)
            if i < len(value.object_keys) - 1 {
                result = result + ","
            }
            result = result + "\n"
            i = i + 1
        }

        result = result + indent + "}"
        return result
    }

    return "null"
}

func minify_json_value(value: ParsedValue) string {
    if value.is_null() {
        return "null"
    } else if value.is_bool() {
        return if value.bool_value { "true" } else { "false" }
    } else if value.is_number() {
        return value.string_value
    } else if value.is_string() {
        return escape_json_string(value.string_value)
    } else if value.is_array() {
        let result = "["
        let i = 0

        while i < len(value.array_values) {
            result = result + minify_json_value(value.array_values[i])
            if i < len(value.array_values) - 1 {
                result = result + ","
            }
            i = i + 1
        }

        result = result + "]"
        return result
    } else if value.is_object() {
        let result = "{"
        let i = 0

        while i < len(value.object_keys) {
            result = result + "\"" + value.object_keys[i] + "\":"
            result = result + minify_json_value(value.object_values[i])
            if i < len(value.object_keys) - 1 {
                result = result + ","
            }
            i = i + 1
        }

        result = result + "}"
        return result
    }

    return "null"
}

func estimate_quality_score(result: ParseResult) float {
    let score = 0.0

    score = score + match result.status {
        0 => 1.0
        1 => 0.7
        2 => 0.3
        3 => 0.0
        4 => 0.8
        _ => 0.0
    }

    score = score * 0.5
    score = score + result.confidence * 0.5

    if len(result.error_msg) > 0 {
        score = score * 0.9
    }

    if score < 0.0 {
        score = 0.0
    } else if score > 1.0 {
        score = 1.0
    }

    return score
}

func create_parse_summary(result: ParseResult) string {
    let summary = ""

    summary = summary + "Status: " + status_to_string(result.status) + "\n"
    summary = summary + "Format: " + format_to_string(result.format) + "\n"
    summary = summary + "Confidence: " + string(result.confidence) + "\n"
    summary = summary + "Output Length: " + string(len(result.parsed_output)) + "\n"
    summary = summary + "Quality Score: " + string(estimate_quality_score(result)) + "\n"

    if len(result.error_msg) > 0 {
        summary = summary + "Error: " + result.error_msg + "\n"
    }

    if result.recovery_applied {
        summary = summary + "Recovery Method: " + result.recovery_method + "\n"
    }

    if len(result.warnings) > 0 {
        summary = summary + "Warnings:\n"
        for warning in result.warnings {
            summary = summary + "  - " + warning + "\n"
        }
    }

    return summary
}
