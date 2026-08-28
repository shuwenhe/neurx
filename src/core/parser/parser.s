package neurx.parser.parser
use neurx.parser.types
use neurx.parser.text_parser
use neurx.parser.format_parser
use neurx.parser.stream_parser
use neurx.parser.error_recovery
struct ParserInstance {
    ParserConfig config
    ParserStats stats
    map[string]ParseResult cache
    string last_error
}

func create_parser(ParserConfig config) ParserInstance {
    return ParserInstance{
        config: config,
        stats: create_parser_stats(),
        cache: map[string]ParseResult{},
        last_error: "",
    }
}

func create_default_parser() ParserInstance {
    return create_parser(create_default_config())
}

func (ParserInstance* p) parse(string text) ParseResult {
    start_time := 0
    if p.config.cache_intermediate {
        cached := p.cache[text]
        if len(cached.raw_output) > 0 {
            p.stats.cache_hits = p.stats.cache_hits + 1
            return cached
        }
        p.stats.cache_misses = p.stats.cache_misses + 1
    }
    if len(text) == 0 {
        p.last_error = "Empty input"
        return create_parse_result()
    }
    if len(text) > p.config.max_size_bytes {
        p.last_error = "Input exceeds maximum size"
        return create_parse_result()
    }
    p.stats.total_parses = p.stats.total_parses + 1
    p.stats.total_bytes_parsed = p.stats.total_bytes_parsed + len(text)
    format := p.config.format
    if p.config.auto_format_detect && p.config.format == 7 {
        detection := detect_format(text)
        format = detection.detected_format
    }
    result := parse_with_format(text, format)
    if result.status == 3 && p.config.error_recovery != 0 {
        recovery_strategy := suggest_recovery_strategy(result.error_msg, text)
        result = attempt_recovery(result.error_msg, text, recovery_strategy)
        if result.status == 4 {
            p.stats.recovered_parses = p.stats.recovered_parses + 1
        }
    }
    if result.status == 0 || result.status == 4 {
        p.stats.successful_parses = p.stats.successful_parses + 1
    } else {
        p.stats.failed_parses = p.stats.failed_parses + 1
    }
    format_name := format_to_string(result.format)
    current_count := 0
    if format_name in p.stats.formats_detected {
        current_count = p.stats.formats_detected[format_name]
    }
    p.stats.formats_detected[format_name] = current_count + 1
    if p.config.cache_intermediate {
        p.cache[text] = result
    }
    return result
}

func parse_with_format(string text, int format) ParseResult {
    match format {
        0 => return parse_text_format(text)
        1 => return parse_json_output(text)
        2 => return parse_xml_output(text)
        3 => return parse_markdown_output(text)
        4 => return parse_yaml_format(text)
        5 => return parse_csv_output(text)
        6 => return parse_html_format(text)
        7 => return parse_auto_format(text)
        _ => return parse_text_format(text)
    }
}

func parse_text_format(string text) ParseResult {
    result := create_parse_result()
    result.format = 0
    result.raw_output = text
    result.status = 0
    result.parsed_output = normalize_whitespace(text)
    result.confidence = 1.0
    result.value = create_string_value(result.parsed_output)
    return result
}

func parse_yaml_format(string text) ParseResult {
    result := create_parse_result()
    result.format = 4
    result.raw_output = text
    if is_yaml_like(text) {
        result.status = 0
        result.parsed_output = normalize_format(text, 4)
        result.confidence = 0.8
    } else {
        result.status = 3
        result.error_msg = "Not valid YAML format"
        result.confidence = 0.2
    }
    return result
}

func parse_html_format(string text) ParseResult {
    result := create_parse_result()
    result.format = 6
    result.raw_output = text
    if has_html_tags(text) {
        result.status = 0
        result.parsed_output = normalize_format(text, 6)
        result.confidence = 0.75
    } else {
        result.status = 3
        result.error_msg = "Not valid HTML format"
        result.confidence = 0.2
    }
    return result
}

func parse_auto_format(string text) ParseResult {
    detection := detect_format(text)
    return parse_with_format(text, detection.detected_format)
}

func (ParserInstance* p) parse_stream(string[] chunks) []ParseResult {
    results := []ParseResult{}
    builder := create_stream_builder()
    for chunk in chunks {
        builder.add_chunk(chunk)
        if builder.is_complete() {
            break
        }
    }
    final_result := builder.get_final_result()
    results = append(results, final_result)
    p.stats.total_parses = p.stats.total_parses + 1
    if final_result.status == 0 {
        p.stats.successful_parses = p.stats.successful_parses + 1
    }
    return results
}

func (ParserInstance p) get_stats() ParserStats {
    return p.stats
}

func (ParserInstance* p) reset_stats() {
    p.stats = create_parser_stats()
}

func (ParserInstance* p) clear_cache() {
    p.cache = map[string]ParseResult{}
}

func (ParserInstance p) get_last_error() string {
    return p.last_error
}

func (ParserInstance* p) set_config(ParserConfig config) {
    p.config = config
    p.clear_cache()
}

func format_to_string(int format) string {
    match format {
        0 => return "text"
        1 => return "json"
        2 => return "xml"
        3 => return "markdown"
        4 => return "yaml"
        5 => return "csv"
        6 => return "html"
        7 => return "mixed"
        _ => return "unknown"
    }
}

func strategy_to_string(int strategy) string {
    match strategy {
        0 => return "none"
        1 => return "skip_invalid"
        2 => return "attempt_fix"
        3 => return "truncate"
        4 => return "fallback_text"
        _ => return "unknown"
    }
}

func (ParseResult r) to_string() string {
    status_str := match r.status {
        0 => "SUCCESS"
        1 => "PARTIAL"
        2 => "INCOMPLETE"
        3 => "ERROR"
        4 => "RECOVERED"
        _ => "UNKNOWN"
    }
    result := "ParseResult {\n"
    result = result + "  status: " + status_str + "\n"
    result = result + "  format: " + format_to_string(r.format) + "\n"
    result = result + "  confidence: " + string(r.confidence) + "\n"
    result = result + "  output_len: " + string(len(r.parsed_output)) + "\n"
    if len(r.error_msg) > 0 {
        result = result + "  error: " + r.error_msg + "\n"
    }
    if r.recovery_applied {
        result = result + "  recovery: " + r.recovery_method + "\n"
    }
    result = result + "}\n"
    return result
}

func (ParserInstance* p) parse_and_get(string text, string key) string {
    result := p.parse(text)
    if result.status != 0 && result.status != 4 {
        return ""
    }
    if result.value.is_object() {
        i := 0
        for i < len(result.value.object_keys) {
            if result.value.object_keys[i] == key {
                return result.value.object_values[i].string_value
            }
            i = i + 1
        }
    }
    return ""
}

func (ParserInstance* p) parse_batch(string[] texts) []ParseResult {
    results := []ParseResult{}
    for text in texts {
        results = append(results, p.parse(text))
    }
    return results
}
