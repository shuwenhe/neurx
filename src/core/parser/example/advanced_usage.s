package main
use neurx.parser.parser
use neurx.parser.types
use neurx.parser.utils
use neurx.parser.text_parser
use neurx.parser.format_parser
func main() {
    print("\n")
    print("╔════════════════════════════════════════════════════════════╗\n")
    print("║                                                            ║\n")
    print("║   🎯 NeurX Parser - Advanced Usage Examples               ║\n")
    print("║      Production Integration Scenarios                     ║\n")
    print("║                                                            ║\n")
    print("╚════════════════════════════════════════════════════════════╝\n\n")
    demo_custom_config()
    demo_format_conversion()
    demo_realtime_parsing()
    demo_function_calling()
    demo_structured_extraction()
    print("\n✅ All advanced examples completed!\n\n")
}
func demo_custom_config() {
    print("="*60 + "\n")
    print("Example 1: Custom Parser Configuration\n")
    print("="*60 + "\n\n")
    config := ParserConfig{
        mode: 0,
        format: 1,
        max_depth: 50,
        strict_mode: true,
        auto_format_detect: false,
        stream_mode: false,
        error_recovery: 0,
        max_error_recovery_attempts: 0,
        timeout_ms: 1000,
        max_size_bytes: 1000000,
        preserve_whitespace: true,
        case_sensitive: true,
        normalize_output: false,
        cache_intermediate: false,
    }
    parser := create_parser(config)
    valid_json := "{\"items\": [1, 2, 3]}"
    print("Configuration: STRICT JSON mode\n")
    print("Input: " + valid_json + "\n\n")
    result := parser.parse(valid_json)
    print("Result: " + status_to_string(result.status) + "\n")
    print("Confidence: " + string(result.confidence) + "\n\n")
    lenient_config := create_default_config()
    parser.set_config(lenient_config)
    malformed := "{items: [1, 2, 3"
    print("Configuration: LENIENT mode (with error recovery)\n")
    print("Input: " + malformed + "\n\n")
    result2 := parser.parse(malformed)
    print("Result: " + status_to_string(result2.status) + "\n")
    print("Confidence: " + string(result2.confidence) + "\n")
    if result2.recovery_applied {
        print("Recovered using: " + result2.recovery_method + "\n")
    }
    print("\n")
}
func demo_format_conversion() {
    print("="*60 + "\n")
    print("Example 2: Multi-Format Conversion\n")
    print("="*60 + "\n\n")
    json_data := "{\"name\": \"Alice\", \"age\": 30}"
    print("Original JSON:\n  " + json_data + "\n\n")
    xml_form := convert_format(json_data, 1, 2)
    print("Converted to XML:\n  " + xml_form + "\n\n")
    yaml_form := convert_format(json_data, 1, 4)
    print("Converted to YAML:\n  " + yaml_form + "\n\n")
    text_form := normalize_format(json_data, 0)
    print("Normalized to TEXT:\n  " + text_form + "\n\n")
}
func demo_realtime_parsing() {
    print("="*60 + "\n")
    print("Example 3: Real-time LLM Output Parsing\n")
    print("="*60 + "\n\n")
    parser := create_default_parser()
    print("Simulating LLM real-time response...\n\n")
    chunks := string[]{
        "I think the answer is ",
        "{\"reasoning\": \"Let me work through this\", ",
        "\"steps\": [\"First\", \"Second\", \"Third\"], ",
        "\"final_answer\": 42}",
    }
    print("Chunks received:\n")
    for i, chunk in chunks {
        print("  [" + string(i) + "] " + chunk + "\n")
    }
    print("\n")
    results := parser.parse_stream(chunks)
    print("Parsing progress:\n")
    final_result := results[len(results) - 1]
    print("  Final status: " + status_to_string(final_result.status) + "\n")
    print("  Detected format: " + format_to_string(final_result.format) + "\n")
    print("  Confidence: " + string(final_result.confidence) + "\n")
    print("  Parsed output: " + final_result.parsed_output + "\n\n")
}
func demo_function_calling() {
    print("="*60 + "\n")
    print("Example 4: Function Calling Output\n")
    print("="*60 + "\n\n")
    parser := create_default_parser()
    func_response := "{\"function\": \"send_email\", \"parameters\": {\"to\": \"user@example.com\", \"subject\": \"Hello\", \"body\": \"This is a test\"}}"
    print("Function Calling Response:\n  " + func_response + "\n\n")
    result := parser.parse(func_response)
    print("Parsed Result:\n")
    print("  Status: " + status_to_string(result.status) + "\n")
    print("  Format: " + format_to_string(result.format) + "\n")
    print("  Output: " + result.parsed_output + "\n\n")
    function_name := parser.parse_and_get(func_response, "function")
    print("Extracted function name: " + function_name + "\n\n")
}
func demo_structured_extraction() {
    print("="*60 + "\n")
    print("Example 5: Structured Data Extraction\n")
    print("="*60 + "\n\n")
    parser := create_default_parser()
    markdown_table := "| Name | Age | City |\n| --- | --- | --- |\n| Alice | 30 | NYC |\n| Bob | 25 | LA |"
    print("Markdown Table:\n")
    print(markdown_table + "\n\n")
    result := parser.parse(markdown_table)
    print("Parse Result:\n")
    print("  Format: " + format_to_string(result.format) + "\n")
    print("  Status: " + status_to_string(result.status) + "\n")
    print("  Parsed: " + result.parsed_output + "\n\n")
    quality := estimate_quality_score(result)
    print("Quality Score: " + string(quality) + "\n\n")
}
func status_to_string(int status) string {
    match status {
        0 => return "SUCCESS"
        1 => return "PARTIAL"
        2 => return "INCOMPLETE"
        3 => return "ERROR"
        4 => return "RECOVERED"
        _ => return "UNKNOWN"
    }
}
func format_to_string(int format) string {
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
