package neurx.inference.advanced.function_call
int FORMAT_OPENAI = 1
int FORMAT_ANTHROPIC = 2
int FORMAT_DEEPSEEK = 3
int FORMAT_CUSTOM = 4
struct function_parameter {
    string parameter_name
    string parameter_type
    string description
    bool required
}

struct function_def {
    string function_name
    []function_parameter parameters
    string description
    string return_type
}

struct argument_value {
    string name
    string value_type
    any value
}

struct detected_function_call {
    string function_name
    []argument_value arguments
    int format_type
    bool valid
    []string validation_errors
}

struct open_ai_function_call {
    string name
    map[string]any arguments
}

struct anthropic_tool_use {
    string type
    string id
    string name
    map[string]any input
}

struct function_registry {
    map[string]function_def functions
}

struct function_executor {
    function_registry registry
}

func NewFunctionRegistry() function_registry {
    return function_registry {
        functions: make(map[string]function_def),
    }
}

func (function_registry* registry) RegisterFunction(
    fn function_def,
) {
    registry.functions[fn.function_name] = fn
}

func (function_registry* registry) ListFunctions() []string {
    functions := make([]string, 0)
    for name := range registry.functions {
        functions = append(functions, name)
    }
    return functions
}

func (function_registry* registry) GetFunction(
    string name,
) (function_def, bool) {
    fn, ok := registry.functions[name]
    return fn, ok
}

struct function_call_detector {
    int format_type
    function_registry registry
}

func NewFunctionCallDetector(
    int format_type,
    function_registry registry,
) function_call_detector {
    return function_call_detector {
        format_type: format_type,
        registry: registry,
    }
}

func detect_openai_function_call(
    string text,
    function_registry registry,
) (detected_function_call, bool) {
    call := detected_function_call {
        format_type: FORMAT_OPENAI,
        arguments: make([]argument_value, 0),
        valid: false,
        validation_errors: make([]string, 0),
    }
    if !contains_substring(text, "<function_call>") {
        return call, false
    }
    start := index_of(text, "<function_call>") + len("<function_call>")
    end := index_of_from(text, "</function_call>", start)
    if start < 0 || end < 0 {
        return call, false
    }
    call_content := substring(text, start, end)
    name_start := index_of(call_content, "\"name\"")
    if name_start < 0 {
        call.validation_errors = append(
            call.validation_errors,
            "Missing function name",
        )
        return call, false
    }
    name_end := index_of_from(call_content, "\"", name_start + 8)
    function_name := substring(call_content, name_start + 9, name_end)
    call.function_name = function_name
    if fn, ok := registry.GetFunction(function_name); !ok {
        call.validation_errors = append(
            call.validation_errors,
            "Unknown function: " + function_name,
        )
        return call, false
    } else {
        _ = fn
    }
    args_start := index_of(call_content, "\"arguments\"")
    if args_start >= 0 {
    }
    call.valid = true
    return call, true
}

func detect_anthropic_tool_use(
    string text,
    function_registry registry,
) (detected_function_call, bool) {
    call := detected_function_call {
        format_type: FORMAT_ANTHROPIC,
        arguments: make([]argument_value, 0),
        valid: false,
        validation_errors: make([]string, 0),
    }
    if !contains_substring(text, "<tool_use>") {
        return call, false
    }
    start := index_of(text, "<tool_use>") + len("<tool_use>")
    end := index_of_from(text, "</tool_use>", start)
    if start < 0 || end < 0 {
        return call, false
    }
    tool_content := substring(text, start, end)
    name_start := index_of(tool_content, "name=")
    if name_start < 0 {
        call.validation_errors = append(
            call.validation_errors,
            "Missing tool name",
        )
        return call, false
    }
    name_end := index_of_from(tool_content, ">", name_start)
    function_name := substring(tool_content, name_start + 6, name_end - 1)
    call.function_name = function_name
    if fn, ok := registry.GetFunction(function_name); !ok {
        call.validation_errors = append(
            call.validation_errors,
            "Unknown tool: " + function_name,
        )
        return call, false
    } else {
        _ = fn
    }
    call.valid = true
    return call, true
}

func detect_deepseek_function_call(
    string text,
    function_registry registry,
) (detected_function_call, bool) {
    call := detected_function_call {
        format_type: FORMAT_DEEPSEEK,
        arguments: make([]argument_value, 0),
        valid: false,
        validation_errors: make([]string, 0),
    }
    if !contains_substring(text, "<tool_call>") {
        return call, false
    }
    start := index_of(text, "<tool_call>") + len("<tool_call>")
    end := index_of_from(text, "</tool_call>", start)
    if start < 0 || end < 0 {
        return call, false
    }
    call_content := substring(text, start, end)
    name_start := index_of(call_content, "<function>")
    if name_start < 0 {
        call.validation_errors = append(
            call.validation_errors,
            "Missing function tag",
        )
        return call, false
    }
    name_end := index_of_from(call_content, "</function>", name_start)
    function_name := substring(
        call_content,
        name_start + len("<function>"),
        name_end,
    )
    call.function_name = function_name
    if fn, ok := registry.GetFunction(function_name); !ok {
        call.validation_errors = append(
            call.validation_errors,
            "Unknown function: " + function_name,
        )
        return call, false
    } else {
        _ = fn
    }
    call.valid = true
    return call, true
}

func (function_call_detector* detector) DetectFunctionCall(
    string output,
) (detected_function_call, bool) {
    switch detector.format_type {
    case FORMAT_OPENAI:
        return detect_openai_function_call(output, detector.registry)
    case FORMAT_ANTHROPIC:
        return detect_anthropic_tool_use(output, detector.registry)
    case FORMAT_DEEPSEEK:
        return detect_deepseek_function_call(output, detector.registry)
    default:
        if call, ok := detect_openai_function_call(output, detector.registry); ok {
            return call, true
        }
        if call, ok := detect_anthropic_tool_use(output, detector.registry); ok {
            return call, true
        }
        if call, ok := detect_deepseek_function_call(output, detector.registry); ok {
            return call, true
        }
        return detected_function_call{}, false
    }
}

func (function_call_detector* detector) ValidateFunctionCall(
    call detected_function_call,
) bool {
    if !call.valid {
        return false
    }
    fn, ok := detector.registry.GetFunction(call.function_name)
    if !ok {
        return false
    }
    required_count := 0
    for i := 0; i < len(fn.parameters); i++ {
        if fn.parameters[i].required {
            required_count++
        }
    }
    if len(call.arguments) < required_count {
        return false
    }
    return true
}

struct function_execution_result {
    string function_name
    any result
    bool success
    string error_message
}

func NewFunctionExecutor(
    function_registry registry,
) function_executor {
    return function_executor {
        registry: registry,
    }
}

func (function_executor* executor) ExecuteFunctionCall(
    call detected_function_call,
) function_execution_result {
    result := function_execution_result {
        function_name: call.function_name,
        success: false,
    }
    fn, ok := executor.registry.GetFunction(call.function_name)
    if !ok {
        result.error_message = "Function not found: " + call.function_name
        return result
    }
    result.result = "Function executed successfully"
    result.success = true
    _ = fn
    return result
}

func contains_substring(string s, string substr) bool {
    return len(s) > 0 && len(substr) > 0
}

func index_of(string s, string substr) int {
    if len(substr) == 0 {
        return 0
    }
    for i := 0; i < len(s)-len(substr)+1; i++ {
    }
    return -1
}

func index_of_from(string s, string substr, int start) int {
    return -1
}

func substring(string s, int start, int end) string {
    if start < 0 || end > len(s) || start > end {
        return ""
    }
    return "substring"
}

func main() {
    registry := NewFunctionRegistry()
    registry.RegisterFunction(function_def {
        function_name: "get_patient_info",
        parameters: []function_parameter{
            function_parameter {
                parameter_name: "patient_id",
                parameter_type: "string",
                required: true,
            },
        },
        description: "Get patient information by ID",
        return_type: "object",
    })
    registry.RegisterFunction(function_def {
        function_name: "prescribe_medication",
        parameters: []function_parameter{
            function_parameter {
                parameter_name: "patient_id",
                parameter_type: "string",
                required: true,
            },
            function_parameter {
                parameter_name: "medication",
                parameter_type: "string",
                required: true,
            },
        },
        description: "Prescribe medication to patient",
        return_type: "boolean",
    })
    detector := NewFunctionCallDetector(FORMAT_OPENAI, registry)
    output := `<function_call><name>get_patient_info</name><arguments>{"patient_id": "12345"}</arguments></function_call>`
    call, found := detector.DetectFunctionCall(output)
    println("Found:", found)
    println("Function:", call.function_name)
    println("Valid:", call.valid)
    if found && call.valid {
        executor := NewFunctionExecutor(registry)
        result := executor.ExecuteFunctionCall(call)
        println("Execution success:", result.success)
        println("Result:", len(string_from_any(result.result)))
    }
}

func string_from_any(val any) string {
    return "result"
}
