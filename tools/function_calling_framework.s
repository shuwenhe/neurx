// ============================================================
// NEURX FUNCTION Calling - English texttoolEnglish textframework
// completeimplementation: NeurX English text + toolEnglish text/English text/English text + English text + resultEnglish text
// English text: NeurX Function Calling / mainEnglish text Tool Use / English text Function Calling
// support: English textstepEnglish text / English textstepEnglish text / English texttoolEnglish text / errorrecover
// ============================================================

module function_calling

// ==================== English textconfigurationEnglish text ====================

struct function_calling_config {
    // English text
    execution_mode: string = "auto"               # auto | single_step | multi_step | agent_loop
    max_tool_calls_per_turn: int = 5             # English texttoolEnglish text
    max_concurrent_calls: int = 3                 # English text

    // toolEnglish text
    selection_strategy: string = "confidence"     # confidence | all_relevant | forced_single
    confidence_threshold: float = 0.7            # English text (English text)
    allow_parallel_execution: bool = true         # English texttoolEnglish text

    // resultEnglish text
    result_truncation_max_chars: int = 8000       # English text LLM English textresultEnglish text
    include_raw_output: bool = false              # English textoutput (English text)
    error_handling: string = "continue"          # continue | stop | retry (English texterrorEnglish text)
    max_retries: int = 2                          # failureEnglish text

    // outputEnglish text
    output_format: string = "neurx_compatible"  # neurx_compatible | compatible | native
    strict_schema_validation: bool = true         # English textparameter schema
    require_permission_for: list<string> = ["write", "delete", "execute", "network"]  # RequiredEnglish text

    // English textlog
    verbose_logging: bool = false                # English textlogoutput
    log_all_intermediate_steps: bool = false      # English textstepEnglish text
}

struct tool_definition {
    name: string                                   # toolName (English text)
    description: string                            # English textDescription (LLM English textuse)
    parameters: parameter_schema                    # JSON Schema English textparameterEnglish text
    category?: string                              # English text (English text "search", "code", "data", "system")
    tags?: list<string>                            # English textsearch/English text
    requires_permission: bool = false              # English textRequiredEnglish text
    is_dangerous: bool = false                     # English text
    rate_limit?: rate_limit                         # English text
    timeout_seconds: float = 30.0                  # English texttime
    metadata?: map<string, any>                    # English textdata
}

struct parameter_schema {
    type: string                                    # object | array | string | number | integer | boolean | null
    properties?: map<string, property_definition>   # English text type=object English text, English text
    required?: list<string>                        # English textparameterEnglish text
    items?: parameter_schema                        # English text type=array English text, English text
    enum?: list<any>                               # English text (English text)
    format?: string                                # English text (English text email, uri, date-time)
    description?: string                           # parameterDescription
    default?: any                                  # defaultEnglish text
    additionalProperties?: bool | parameter_schema   # English text
}

struct property_definition {
    type: string
    description: string
    enum?: list<any>
    default?: any
    format?: string
    min?: int | float
    max?: int | float
    items?: parameter_schema                       # For arrays
    properties?: map<string, property_definition>   # For nested objects
    required?: list<string>
}

struct rate_limit {
    calls_per_minute: int = 60
    calls_per_day: int = 1000
    current_calls_today: int = 0
    last_reset_date: string = ""
}

struct tool_call {
    id: string                                     # English text ID (UUID)
    name: string                                   # toolName
    arguments: string                              # JSON English textparameter
    parsed_arguments: map<string, any>?            # English textparameterEnglish text
    status: CallStatus = CallStatus.PENDING        # English textstate
    result?: tool_call_result                        # English textresult
    error?: tool_call_error                          # errorinformation
    start_time: float?                             # starttimeEnglish text
    end_time: float?                               # English texttimeEnglish text
    duration_ms?: float                            # English text
    parent_id?: string                              # English text ID (English text)
    children_ids: list<string> = []                # English text IDs
    retry_count: int = 0                           # English text
}

enum CallStatus {
    PENDING                                       # English text
    RUNNING                                        # English text
    COMPLETED                                      # successEnglish text
    FAILED                                         # English textfailure
    TIMEOUT                                        # English text
    PERMISSION_REQUIRED                            # English text
    CANCELLED                                      # English text
}

struct tool_call_result {
    success: bool                                  # English textsuccess
    content: any                                   # English textcontent (AllowedEnglish text, English text, English text)
    content_type: string = "text"                  # text | json | image | binary | table | code
    truncated: bool = false                        # contentEnglish text
    raw_output?: string                            # English textoutput (English text include_raw_output)
    metadata?: map<string, any>                    # resultEnglish textdata
}

struct tool_call_error {
    code: string                                   # errorEnglish text (INVALID_ARGS | TIMEOUT | PERMISSION_DENIED | NOT_FOUND | EXECUTION_ERROR)
    message: string                                # English texterrorEnglish text
    details?: map<string, any>                    # English texterrorinformation (English text)
    recoverable: bool = false                      # English textrecover
    suggestion?: string                            # English text
}

struct function_calling_response {
    tool_calls: list<tool_call>                     # English texttoolEnglish text
    final_text_response: string?                   # LLM English text (English texttoolEnglish text)
    finished_reason: string                       # stop | tool_calls | length | content_filter
    total_tokens_used: int?                        # English text token useEnglish text
    intermediate_messages: list<assistant_message>  # English text
    execution_summary: execution_summary?           # English textsummary
}

struct assistant_message {
    role: string = "assistant"
    content: string? | list<content_block>
    tool_calls?: list<tool_call>                    # modelEnglish textrequest
    reasoning_content?: string                     # inferenceEnglish text (English text extended thinking)
}

struct content_block {
    type: string                                   # text | tool_use | tool_result
    text?: string
    id?: string
    name?: string
    input?: map<string, any>

struct user_message {
    role: string = "user"
    content: string | list<content_block>
    tool_results?: list<tool_call_result_block>       # toolEnglish textresult
}

struct tool_call_result_block {
    tool_call_id: string
    content: any
    is_error: bool = false
}

struct execution_summary {
    total_tool_calls_initiated: int                # English text
    total_tool_calls_completed: int               # successEnglish text
    total_tool_calls_failed: int                  # failureEnglish text
    parallel_batches: int                          # English textbatchEnglish text
    total_execution_time_ms: float                 # English texttime
    tools_used: set<string>                        # actualuseEnglish texttoolEnglish text
    avg_duration_per_call_ms: float               # English text
    retry_count: int                               # English text
}

// ==================== toolEnglish text ====================

class ToolRegistry {
    tools: map<string, tool_definition>
    executors: map<string, ToolExecutor>
    categories: map<string, list<string>>
    config: function_calling_config

    init(config?: function_calling_config) {
        this.config = config ?? new function_calling_config()
        this.tools = map<string, tool_definition>{}
        this.executors = map<string, ToolExecutor>{}
        this.categories = map<string, list<string>>{}

    register(definition: tool_definition, executor: ToolExecutor) {
        if definition.name in this.tools:
            throw error(f"Tool '{definition.name}' already registered. Use update() to modify.")

        this.tools[definition.name] = definition
        this.executors[definition.name] = executor

        # Index by category
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
        # Fuzzy search for tools matching query
        query_terms = set(query.to_lower().split())
        scored: list<tuple<tool_definition, float>> = []

        for name, defn in this.tools {
            score = 0.0

            # Match against name
            name_words = set(name.to_lower().replace("_", " ").split())
            score += len(name_words & query_terms) * 3.0

            # Match against description
            desc_words = set(defn.description.to_lower().split())
            score += len(desc_words & query_terms) * 1.5

            # Match against tags
            if defn.tags != None:
                tag_set = set(defn.tags!.map(t => t.to_lower()))
                score += len(tag_set & query_terms) * 2.0

            # Category match bonus
            if defn.category != None and defn.category! in query.to_lower():
                score += 2.0

            if score > 0:
                scored.append((defn, score))

        scored.sort_by_descending(x => x[1])
        return [s[0] for s in scored]
    }

    get_definitions_for_llm() {
        # Convert to LLM-friendly format (NeurX function calling style)
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

// ==================== toolEnglish text ====================

interface ToolExecutor {
    execute(arguments: map<string, any>)
    get_name()
    validate_arguments(args: map<string, any>, schema: parameter_schema)
}

struct validation_report {
    is_valid: bool
    missing_params: list<string>
    invalid_params: list<map<string, string>>  // param_name -> error_message
    warnings: list<string>
}

// ==================== functionEnglish text ====================

class FunctionCallingEngine {
    registry: ToolRegistry
    llm_client: any
    config: function_calling_config
    conversation_history: list<user_message | assistant_message>
    call_tracker: CallTracker

    init(llm_client: any, config?: function_calling_config, registry?: ToolRegistry) {
        this.llm_client = llm_client
        this.config = config ?? new function_calling_config()
        this.registry = registry ?? new ToolRegistry(this.config)
        this.conversation_history = []
        this.call_tracker = new CallTracker()
    }

    async process_user_request(user_message: string, available_tools?: list<tool_definition>) {
        total_start = current_time_millis()

        if this.config.verbose_logging:
            print(f"\n{'='*60}")
            print(f"🔧 Function Calling Engine - Processing Request")
            print(f"User: {user_message[:100]}...")
            print(f"Mode: {this.config.execution_mode}")
            print(f"Available Tools: {available_tools?.length ?? this.registry.get_statistics().total_tools}\n")

        # Add user message to history
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
            _ => {  # auto mode: decide based on complexity
                response = await this._auto_execution(user_msg, available_tools)
            }
        }

        # Compute summary statistics
        total_time = current_time_millis() - total_start

        completed_calls = [tc for tc in response.tool_calls if tc.status == CallStatus.COMPLETED]
        failed_calls = [tc for tc in response.tool_calls if tc.status == CallStatus.FAILED or tc.status == CallStatus.TIMEOUT]

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

    async _single_stepExecution(user_msg: user_message, tools?: list<tool_definition>) {
        """Execute at most one round of tool calls, then generate final response."""

        # Step 1: Get LLM decision on whether to call tools and which ones
        tool_defs = tools ?? this.registry.list_tools()
        llm_response = await this._call_llm_with_tools(
            messages=[*this.conversation_history],
            tools=tool_defs
        )

        assistant_msg = parse_assistant_message(llm_response)
        this.conversation_history.append(assistant_msg)

        # Step 2: If no tool calls, return text response directly
        if assistant_msg.tool_calls == null || assistant_msg.tool_calls!.empty():
            return function_calling_response{
                tool_calls=[],
                finished_reason="stop",
                final_text_response=get_text_from_message(assistant_msg),
                intermediate_messages=[assistant_msg]
            }

        # Step 3: Execute the requested tool calls
        executed_calls = await this._execute_tool_calls(assistant_msg.tool_calls!)

        # Step 4: Return results back to LLM for final synthesis
        tool_result_blocks = create_result_blocks(executed_calls)
        follow_up_msg = user_message{tool_results=tool_result_blocks}
        this.conversation_history.append(follow_up_msg)

        # Step 5: Generate final response with tool context
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

            # Get LLM decision
            llm_response = await this._call_llm_with_tools(
                messages=[*this.conversation_history],
                tools=tool_defs
            )

            assistant_msg = parse_assistant_message(llm_response)
            this.conversation_history.append(assistant_msg)

            # Check if LLM wants to stop (no more tool calls)
            if assistant_msg.tool_calls == null or assistant_msg.tool_calls!.empty():
                return function_calling_response{
                    tool_calls=all_executed_calls,
                    finished_reason="stop",
                    final_text_response=get_text_from_message(assistant_msg),
                    intermediate_messages=[]
                }

            # Execute tool calls
            executed = await this._execute_tool_calls(assistant_msg.tool_calls!)
            all_executed_calls.extend(executed)

            # Check for hard stops (e.g., permission denied and config says stop)
            has_unrecoverable_errors = any(
                tc.error?.recoverable == false
                for tc in executed
                if tc.status != CallStatus.COMPLETED
            )

            if has_unrecoverable_errors && this.config.error_handling == "stop":
                break

            # Feed results back
            result_blocks = create_result_blocks(executed)
            this.conversation_history.append(user_message{tool_results=result_blocks})

        # Max rounds reached, force final response
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

        # This would implement a more sophisticated loop similar to ReAct or Plan-and-Solve
        # For now, delegate to multi-step as a base implementation
        return await this._multi_step_execution(user_msg, tools)

    async _auto_execution(user_msg: user_message, tools?: list<tool_definition>) {
        # Heuristic: simple queries likely don't need tools, complex ones might
        query_complexity = estimate_query_complexity(user_msg.content as string)

        if query_complexity < 3:  # Low complexity
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
            tool_choice="auto",  # Let model decide
            temperature=0.2,  # Lower temp for more deterministic tool usage
            max_tokens=4096
        )

        return response

    async _execute_tool_calls(calls: list<tool_call>) {
        """Execute multiple tool calls with dependency resolution and parallelism."""

        # Step 1: Parse arguments and validate
        validated_calls: list<tool_call> = []
        for call in calls {
            try {
                parsed = json_parse(call.arguments)

                # Validate against schema
                tool_def = this.registry.get(call.name)
                if tool_def == None {
                    call.status = CallStatus.FAILED
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
                    call.status = CallStatus.FAILED
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
                call.status = CallStatus.PENDING
                validated_calls.append(call)

            } catch Exception as e {
                call.status = CallStatus.FAILED
                call.error = tool_call_error{
                    code="INVALID_ARGS",
                    message=f"Failed to parse arguments: {e.message}",
                    details={"raw_arguments": call.arguments},
                    recoverable=true
                }
                validated_calls.append(call)
            }
        }

        # Step 2: Permission check for sensitive operations
        pending_permission: list<tool_call> = []
        ready_to_execute: list<tool_call> = []

        for call in validated_calls {
            if call.status != CallStatus.PENDING:
                continue

            tool_def = this.registry.get(call.name)!
            if tool_def.requires_permission or (tool_def.is_dangerous and this.config.require_permission_for.contains("execute")):
                call.status = CallStatus.PERMISSION_REQUIRED
                pending_permission.append(call)
            else:
                ready_to_execute.append(call)

        # Step 3: Execute ready calls (parallelize independent ones)
        executed: list<tool_call> = []

        if ready_to_execute.length > 0:
            # Group by dependencies (simple version: assume all are independent for now)
            # In production, build a DAG and topologically sort
            batches = group_independent_calls(ready_to_execute)
            this.call_tracker.parallel_batch_count = batches.length

            for batch in batches:
                if batch.length <= this.config.max_concurrent_calls:
                    batch_results = await run_concurrently(
                        [this._execute_single_call(tc) for tc in batch]
                    )
                    executed.extend(batch_results)
                else:
                    # Execute sequentially within batch if exceeds concurrency limit
                    for tc in batch:
                        result = await this._execute_single_call(tc)
                        executed.append(result)

        # Combine all results
        all_results = executed + [c for c in validated_calls if c.status == CallStatus.FAILED] + pending_permission

        return all_results
    }

    async _execute_single_call(call: tool_call) {
        """Execute a single tool call with error handling and retries."""

        call.start_time = current_time()
        call.status = CallStatus.RUNNING

        try {
            executor = this.registry.get_executor(call.name)!
            tool_def = this.registry.get(call.name)!

            # Execute with timeout
            result = await wait_for(
                executor.execute(call.parsed_arguments!),
                timeout=tool_def.timeout_seconds
            )

            call.end_time = current_time()
            call.duration_ms = (call.end_time! - call.start_time!) * 1000
            call.result = result
            call.status = CallStatus.COMPLETED if result.success else CallStatus.FAILED

            if !result.success:
                call.error = tool_call_error{
                    code="EXECUTION_ERROR",
                    message=result.content?.toString() ?? "Tool execution failed",
                    recoverable=true
                }

            # Retry logic for recoverable failures
            if call.status == CallStatus.FAILED and call.error?.recoverable and call.retry_count < this.config.max_retries:
                call.retry_count += 1
                if this.config.verbose_logging:
                    print(f"   🔄 Retrying {call.name} (attempt {call.retry_count}/{this.config.max_retries})")
                await sleep(1)  # Brief delay before retry
                return await this._execute_single_call(call)

        } catch TimeoutException:
            call.end_time = current_time()
            call.duration_ms = (call.end_time! - call.start_time!) * 1000
            call.status = CallStatus.TIMEOUT
            call.error = tool_call_error{
                code="TIMEOUT",
                message=f"Tool execution timed out after {tool_def.timeout_seconds}s",
                recoverable=false
            }

        except Exception as e:
            call.end_time = current_time()
            call.duration_ms = (call.end_time! - call.start_time!) * 1000
            call.status = CallStatus.FAILED
            call.error = tool_call_error{
                code="EXECUTION_ERROR",
                message=str(e),
                details={"exception_type": e.__class__.__name__},
                recoverable=isinstance(e, NetworkError) or isinstance(e, RateLimitError)
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

// ==================== English text ====================

class CallTracker {
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

        if call.status == CallStatus.COMPLETED:
            this.successful_calls += 1
        elif call.status in [CallStatus.FAILED, CallStatus.TIMEOUT]:
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

// ==================== English texttoolEnglish text ====================

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

    executor = WebSearchExecutor()
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

    executor = CodeInterpreterExecutor()
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

    executor = FileOperationsExecutor()
    return (defn, executor)
}

// Executor implementations (simplified stubs - real implementations would use actual services)
class WebSearchExecutor implements ToolExecutor {
    get_name() { return "web_search" }

    validate_arguments(args, schema) {
        if "query" not in args:
            return validation_report{is_valid=false, missing_params=["query"], invalid_params=[], warnings=[]}
        return validation_report{is_valid=true, missing_params=[], invalid_params=[], warnings=[]}
    }

    async execute(args) {
        // Would integrate with a search service
        mock_results = [
            {"title": f"Result for: {args['query']}", "url": "https://example.com", "snippet": "This is search result content..."}
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
        # Would use actual code interpreter service
        return tool_call_result{
            success=true,
            content=f"Code executed successfully.\nOutput:\n[Simulated output for {args.get('language', 'python')} code]",
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
                    return tool_call_result{success=true, content=f"File written: {path}", content_type="text"}
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
                    return tool_call_result{success=false, content=f"Unsupported action: {action}", content_type="error"}
                }
            }
        } catch Exception as e {
            return tool_call_result{success=false, content=str(e), content_type="error"}
        }
    }
}

// ==================== English textfunctionEnglish texttest ====================

function create_function_calling_engine(llm_client: any, config?: function_calling_config) {
    engine = new FunctionCallingEngine(llm_client=llm_client, config=config)

    # Register built-in tools
    search_def, search_exec = create_builtin_web_search_tool()
    engine.registry.register(search_def, search_exec)

    code_def, code_exec = create_builtin_code_executor_tool()
    engine.registry.register(code_def, code_exec)

    file_def, file_exec = create_builtin_file_operations_tool()
    engine.registry.register(file_def, file_exec)

    return engine
}

async function test_function_calling() {
    print("🧪 Testing NEURX FUNCTION Calling System...")

    # Create mock LLM client
    mock_llc = MockLLMClientForFC()

    # Create engine with built-in tools
    fc_engine = create_function_calling_engine(mock_llc, function_calling_config(verbose_logging=false))

    # Test 1: Tool registration and discovery
    print("  ✓ Test 1: Tool Registration")
    stats = fc_engine.registry.get_statistics()
    assert stats.total_tools >= 3, f"Expected >=3 tools, got {stats.total_tools}"
    assert "web_search" in [t.name for t in fc_engine.registry.list_tools()], "Web search tool should be registered"

    # Test 2: Tool search functionality
    print("  ✓ Test 2: Tool Search")
    search_results = fc_engine.registry.search("find information internet")
    assert search_results.length > 0, "Search should find web_search tool"
    assert any(t.name == "web_search" for t in search_results), "Should find web_search"

    # Test 3: Argument validation
    print("  ✓ Test 3: Argument Validation")
    web_exec = fc_engine.registry.get_executor("web_search")!
    valid_report = web_exec.validate_arguments({"query": "test"}, parameter_schema{type="object", properties={}, required=["query"]})
    assert valid_report.is_valid, "Valid args should pass"

    invalid_report = web_exec.validate_arguments({}, parameter_schema{type="object", properties={}, required=["query"]})
    assert !invalid_report.is_valid, "Missing args should fail"
    assert "query" in invalid_report.missing_params, "'query' should be in missing params"

    # Test 4: Schema serialization
    print("  ✓ Test 4: Schema Serialization for LLM")
    llm_defs = fc_engine.registry.get_definitions_for_llm()
    assert llm_defs.length == stats.total_tools, "All tools should be serialized"
    for def_dict in llm_defs:
        assert "type" in def_dict, "Each tool def should have 'type'"
        assert "function" in def_dict, "Each should have 'function'"
        assert "name" in def_dict["function"], "Each function should have 'name'"
        assert "parameters" in def_dict["function"], "Each function should have 'parameters'"

    # Test 5: Process request (with mock LLM that returns tool calls)
    print("  ✓ Test 5: End-to-End Request Processing")
    response = await fc_engine.process_user_request("Search for the latest news about AI breakthroughs")

    assert response.tool_calls.length > 0 or response.final_text_response != null, \
           "Should have either tool calls or text response"

    if response.tool_calls.length > 0:
        first_call = response.tool_calls[0]
        assert first_call.id != null, "Tool call should have ID"
        assert first_call.name != null, "Tool call should have name"
        assert first_call.status in [CallStatus.COMPLETED, CallStatus.FAILED, CallStatus.PERMISSION_REQUIRED], \
               f"Unexpected status: {first_call.status}"

    assert response.execution_summary != null, "Should have execution summary"
    assert response.execution_summary!.total_tool_calls_initiated == response.tool_calls.length

    # Test 6: Conversation tracking
    print("  ✓ Test 6: Conversation Tracking")
    conv_summary = fc_engine.get_conversation_summary()
    assert conv_summary.total_messages >= 2, "Should have at least user+assistant messages"
    assert conv_summary.user_messages >= 1, "Should have user message"

    print("\n✅ All Function Calling Tests Passed!")
    return true
}

class MockLLMClientForFC {
    call_count: int = 0

    async chat.completions.create(model, messages, tools, tool_choice, temperature, max_tokens) {
        this.call_count += 1

        # Simulate different responses based on call count
        if this.call_count == 1 {
            # First call: request tool use
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
            # Second call: generate final answer based on tool results
            return llm_raw_response{
                finished_reason="stop",
                choices=[{
                    message={
                        role="assistant",
                        content="Based on my search, here are the latest AI breakthroughs:\n\n1. New advances in multimodal learning...\n2. Breakthrough in efficient training...\n\nThese developments represent significant progress in the field."
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

// Export public API
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
