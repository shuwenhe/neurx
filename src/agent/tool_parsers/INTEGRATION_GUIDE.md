# Integration Guide: Tool Parsers with NeurX Inference
## Overview
This document explains how to integrate the 40+ model-specific tool parsers with NeurX's inference engines to enable production-grade function calling and tool use.
## Quick Start
### 1. Import in Your Module
```s
use neurx.tool_parsers
use neurx.tool_parsers.parsers
fn my_inference_function() {
    let model_output = generate_from_model(prompt, model)
    let tools = vec!["search", "calculator", "weather"]
    let result = extract_tool_calls(model_name, model_output, tools)
    if result.tools_called {
        for tool_call in result.tool_calls {
            execute_tool(tool_call.function.name, tool_call.function.arguments)
        }
    }
}
```
### 2. Request Context
```s
let request = ParserRequest {
    messages: conversation_history,
    tools: available_tools,
    tool_choice: "auto",  
    model: "deepseek-v3"
}
match get_parser_for_model("deepseek-v3") {
    Some(parser) => {
        let result = parser.extract_tool_calls(model_output, request)
    }
    None => println("No parser available")
}
```
## Integration Points
### 1. With Inference Engines
#### Production Inference Engine
```s
use neurx.inference.production_inference
use neurx.tool_parsers
fn inference_with_tools(
    model: Model,
    prompt: str,
    tools: Vec<str>
) -> (str, Vec<ToolCall>) {
    let output = model.generate(prompt)
    let result = extract_tool_calls(model.name(), output, tools)
    (result.content, result.tool_calls)
}
```
#### Real-time Inference Engine
```s
use neurx.inference.real_inference_engine
use neurx.tool_parsers
fn stream_with_tool_extraction(
    model: Model,
    prompt: str,
    tools: Vec<str>
) {
    let mut previous_text = ""
    for token in model.generate_stream(prompt) {
        let current_text = previous_text + token
        let request = ParserRequest {
            messages: vec![],
            tools: tools.clone(),
            tool_choice: "auto",
            model: model.name()
        }
        match get_parser_for_model(model.name()) {
            Some(parser) => {
                let delta = parser.extract_tool_calls_streaming(
                    previous_text,
                    current_text,
                    token,
                    request
                )
                if delta.index >= 0 {
                    stream_tool_delta(delta)
                }
            }
            None => {}
        }
        previous_text = current_text
    }
}
```
### 2. With Serving Infrastructure
#### OpenAI-Compatible API
```s
use neurx.api.openai_compat
use neurx.tool_parsers
fn handle_tool_calling_request(
    request: ChatCompletionRequest
) -> ChatCompletionResponse {
    let model_output = model.generate(request.messages)
    let extracted = extract_tool_calls(
        request.model,
        model_output,
        request.tools.unwrap_or(vec![])
    )
    if extracted.tools_called {
        return ChatCompletionResponse {
            choices: vec![{
                message: {
                    role: "assistant",
                    content: extracted.content,
                    tool_calls: extracted.tool_calls
                }
            }]
        }
    }
    standard_response(extracted.content)
}
```
#### REST API Server
```s
use neurx.serving.serve
use neurx.tool_parsers
route("/v1/completions", POST, |request| {
    let model = get_model(request.model)
    let output = model.generate(request.prompt)
    let tools = match request.tools {
        Some(t) => t,
        None => vec![]
    }
    let result = extract_tool_calls(request.model, output, tools)
    json_response({
        "text": result.content,
        "tool_calls": result.tool_calls,
        "stop_reason": if result.tools_called { "tool_calls" } else { "end_turn" }
    })
})
```
### 3. With Distributed Inference
```s
use neurx.distributed.data_parallel
use neurx.tool_parsers
fn distributed_inference_with_tools(
    models: Vec<Model>,
    prompt: str,
    tools: Vec<str>
) -> Vec<(str, Vec<ToolCall>)> {
    let mut results = vec![]
    for model in models {
        let output = model.generate(prompt)
        let extracted = extract_tool_calls(model.name(), output, tools)
        results.push((extracted.content, extracted.tool_calls))
    }
    results
}
```
## Format Adaptation for Each Model
### DeepSeek Models
```s
let model_name = "deepseek-v3-70b"
let request = ParserRequest {
    tools: vec!["search", "calculator"],
    tool_choice: "auto",
    model: model_name
}
match get_parser_for_model(model_name) {
    Some(parser) => {
        parser.extract_tool_calls(model_output, request)
    }
    None => {}
}
```
**Expected format in model output:**
```
<｜tool▁calls▁begin｜>
<｜tool▁call▁begin｜>search<｜tool▁sep｜>
```json
{"query": "AI trends"}
```
<｜tool▁call▁end｜>
<｜tool▁calls▁end｜>
```
### Qwen Models
```s
let parser = get_parser_for_model("qwen3-32b").unwrap()
let result = parser.extract_tool_calls(output, request)
```
**Expected format:**
```json
{
  "function": "search",
  "arguments": {"query": "AI trends"}
}
```
### Mistral Models
```s
let parser = get_parser_for_model("mistral-large").unwrap()
```
**Expected format:**
```
[TOOL_CALLS]
[TOOL_CALL]search(query="AI trends")[/TOOL_CALL]
[/TOOL_CALLS]
```
## Streaming Tool Extraction
For streaming responses with tool calling:
```s
use neurx.tool_parsers
fn stream_with_tool_support(
    model: Model,
    prompt: str,
    tools: Vec<str>
) {
    let parser = get_parser_for_model(model.name()).unwrap()
    let mut previous_text = ""
    for token in model.stream(prompt) {
        let current_text = previous_text + token
        let request = ParserRequest {
            tools: tools.clone(),
            tool_choice: "auto",
            model: model.name(),
            messages: vec![]
        }
        let delta = parser.extract_tool_calls_streaming(
            previous_text,
            current_text,
            token,
            request
        )
        if delta.index >= 0 {
            if len(delta.function.name) > 0 {
                emit_delta(delta)
            }
            if len(delta.function.arguments) > 0 {
                emit_delta_args(delta)
            }
        } else {
            emit_text_token(token)
        }
        previous_text = current_text
    }
}
```
## Error Handling
```s
use neurx.tool_parsers
fn safe_extract(
    model: str,
    output: str,
    tools: Vec<str>
) -> Result<ExtractedToolCallInformation, str> {
    match get_parser_for_model(model) {
        Some(parser) => {
            let request = ParserRequest {
                messages: vec![],
                tools: tools,
                tool_choice: "auto",
                model: model
            }
            let result = parser.extract_tool_calls(output, request)
            if result.tools_called {
                let validated = validate_tool_calls(result.tool_calls, tools)
                if len(validated) == 0 {
                    return Err("No valid tool calls found")
                }
                Ok(ExtractedToolCallInformation {
                    tools_called: true,
                    tool_calls: validated,
                    content: result.content
                })
            } else {
                Ok(result)
            }
        }
        None => Err("No parser for model: " + model)
    }
}
```
## Tool Execution Pipeline
```s
use neurx.tool_parsers
fn full_tool_calling_pipeline(
    model: Model,
    prompt: str,
    available_tools: Vec<ToolDefinition>
) -> str {
    let tool_names = available_tools.map(|t| t.name)
    let output = model.generate_with_tools(prompt, tool_names)
    let extracted = extract_tool_calls(model.name(), output, tool_names)
    if !extracted.tools_called {
        return extracted.content
    }
    let validated = validate_tool_calls(extracted.tool_calls, tool_names)
    let mut tool_results = vec![]
    for tool_call in validated {
        let tool = find_tool_by_name(&available_tools, tool_call.function.name)
        match tool {
            Some(t) => {
                let result = execute_tool(&t, tool_call.function.arguments)
                tool_results.push(result)
            }
            None => println("Tool not found: " + tool_call.function.name)
        }
    }
    let final_prompt = build_followup_with_results(
        extracted.content,
        tool_results
    )
    model.generate(final_prompt)
}
```
## Configuration for Different Scenarios
### Strict Tool Calling (Production)
```s
let config = ToolParserConfig::default()
    .set_strict_mode(true)
let validated = validate_tool_calls(extracted.tool_calls, available_tools)
```
### Flexible Extraction (Experimental)
```s
let config = ToolParserConfig::default()
    .set_strict_mode(false)
```
### Streaming-Optimized
```s
let config = ToolParserConfig::default()
    .set_streaming_enabled(true)
    .set_strict_mode(false)
```
## Performance Considerations
### 1. Parser Caching
```s
let parser = get_parser_for_model(model_name)
for request in batch_requests {
    let result = parser.extract_tool_calls(request.output, request)
}
```
### 2. Lazy Loading
Parsers are loaded on first use:
```s
let parser = get_parser_for_model("deepseek-v3")
```
### 3. Incremental Streaming
Only process complete tool calls, hold back partial ones:
```s
let delta = parser.extract_tool_calls_streaming(prev, curr, token, req)
if delta.index >= 0 {
    emit_delta(delta)
}
```
## Monitoring & Logging
```s
use neurx.observability.metrics.performance_monitor
fn monitored_tool_extraction(
    model: str,
    output: str,
    tools: Vec<str>
) {
    let start = time::now()
    let result = extract_tool_calls(model, output, tools)
    let duration = time::now() - start
    log_extraction_metric({
        model: model,
        tools_found: result.tools_called,
        tool_count: len(result.tool_calls),
        duration_ms: duration.as_millis(),
        content_length: len(output)
    })
    result
}
```
## Multi-Model Ensembling with Tools
```s
fn ensemble_with_tool_voting(
    models: Vec<Model>,
    prompt: str,
    tools: Vec<str>
) -> Vec<ToolCall> {
    let mut all_calls = vec![]
    for model in models {
        let output = model.generate(prompt)
        let extracted = extract_tool_calls(model.name(), output, tools)
        all_calls.extend(extracted.tool_calls)
    }
    dedup_tool_calls(all_calls)
}
```
## Testing Tool Parsing
```s
#[test]
fn test_deepseek_parsing() {
    let output = "Data: <｜tool▁calls▁begin｜>...<｜tool▁calls▁end｜>"
    let result = extract_tool_calls("deepseek-v3", output, vec!["search"])
    assert!(result.tools_called)
    assert_eq!(len(result.tool_calls), 1)
}
#[test]
fn test_validation() {
    let calls = vec![
        ToolCall {
            type: "function",
            id: "",
            function: FunctionCall {
                name: "valid_tool",
                arguments: "{}"
            }
        }
    ]
    let validated = validate_tool_calls(calls, vec!["valid_tool"])
    assert_eq!(len(validated), 1)
}
```
## Troubleshooting
### Parser Not Found for Model
```
Error: No parser available
Solution: Check model name spelling, use get_parser_for_model() to auto-detect
```
### Tools Not Extracted
```
Error: tools_called = false
Check:
  1. Model output contains expected format markers
  2. Tool names match available_tools
  3. Parser supports the model's output format
```
### Streaming Incomplete
```
Error: Partial tool calls in stream
Solution: Wait for delta.index < 0 before processing next token
```
## Next Steps
1. **Integrate** with your inference engine
2. **Test** with production models
3. **Monitor** extraction performance
4. **Extend** with custom parsers if needed
5. **Optimize** for your use case
---
For more examples, see `COMPLETE_EXAMPLE.s` in the tool_parsers directory.
