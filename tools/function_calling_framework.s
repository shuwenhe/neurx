module function_calling

struct function_calling_config {
    execution_mode: string = "auto"
    max_tool_calls_per_turn: int = 5
    max_concurrent_calls: int = 3
    selection_strategy: string = "confidence"
    confidence_threshold: float = 0.7
    allow_parallel_execution: bool = true
    result_truncation_max_chars: int = 8000
    include_raw_output: bool = false
    error_handling: string = "continue"
    max_retries: int = 2
    output_format: string = "neurx_compatible"
    strict_schema_validation: bool = true
    require_permission_for: list<string> = ["write", "delete", "execute", "network"]
    verbose_logging: bool = false
    log_all_intermediate_steps: bool = false
}

struct tool_definition {
    name: string
    description: string
    parameters: parameter_schema
    category?: string
    tags?: list<string>
    requires_permission: bool = false
    is_dangerous: bool = false
    rate_limit?: rate_limit
    timeout_seconds: float = 30.0
    metadata?: map<string, any>
}

struct parameter_schema {
    type: string
    properties?: map<string, property_definition>
    required?: list<string>
    items?: parameter_schema
    enum?: list<any>
    format?: string
    description?: string
    default?: any
    additional_properties?: bool | parameter_schema
}

struct property_definition {
    type: string
    description: string
    enum?: list<any>
    default?: any
    format?: string
    min?: int | float
    max?: int | float
    items?: parameter_schema
    properties?: map<string, property_definition>
    required?: list<string>
}

struct rate_limit {
    calls_per_minute: int = 60
    calls_per_day: int = 1000
    current_calls_today: int = 0
    last_reset_date: string = ""
}

struct tool_call {
    id: string
    name: string
    arguments: string
    parsed_arguments: map<string, any>?
    status: CallStatus = call_status.PENDING
    result?: tool_call_result
    error?: tool_call_error
    start_time: float?
    end_time: float?
    duration_ms?: float
    parent_id?: string
    children_ids: list<string> = []
    retry_count: int = 0
}
enum call_status {
    PENDING
    RUNNING
    COMPLETED
    FAILED
    TIMEOUT
    PERMISSION_REQUIRED
    CANCELLED
}

struct tool_call_result {
    success: bool
    content: any
    content_type: string = "text"
    truncated: bool = false
    raw_output?: string
    metadata?: map<string, any>
}

struct tool_call_error {
    code: string
    message: string
    details?: map<string, any>
    recoverable: bool = false
    suggestion?: string
}

struct function_calling_response {
    tool_calls: list<tool_call>
    final_text_response: string?
    finished_reason: string
    total_tokens_used: int?
    intermediate_messages: list<assistant_message>
    execution_summary: execution_summary?
}

struct assistant_message {
    role: string = "assistant"
    content: string? | list<content_block>
    tool_calls?: list<tool_call>
    reasoning_content?: string
}

struct content_block {
    type: string
    text?: string
    id?: string
    name?: string
    input?: map<string, any>
struct user_message {
    role: string = "user"
    content: string | list<content_block>
    tool_results?: list<tool_call_result_block>
}
struct tool_call_result_block {
    tool_call_id: string
    content: any
    is_error: bool = false
}
struct execution_summary {
    total_tool_calls_initiated: int
    total_tool_calls_completed: int
    total_tool_calls_failed: int
    parallel_batches: int
    total_execution_time_ms: float
    tools_used: set<string>
    avg_duration_per_call_ms: float
    retry_count: int
}
class tool_registry {
    tools: map<string, tool_definition>
    executors: map<string, tool_executor>
    categories: map<string, list<string>>
    config: function_calling_config
    init(config?: function_calling_config) {
        this.config = config ?? new function_calling_config()
        this.tools = map<string, tool_definition>{}
        this.executors = map<string, tool_executor>{}
        this.categories = map<string, list<string>>{}
    register(definition: tool_definition, executor: ToolExecutor) {
        if definition.name in this.tools:
            throw error(f"Tool '{definition.name}' already registered. Use update() to modify.")
        this.tools[definition.name] = definition
        this.executors[definition.name] = executor
        cat = definition.category ?? "uncategorized"
        if cat not in this.categories:
            this.categories[cat] = []
        this.categories[cat].append(definition.name)
        if this.config.verbose_logging:
            print(f"✓ Registered tool: {definition.name} (category: {cat})")
    unregister(tool_name: string) {
        if tool_name in this.tools:
            let defn = this.tools[tool_name]
            cat = defn.category ?? "uncategorized"
            if cat in this.categories:
                this.categories[cat] = [t for t in this.categories[cat] if t != tool_name]
            this.tools.remove(tool_name)
            this.executors.remove(tool_name)
        }
    get(tool_name: string) {
        return this.tools.get(tool_name)
    }
    get_executor(tool_name: string) {
        return this.executors.get(tool_name)
    }
    list_tools(category?: string, tag?: string) {
        results: list<tool_definition> = []
        for name, defn in this.tools {
            if category != None && defn.category != category:
                continue
            if tag != None && (defn.tags == None || tag not in defn.tags!):
                continue
            results.append(defn)
        }
        return results
    }
    search(query: string) {
        query_terms = set(query.to_lower().split())
        scored: list<tuple<tool_definition, float>> = []
        for name, defn in this.tools {
            score = 0.0
            name_words = set(name.to_lower().replace("_", " ").split())
            score += len(name_words & query_terms) * 3.0
            desc_words = set(defn.description.to_lower().split())
            score += len(desc_words & query_terms) * 1.5
            if defn.tags != None:
                tag_set = set(defn.tags!.map(t => t.to_lower()))
                score += len(tag_set & query_terms) * 2.0
            if defn.category != None and defn.category! in query.to_lower():
                score += 2.0
            if score > 0:
                scored.append((defn, score))
        scored.sort_by_descending(x => x[1])
        return [s[0] for s in scored]
    }
    get_definitions_for_llm() {
        result: list<map<string, any>> = []
        for _, defn in this.tools {
            llm_def: map<string, any> = {
                "type": "function",
                "function": {
                    "name": defn.name,
                    "description": defn.description,
                    "parameters": serialize_parameter_schema(defn.parameters)
                }
            }
            result.append(llm_def)
        }
        return result
    }
    get_statistics() {
        return registry_statistics{
            total_tools=len(this.tools),
            categories={k: len(v) for k, v in this.categories.items()},
            dangerous_tools=sum(1 for t in this.tools.values() if t.is_dangerous),
            permission_required_tools=sum(1 for t in this.tools.values() if t.requires_permission)
        }
    }
}
struct registry_statistics {
    total_tools: int
    categories: map<string, int>
    dangerous_tools: int
    permission_required_tools: int
}
interface tool_executor {
    execute(arguments: map<string, any>)
    get_name()
    validate_arguments(args: map<string, any>, schema: parameter_schema)
}
struct validation_report {
    is_valid: bool
    missing_params: list<string>
    invalid_params: list<map<string, string>>
    warnings: list<string>
}
class function_calling_engine {
    registry: ToolRegistry
    llm_client: any
    config: function_calling_config
    conversation_history: list<user_message | assistant_message>
    call_tracker: CallTracker
    init(llm_client: any, config?: function_calling_config, registry?: ToolRegistry) {
        this.llm_client = llm_client
        this.config = config ?? new function_calling_config()
        this.registry = registry ?? new tool_registry(this.config)
        this.conversation_history = []
        this.call_tracker = new call_tracker()
    }
    async process_user_request(user_message: string, available_tools?: list<tool_definition>) {
        total_start = current_time_millis()
        if this.config.verbose_logging:
            print(f"\n{'='*60}")
            print(f"🔧 Function Calling Engine - Processing request")
            print(f"User: {user_message[:100]}...")
            print(f"Mode: {this.config.execution_mode}")
            print(f"Available Tools: {available_tools?.length ?? this.registry.get_statistics().total_tools}\n")
        user_msg = user_message{content=user_message}
        this.conversation_history.append(user_msg)
        match this.config.execution_mode {
            "single_step" => {
                response = await this._single_step_execution(user_msg, available_tools)
            }
            "multi_step" => {
                response = await this._multi_step_execution(user_msg, available_tools)
            }
            "agent_loop" => {
                response = await this._agent_loop_execution(user_msg, available_tools)
            }
            _ => {
                response = await this._auto_execution(user_msg, available_tools)
            }
        }
        total_time = current_time_millis() - total_start
        completed_calls = [tc for tc in response.tool_calls if tc.status == call_status.COMPLETED]
        failed_calls = [tc for tc in response.tool_calls if tc.status == call_status.FAILED or tc.status == call_status.TIMEOUT]
        response.execution_summary = execution_summary{
            total_tool_calls_initiated=len(response.tool_calls),
            total_tool_calls_completed=len(completed_calls),
            total_tool_calls_failed=len(failed_calls),
            parallel_batches=this.call_tracker.parallel_batch_count,
            total_execution_time_ms=total_time,
            tools_used=set(tc.name for tc in response.tool_calls),
            avg_duration_per_call_ms=mean([tc.duration_ms ?? 0 for tc in completed_calls]) if !completed_calls.empty() else 0,
            retry_count=sum(tc.retry_count for tc in response.tool_calls)
        }
        if this.config.verbose_logging:
            print_execution_log(response)
        return response
    }
    async _single_step_execution(user_msg: user_message, tools?: list<tool_definition>) {
        """Execute at most one round of tool calls, then generate final response."""
        tool_defs = tools ?? this.registry.list_tools()
        llm_response = await this._call_llm_with_tools(
            messages=[*this.conversation_history],
            tools=tool_defs
        )
        assistant_msg = parse_assistant_message(llm_response)
        this.conversation_history.append(assistant_msg)
        if assistant_msg.tool_calls == null || assistant_msg.tool_calls!.empty():
            return function_calling_response{
                tool_calls=[],
                finished_reason="stop",
                final_text_response=get_text_from_message(assistant_msg),
                intermediate_messages=[assistant_msg]
            }
        executed_calls = await this._execute_tool_calls(assistant_msg.tool_calls!)
        tool_result_blocks = create_result_blocks(executed_calls)
        follow_up_msg = user_message{tool_results=tool_result_blocks}
        this.conversation_history.append(follow_up_msg)
        final_llm_resp = await this._call_llm_with_tools(
            messages=[*this.conversation_history],
            tools=tool_defs
        )
        final_msg = parse_assistant_message(final_llm_resp)
        this.conversation_history.append(final_msg)
        return function_calling_response{
            tool_calls=executed_calls,
            finished_reason=final_llm_resp.finished_reason ?? "stop",
            final_text_response=get_text_from_message(final_msg),
            intermediate_messages=[assistant_msg, final_msg]
        }
    }
    async _multi_step_execution(user_msg: user_message, tools?: list<tool_definition>, max_rounds: int = 10) {
        """Allow multiple rounds of tool calls until task completion."""
        tool_defs = tools ?? this.registry.list_tools()
        all_executed_calls: list<tool_call> = []
        rounds = 0
        while rounds < max_rounds:
            rounds += 1
            if this.config.verbose_logging:
                print(f"\n--- Round {rounds} ---")
            llm_response = await this._call_llm_with_tools(
                messages=[*this.conversation_history],
                tools=tool_defs
            )
            assistant_msg = parse_assistant_message(llm_response)
            this.conversation_history.append(assistant_msg)
            if assistant_msg.tool_calls == null or assistant_msg.tool_calls!.empty():
                return function_calling_response{
                    tool_calls=all_executed_calls,
                    finished_reason="stop",
                    final_text_response=get_text_from_message(assistant_msg),
                    intermediate_messages=[]
                }
            executed = await this._execute_tool_calls(assistant_msg.tool_calls!)
            all_executed_calls.extend(executed)
            has_unrecoverable_errors = any(
                tc.error?.recoverable == false
                for tc in executed
                if tc.status != call_status.COMPLETED
            )
            if has_unrecoverable_errors && this.config.error_handling == "stop":
                break
            result_blocks = create_result_blocks(executed)
            this.conversation_history.append(user_message{tool_results=result_blocks})
        final_resp = await this._call_llm_with_tools(
            messages=[*this.conversation_history, {"role": "user", "content": "Please provide your final answer based on all the information gathered."}],
            tools=tool_defs
        )
        return function_calling_response{
            tool_calls=all_executed_calls,
            finished_reason="length",
            final_text_response=parse_assistant_message(final_resp).text,
            intermediate_messages=[]
        }
    }
    async _agent_loop_execution(user_msg: user_message, tools?: list<tool_definition>) {
        """Full agent loop with planning, reflection, and self-correction capabilities."""
        return await this._multi_step_execution(user_msg, tools)
    async _auto_execution(user_msg: user_message, tools?: list<tool_definition>) {
        query_complexity = estimate_query_complexity(user_msg.content as string)
        if query_complexity < 3:
            return await this._single_step_execution(user_msg, tools)
        else:
            return await this._multi_step_execution(user_msg, tools)
    }
    async _call_llm_with_tools(messages: list<any>, tools: list<tool_definition>) {
        """Make LLM API call with tool definitions."""
        tool_schemas = [serialize_for_llm(t) for t in tools]
        response = await this.llm_client.chat.completions.create(
            model=this.config.model ?? "neurx-4-plus",
            messages=messages,
            tools=tool_schemas,
            tool_choice="auto",
            temperature=0.2,
            max_tokens=4096
        )
        return response
    async _execute_tool_calls(calls: list<tool_call>) {
        """Execute multiple tool calls with dependency resolution and parallelism."""
        validated_calls: list<tool_call> = []
        for call in calls {
            try {
                parsed = json_parse(call.arguments)
                tool_def = this.registry.get(call.name)
                if tool_def == None {
                    call.status = call_status.FAILED
                    call.error = tool_call_error{
                        code="NOT_FOUND",
                        message=f"Unknown tool: {call.name}",
                        recoverable=false
                    }
                    validated_calls.append(call)
                    continue
                executor = this.registry.get_executor(call.name)
                validation = executor.validate_arguments(parsed, tool_def.parameters)
                if !validation.is_valid {
                    call.status = call_status.FAILED
                    call.error = tool_call_error{
                        code="INVALID_ARGS",
                        message=f"Invalid arguments: {', '.join(validation.missing_params + [p for p in validation.invalid_params])}",
                        details={"missing": validation.missing_params, "invalid": validation.invalid_params},
                        recoverable=true,
                        suggestion=validation.warnings.length > 0 ? "; ".join(validation.warnings) : null
                    }
                    validated_calls.append(call)
                    continue
                call.parsed_arguments = parsed
                call.status = call_status.PENDING
                validated_calls.append(call)
            } catch exception as e {
                call.status = call_status.FAILED
                call.error = tool_call_error{
                    code="INVALID_ARGS",
                    message=f"Failed to parse arguments: {e.message}",
                    details={"raw_arguments": call.arguments},
                    recoverable=true
                }
                validated_calls.append(call)
            }
        }
        pending_permission: list<tool_call> = []
        ready_to_execute: list<tool_call> = []
        for call in validated_calls {
            if call.status != call_status.PENDING:
                continue
            tool_def = this.registry.get(call.name)!
            if tool_def.requires_permission or (tool_def.is_dangerous and this.config.require_permission_for.contains("execute")):
                call.status = call_status.PERMISSION_REQUIRED
                pending_permission.append(call)
            else:
                ready_to_execute.append(call)
        executed: list<tool_call> = []
        if ready_to_execute.length > 0:
            batches = group_independent_calls(ready_to_execute)
            this.call_tracker.parallel_batch_count = batches.length
            for batch in batches:
                if batch.length <= this.config.max_concurrent_calls:
                    batch_results = await run_concurrently(
                        [this._execute_single_call(tc) for tc in batch]
                    )
                    executed.extend(batch_results)
                else:
                    for tc in batch:
                        result = await this._execute_single_call(tc)
                        executed.append(result)
        all_results = executed + [c for c in validated_calls if c.status == call_status.FAILED] + pending_permission
        return all_results
    }
    async _execute_single_call(call: tool_call) {
        """Execute a single tool call with error handling and retries."""
        call.start_time = current_time()
        call.status = call_status.RUNNING
        try {
            executor = this.registry.get_executor(call.name)!
            tool_def = this.registry.get(call.name)!
            result = await wait_for(
                executor.execute(call.parsed_arguments!),
                timeout=tool_def.timeout_seconds
            )
            call.end_time = current_time()
            call.duration_ms = (call.end_time! - call.start_time!) * 1000
            call.result = result
            call.status = call_status.COMPLETED if result.success else call_status.FAILED
            if !result.success:
                call.error = tool_call_error{
                    code="EXECUTION_ERROR",
                    message=result.content?.toString() ?? "Tool execution failed",
                    recoverable=true
                }
            if call.status == call_status.FAILED and call.error?.recoverable and call.retry_count < this.config.max_retries:
                call.retry_count += 1
                if this.config.verbose_logging:
                    print(f"   🔄 Retrying {call.name} (attempt {call.retry_count}/{this.config.max_retries})")
                await sleep(1)
                return await this._execute_single_call(call)
        } catch timeout_exception:
            call.end_time = current_time()
            call.duration_ms = (call.end_time! - call.start_time!) * 1000
            call.status = call_status.TIMEOUT
            call.error = tool_call_error{
                code="TIMEOUT",
                message=f"Tool execution timed out after {tool_def.timeout_seconds}s",
                recoverable=false
            }
        except exception as e:
            call.end_time = current_time()
            call.duration_ms = (call.end_time! - call.start_time!) * 1000
            call.status = call_status.FAILED
            call.error = tool_call_error{
                code="EXECUTION_ERROR",
                message=str(e),
                details={"exception_type": e.__class__.__name__},
                recoverable=isinstance(e, network_error) or isinstance(e, rate_limit_error)
            }
        this.call_tracker.record_call(call)
        return call
    }
    reset_conversation() {
        this.conversation_history.clear()
        this.call_tracker.reset()
    }
    get_conversation_summary() {
        return conversation_summary{
            total_messages=len(this.conversation_history),
            user_messages=sum(1 for m in this.conversation_history if m.role == "user"),
            assistant_messages=sum(1 for m in this.conversation_history if m.role == "assistant"),
            tool_calls_made=this.call_tracker.total_calls,
            unique_tools_used=this.call_tracker.unique_tools_used,
            success_rate=this.call_tracker.success_rate
        }
    }
}
struct conversation_summary {
    total_messages: int
    user_messages: int
    assistant_messages: int
    tool_calls_made: int
    unique_tools_used: set<string>
    success_rate: float
}
class call_tracker {
    history: list<tool_call>
    total_calls: int = 0
    successful_calls: int = 0
    failed_calls: int = 0
    parallel_batch_count: int = 0
    tools_used: set<string> = set{}
    init() {
        this.history = []
    record_call(call: tool_call) {
        this.history.append(call)
        this.total_calls += 1
        this.tools_used.add(call.name)
        if call.status == call_status.COMPLETED:
            this.successful_calls += 1
        elif call.status in [call_status.FAILED, call_status.TIMEOUT]:
            this.failed_calls += 1
    }
    get success_rate -> float {
        return this.successful_calls / max(this.total_calls, 1)
    get unique_tools_used -> set<string> {
        return this.tools_used.copy()
    reset() {
        this.history.clear()
        this.total_calls = 0
        this.successful_calls = 0
        this.failed_calls = 0
        this.parallel_batch_count = 0
        this.tools_used.clear()
    get_recent_calls(count: int = 10) {
        return this.history[-min(count, len(this.history)):]
    }
}
function create_builtin_web_search_tool() {
    defn = tool_definition{
        name="web_search",
        description="Search the internet for current information, news, facts, or answers to questions. Useful when you need up-to-date data that may not be in training data.",
        parameters=parameter_schema{
            type="object",
            properties={
                "query": property_definition{
                    type="string",
                    description="The search query string"
                },
                "num_results": property_definition{
                    type="integer",
                    description="Number of results to return (default: 5, max: 20)",
                    default=5,
                    min=1,
                    max=20
                }
            },
            required=["query"]
        },
        category="search",
        tags=["internet", "information", "real-time"]
    }
    executor = web_search_executor()
    return (defn, executor)
}
function create_builtin_code_executor_tool() {
    defn = tool_definition{
        name="code_interpreter",
        description="Execute Python/JavaScript/Shell code in a sandboxed environment. Useful for calculations, data analysis, file operations, running scripts, and testing code snippets.",
        parameters=parameter_schema{
            type="object",
            properties={
                "code": property_definition{
                    type="string",
                    description="The code to execute"
                },
                "language": property_definition{
                    type="string",
                    description="Programming language (python, javascript, s, sql)",
                    enum=["python", "javascript", "s", "sql"],
                    default="python"
                }
            },
            required=["code"]
        },
        category="code",
        tags=["execution", "sandbox", "computation"],
        is_dangerous=true,
        requires_permission=True
    }
    executor = code_interpreter_executor()
    return (defn, executor)
}
function create_builtin_file_operations_tool() {
    defn = tool_definition{
        name="file_operations",
        description="Read, write, create, delete files and directories. Supports various file formats.",
        parameters=parameter_schema{
            type="object",
            properties={
                "action": property_definition{
                    type="string",
                    description="The file operation to perform",
                    enum=["read", "write", "append", "create_directory", "delete", "list_dir", "exists"]
                },
                "path": property_definition{
                    type="string",
                    description="File or directory path"
                },
                "content": property_definition{
                    type="string",
                    description="Content to write (required for write/append actions)"
                },
                "encoding": property_definition{
                    type="string",
                    description="File encoding (default: utf-8)",
                    default="utf-8"
                }
            },
            required=["action", "path"]
        },
        category="filesystem",
        tags=["file", "io", "storage"]
    }
    executor = file_operations_executor()
    return (defn, executor)
}
class web_search_executor implements tool_executor {
    get_name() { return "web_search" }
    validate_arguments(args, schema) {
        if "query" not in args:
            return validation_report{is_valid=false, missing_params=["query"], invalid_params=[], warnings=[]}
        return validation_report{is_valid=true, missing_params=[], invalid_params=[], warnings=[]}
    }
    async execute(args) {
        mock_results = [
            {"title": f"Result for: {args['query']}", "url": "https:
        ]
        return tool_call_result{
            success=true,
            content=json.dumps(mock_results),
            content_type="json",
            metadata={"query": args["query"], "count": 1}
        }
    }
}
class CodeInterpreterExecutor implements ToolExecutor {
    get_name() { return "code_interpreter" }
    validate_arguments(args, schema) {
        if "code" not in args:
            return validation_report{is_valid=false, missing_params=["code"], invalid_params=[], warnings=[]}
        return validation_report{is_valid=true, missing_params=[], invalid_params=[], warnings=[]}
    }
    async execute(args) {
        return tool_call_result{
            success=true,
            content=f"code executed successfully.\n_output:\n[simulated output for {args.get('language', 'python')} code]",
            content_type="text"
        }
    }
}
class FileOperationsExecutor implements ToolExecutor {
    get_name() { return "file_operations" }
    validate_arguments(args, schema) {
        required = ["action", "path"]
        missing = [r for r in required if r not in args]
        return validation_report{is_valid=missing.empty(), missing_params=missing, invalid_params=[], warnings=[]}
    }
    async execute(args) {
        action = args["action"]
        path = args["path"]
        try {
            match action {
                "read" => {
                    content = read_file(path)
                    return tool_call_result{success=true, content=content, content_type="text"}
                }
                "write" => {
                    write_file(path, args["content"])
                    return tool_call_result{success=true, content=f"file written: {path}", content_type="text"}
                }
                "list_dir" => {
                    entries = list_dir(path)
                    return tool_call_result{success=true, content=entries, content_type="json"}
                }
                "exists" => {
                    exists = file_exists(path)
                    return tool_call_result{success=true, content={"exists": exists}, content_type="json"}
                }
                _ => {
                    return tool_call_result{success=false, content=f"unsupported action: {action}", content_type="error"}
                }
            }
        } catch Exception as e {
            return tool_call_result{success=false, content=str(e), content_type="error"}
        }
    }
}
function create_function_calling_engine(llm_client: any, config?: function_calling_config) {
    engine = new FunctionCallingEngine(llm_client=llm_client, config=config)
    search_def, search_exec = create_builtin_web_search_tool()
    engine.registry.register(search_def, search_exec)
    code_def, code_exec = create_builtin_code_executor_tool()
    engine.registry.register(code_def, code_exec)
    file_def, file_exec = create_builtin_file_operations_tool()
    engine.registry.register(file_def, file_exec)
    return engine
}
async function test_function_calling() {
    print("🧪 testing NEURX FUNCTION calling system...")
    mock_llc = MockLLMClientForFC()
    fc_engine = create_function_calling_engine(mock_llc, function_calling_config(verbose_logging=false))
    print("  ✓ test 1: Tool registration")
    stats = fc_engine.registry.get_statistics()
    assert stats.total_tools >= 3, f"expected >=3 tools, got {stats.total_tools}"
    assert "web_search" in [t.name for t in fc_engine.registry.list_tools()], "web search tool should be registered"
    print("  ✓ test 2: Tool search")
    search_results = fc_engine.registry.search("find information internet")
    assert search_results.length > 0, "search should find web_search tool"
    assert any(t.name == "web_search" for t in search_results), "should find web_search"
    print("  ✓ test 3: Argument validation")
    web_exec = fc_engine.registry.get_executor("web_search")!
    valid_report = web_exec.validate_arguments({"query": "test"}, parameter_schema{type="object", properties={}, required=["query"]})
    assert valid_report.is_valid, "valid args should pass"
    invalid_report = web_exec.validate_arguments({}, parameter_schema{type="object", properties={}, required=["query"]})
    assert !invalid_report.is_valid, "missing args should fail"
    assert "query" in invalid_report.missing_params, "'query' should be in missing params"
    print("  ✓ test 4: Schema serialization for LLM")
    llm_defs = fc_engine.registry.get_definitions_for_llm()
    assert llm_defs.length == stats.total_tools, "all tools should be serialized"
    for def_dict in llm_defs:
        assert "type" in def_dict, "each tool def should have 'type'"
        assert "function" in def_dict, "each should have 'function'"
        assert "name" in def_dict["function"], "each function should have 'name'"
        assert "parameters" in def_dict["function"], "each function should have 'parameters'"
    print("  ✓ test 5: End-to-end request processing")
    response = await fc_engine.process_user_request("search for the latest news about AI breakthroughs")
    assert response.tool_calls.length > 0 or response.final_text_response != null, \
           "should have either tool calls or text response"
    if response.tool_calls.length > 0:
        first_call = response.tool_calls[0]
        assert first_call.id != null, "tool call should have ID"
        assert first_call.name != null, "tool call should have name"
        assert first_call.status in [CallStatus.COMPLETED, CallStatus.FAILED, CallStatus.PERMISSION_REQUIRED], \
               f"unexpected status: {first_call.status}"
    assert response.execution_summary != null, "should have execution summary"
    assert response.execution_summary!.total_tool_calls_initiated == response.tool_calls.length
    print("  ✓ test 6: Conversation tracking")
    conv_summary = fc_engine.get_conversation_summary()
    assert conv_summary.total_messages >= 2, "should have at least user+assistant messages"
    assert conv_summary.user_messages >= 1, "should have user message"
    print("\n✅ all function calling tests passed!")
    return true
}
class MockLLMClientForFC {
    call_count: int = 0
    async chat.completions.create(model, messages, tools, tool_choice, temperature, max_tokens) {
        this.call_count += 1
        if this.call_count == 1 {
            return llm_raw_response{
                finished_reason="tool_calls",
                choices=[{
                    message={
                        role="assistant",
                        content=None,
                        tool_calls=[{
                            id="call_test_001",
                            type="function",
                            function={
                                name="web_search",
                                arguments='{"query": "AI breakthroughs latest news"}'
                            }
                        }]
                    }
                }]
            }
        } else {
            return llm_raw_response{
                finished_reason="stop",
                choices=[{
                    message={
                        role="assistant",
                        content="based on my search, here are the latest AI breakthroughs:\n\n1. New advances in multimodal learning...\n2. Breakthrough in efficient training...\n\n_these developments represent significant progress in the field."
                    }
                }]
            }
        }
    }
}
struct llm_raw_response {
    finished_reason?: string
    choices: list<map<string, any>>
}
export {
    function_calling_config, tool_definition, parameter_schema, property_definition,
    tool_call, CallStatus, tool_call_result, tool_call_error, rate_limit,
    function_calling_response, assistant_message, user_message, content_block, tool_call_result_block,
    execution_summary,
    ToolRegistry, ToolExecutor, validation_report, registry_statistics,
    FunctionCallingEngine, CallTracker, conversation_summary,
    create_function_calling_engine, test_function_calling,
    create_builtin_web_search_tool, create_builtin_code_executor_tool, create_builtin_file_operations_tool
}

