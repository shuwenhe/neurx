package main

use std.strings
use std.io
use neurx.tool_parsers

func main() {
    println("╔════════════════════════════════════════════════════════════════╗")
    println("║     NeurX Tool Calling & Function Extraction Framework         ║")
    println("║           40+ Model-Specific Tool Parsers (S Lang)            ║")
    println("╚════════════════════════════════════════════════════════════════╝\n")

    registry := get_global_registry()
    available := list_available_parsers()

    println("Available Parsers: " + int_to_string(len(available)) + " models")
    println("─────────────────────────────────────────────────────────────\n")

    i := 0
    while i < len(available) {
        print("  • " + available[i])
        if (i + 1) % 3 == 0 {
            print("\n")
        } else {
            print("  |  ")
        }
        i = i + 1
    }
    print("\n\n")

    test_deepseek_parser()
    test_qwen_parser()
    test_mistral_parser()
    test_gemma_parser()
    test_custom_extraction()
}

func test_deepseek_parser() {
    println("═════════════════════════════════════════════════════════════════")
    println("TEST 1: DeepSeek V3 Parser")
    println("═════════════════════════════════════════════════════════════════\n")

    model_output := "The search query is: weather\n<｜tool▁calls▁begin｜>\n<｜tool▁call▁begin｜>\nsearch_web\n<｜tool▁sep｜>\n```json\n{\"query\": \"weather today\"}\n```\n<｜tool▁call▁end｜>\n<｜tool▁calls▁end｜>"

    tools := vec![
        "search_web",
        "get_time",
        "calculator"
    ]

    result := extract_tool_calls("deepseek-v3", model_output, tools)

    println("Input model output:\n" + model_output + "\n")
    println("Parser: DeepSeek V3")
    println("Available tools: " + int_to_string(len(tools)))
    println("\nExtraction Result:")
    println("─────────────────────────────────────────────────────────────")
    println("Tools called: " + bool_to_string(result.tools_called))
    println("Number of tool calls: " + int_to_string(len(result.tool_calls)))

    for tc in result.tool_calls {
        println("\n  Tool: " + tc.function.name)
        println("  Type: " + tc.type)
        println("  Arguments: " + tc.function.arguments)
    }

    if len(result.content) > 0 {
        println("\n  Content before tool calls: " + result.content)
    }

    print("\n\n")
}

func test_qwen_parser() {
    println("═════════════════════════════════════════════════════════════════")
    println("TEST 2: Qwen3 Parser")
    println("═════════════════════════════════════════════════════════════════\n")

    model_output := "I'll help you with that.\n{\"function\": \"system_info\", \"arguments\": {\"type\": \"cpu\", \"detailed\": true}}\n\nLet me check the details."

    tools := vec![
        "system_info",
        "file_read",
        "network_test"
    ]

    result := extract_tool_calls("qwen3-32b", model_output, tools)

    println("Input model output:\n" + model_output + "\n")
    println("Parser: Qwen3")
    println("\nExtraction Result:")
    println("─────────────────────────────────────────────────────────────")
    println("Tools called: " + bool_to_string(result.tools_called))
    println("Number of tool calls: " + int_to_string(len(result.tool_calls)))

    for tc in result.tool_calls {
        println("\n  Tool: " + tc.function.name)
        println("  Type: " + tc.type)
        println("  Arguments: " + tc.function.arguments)
    }

    print("\n\n")
}

func test_mistral_parser() {
    println("═════════════════════════════════════════════════════════════════")
    println("TEST 3: Mistral Parser")
    println("═════════════════════════════════════════════════════════════════\n")

    model_output := "I'll search for information.\n[TOOL_CALLS]\n[TOOL_CALL]search(query=\"AI trends 2024\")[/TOOL_CALL]\n[/TOOL_CALLS]\n\nHere are the results..."

    tools := vec![
        "search",
        "summarize",
        "translate"
    ]

    result := extract_tool_calls("mistral-large", model_output, tools)

    println("Input model output:\n" + model_output + "\n")
    println("Parser: Mistral")
    println("\nExtraction Result:")
    println("─────────────────────────────────────────────────────────────")
    println("Tools called: " + bool_to_string(result.tools_called))
    println("Number of tool calls: " + int_to_string(len(result.tool_calls)))

    for tc in result.tool_calls {
        println("\n  Tool: " + tc.function.name)
        println("  Type: " + tc.type)
        println("  Arguments: " + tc.function.arguments)
    }

    print("\n\n")
}

func test_gemma_parser() {
    println("═════════════════════════════════════════════════════════════════")
    println("TEST 4: Gemma4 Parser")
    println("═════════════════════════════════════════════════════════════════\n")

    model_output := "Let me process your request.\n{\"function_name\": \"calculate\", \"function_arguments\": {\"expression\": \"2 + 2 * 3\"}}\n\nThe calculation is complete."

    tools := vec![
        "calculate",
        "plot",
        "solve_equation"
    ]

    result := extract_tool_calls("gemma-4-9b", model_output, tools)

    println("Input model output:\n" + model_output + "\n")
    println("Parser: Gemma4")
    println("\nExtraction Result:")
    println("─────────────────────────────────────────────────────────────")
    println("Tools called: " + bool_to_string(result.tools_called))
    println("Number of tool calls: " + int_to_string(len(result.tool_calls)))

    for tc in result.tool_calls {
        println("\n  Tool: " + tc.function.name)
        println("  Type: " + tc.type)
        println("  Arguments: " + tc.function.arguments)
    }

    print("\n\n")
}

func test_custom_extraction() {
    println("═════════════════════════════════════════════════════════════════")
    println("TEST 5: Tool Call Validation & Filtering")
    println("═════════════════════════════════════════════════════════════════\n")

    model_output := "{\"function\": \"query_database\", \"arguments\": {\"table\": \"users\"}}\n{\"function\": \"invalid_tool\", \"arguments\": {\"param\": \"value\"}}"

    tools := vec![
        "query_database",
        "write_file",
        "send_email"
    ]

    result := extract_tool_calls("qwen3", model_output, tools)
    validated := validate_tool_calls(result.tool_calls, tools)

    println("Input model output:\n" + model_output + "\n")
    println("\nExtracted tool calls: " + int_to_string(len(result.tool_calls)))

    for tc in result.tool_calls {
        println("  • " + tc.function.name)
    }

    println("\nAfter validation (strict mode):")
    println("  Valid tool calls: " + int_to_string(len(validated)))

    for tc in validated {
        println("  • " + tc.function.name + " [VALID]")
    }

    println("\n\nExtraction utils examples:")
    println("─────────────────────────────────────────────────────────────")

    test_xml := "<tool_call>{\"name\": \"func1\"}</tool_call><tool_call>{\"name\": \"func2\"}</tool_call>"
    extracted := ToolExtractorUtils::extract_xml_elements(test_xml, "tool_call")

    println("XML extraction test:")
    println("  Input: " + test_xml)
    println("  Extracted elements: " + int_to_string(len(extracted)))

    for elem in extracted {
        println("    - " + elem)
    }

    println("\n\nValidation examples:")
    println("─────────────────────────────────────────────────────────────")

    test_json := "{\"valid\": true, \"nested\": {\"data\": [1, 2, 3]}}"
    is_valid := ToolExtractorUtils::validate_json_structure(test_json)
    println("JSON structure validation:")
    println("  Input: " + test_json)
    println("  Valid: " + bool_to_string(is_valid))

    invalid_json := "{\"missing\": closing brace"
    is_invalid := ToolExtractorUtils::validate_json_structure(invalid_json)
    println("\n  Input: " + invalid_json)
    println("  Valid: " + bool_to_string(is_invalid))

    print("\n\n")
}

func bool_to_string(b: bool) -> str {
    if b { "true" } else { "false" }
}

func int_to_string(i: i32) -> str {
    i.to_string()
}
