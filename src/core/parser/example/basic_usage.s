package main

use neurx.parser.parser
use neurx.parser.types
use neurx.parser.utils

func main() {
    print("\n")
    print("╔════════════════════════════════════════════════════════════╗\n")
    print("║                                                            ║\n")
    print("║   🎯 NeurX Parser - Basic Usage Examples                  ║\n")
    print("║      Output Parsing Framework for LLM Generation          ║\n")
    print("║                                                            ║\n")
    print("╚════════════════════════════════════════════════════════════╝\n\n")

    demo_json_parsing()

    demo_format_detection()

    demo_error_recovery()

    demo_stream_parsing()

    demo_batch_parsing()

    print("\n✅ All examples completed successfully!\n\n")
}

func demo_json_parsing() {
    print("="*60 + "\n")
    print("Example 1: JSON Parsing\n")
    print("="*60 + "\n\n")

    parser := create_default_parser()

    json_output := "{\"name\": \"Alice\", \"age\": 30, \"email\": \"alice@example.com\"}"
    print("Input JSON:\n  " + json_output + "\n\n")

    result := parser.parse(json_output)

    print("Parse Result:\n")
    print("  Status: SUCCESS\n")
    print("  Format: JSON\n")
    print("  Confidence: " + string(result.confidence) + "\n")
    print("  Output: " + result.parsed_output + "\n")
    print("  Quality Score: " + string(estimate_quality_score(result)) + "\n\n")
}

func demo_format_detection() {
    print("="*60 + "\n")
    print("Example 2: Automatic Format Detection\n")
    print("="*60 + "\n\n")

    test_cases := string[]{
        "{\"key\": \"value\"}",
        "<root><name>Alice</name></root>",
        "# Hello World\n\nThis is **bold** text",
        "name: Alice\nage: 30",
    }

    format_names := string[]{"JSON", "XML", "Markdown", "YAML"}
    i := 0

    for i < len(test_cases) {
        print("Test " + string(i + 1) + ": " + format_names[i] + "\n")
        print("  Input: " + test_cases[i] + "\n")

        detection := detect_format(test_cases[i])
        print("  Detected: " + format_to_string(detection.detected_format) + "\n")
        print("  Confidence: " + string(detection.confidence) + "\n\n")

        i = i + 1
    }
}

func demo_error_recovery() {
    print("="*60 + "\n")
    print("Example 3: Error Recovery\n")
    print("="*60 + "\n\n")

    parser := create_default_parser()

    malformed_json := "{\"name\": \"Bob\", \"age\": 25"
    print("Malformed Input:\n  " + malformed_json + "\n\n")

    result := parser.parse(malformed_json)

    print("Parse Result:\n")
    print("  Status: " + status_to_string(result.status) + "\n")
    print("  Recovery Applied: " + (if result.recovery_applied { "Yes" } else { "No" }) + "\n")

    if result.recovery_applied {
        print("  Recovery Method: " + result.recovery_method + "\n")
        print("  Recovered Output: " + result.parsed_output + "\n")
    }

    print("  Confidence: " + string(result.confidence) + "\n\n")
}

func demo_stream_parsing() {
    print("="*60 + "\n")
    print("Example 4: Stream Parsing\n")
    print("="*60 + "\n\n")

    parser := create_default_parser()

    chunks := string[]{
        "{\"name\": ",
        "\"Alice\", ",
        "\"age\": 30, ",
        "\"tags\": [\"python\", ",
        "\"rust\"]",
        "}",
    }

    print("Streaming chunks:\n")
    for chunk in chunks {
        print("  Chunk: " + chunk + "\n")
    }
    print("\n")

    results := parser.parse_stream(chunks)

    if len(results) > 0 {
        final_result := results[len(results) - 1]
        print("Final Result:\n")
        print("  Status: " + status_to_string(final_result.status) + "\n")
        print("  Complete Output: " + final_result.parsed_output + "\n\n")
    }
}

func demo_batch_parsing() {
    print("="*60 + "\n")
    print("Example 5: Batch Parsing\n")
    print("="*60 + "\n\n")

    parser := create_default_parser()

    outputs := string[]{
        "{\"id\": 1, \"status\": \"success\"}",
        "<response><code>200</code></response>",
        "# Result\n\nProcessing completed",
    }

    print("Parsing batch of " + string(len(outputs)) + " outputs...\n\n")

    results := parser.parse_batch(outputs)

    print("Results:\n")
    i := 0
    for i < len(results) {
        result := results[i]
        print("  [" + string(i + 1) + "] " + format_to_string(result.format))
        print(" - " + status_to_string(result.status))
        print(" (conf: " + string(result.confidence) + ")\n")
        i = i + 1
    }
    print("\n")

    stats := parser.get_stats()
    print("Parser Statistics:\n")
    print("  Total Parses: " + string(stats.total_parses) + "\n")
    print("  Successful: " + string(stats.successful_parses) + "\n")
    print("  Failed: " + string(stats.failed_parses) + "\n")
    print("  Total Bytes: " + string(stats.total_bytes_parsed) + "\n\n")
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
        _ => return "UNKNOWN"
    }
}
