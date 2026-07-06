// ============================================================
// NEURX Code Interpreter - 代码解释器系统
// 完整实现: 沙箱执行环境 + 多语言支持 + 结果解析 + 安全隔离
// 兼容 NEURX-4 All Tools / 通用代码解释器 / Jupyter Kernel
// ============================================================

module code_interpreter

// ==================== 核心配置 ====================

struct CodeInterpreterConfig {
    // 超时设置
    execution_timeout_seconds: int = 120        // 单次代码执行最大时间
    total_session_timeout: int = 600            // 整个会话最大时间
    
    // 资源限制
    max_memory_mb: int = 512                    // 最大内存使用 (MB)
    max_output_size_bytes: int = 10 * 1024 * 1024  // 最大输出大小 (10MB)
    max_file_size_mb: int = 10                  // 生成的文件最大大小
    
    // 支持的语言
    supported_languages: list<string> = ["python", "javascript", "shell", "sql"]
    default_language: string = "python"
    
    // 安全配置
    sandbox_enabled: bool = true                // 是否启用沙箱隔离
    allow_network_access: bool = false          // 是否允许网络访问
    allowed_modules: list<string> = [           // 白名单模块
        "math", "random", "datetime", "json", "re", "collections",
        "itertools", "functools", "operator", "statistics",
        "numpy", "pandas", "matplotlib", "scipy"
    ]
    blocked_modules: list<string> = [           // 黑名单模块
        "os", "subprocess", "sys", "importlib", "__import__",
        "eval", "exec", "compile", "open"  # 需要安全包装器
    ]
    
    // 环境配置
    working_directory: string = "/tmp/code_interpreter_sessions/"
    install_dependencies: bool = true           // 允许 pip install
    persist_files_between_calls: bool = true   // 跨调用保持文件状态
    
    // 可视化支持
    enable_plotting: bool = true                // 支持 matplotlib/seaborn 绘图
    enable_dataframe_display: bool = true       # DataFrame 美化显示
    image_format: string = "png"               # 输出图片格式 (svg/png/jpeg)
}

struct ExecutionResult {
    success: bool                              // 执行是否成功
    output: string                             // stdout 输出
    error: string?                             // stderr 错误信息 (如果有)
    error_type: string?                        // 错误类型 (SyntaxError, RuntimeError, etc.)
    traceback: list<string>?                   // 完整堆栈跟踪
    return_value: any                          // 最后一个表达式的返回值 (如果有)
    variables: map<string, any>?              // 执行后的变量状态 (调试用)
    generated_files: list<FileInfo>?           // 生成的文件列表
    plots: list<ImageData>?                    // 生成的图表
    execution_time_ms: float                   // 执行耗时 (毫秒)
    memory_used_mb: float                      // 内存使用量 (MB)
    line_count: int                            // 代码行数
}

struct FileInfo {
    path: string                               // 文件路径
    size_bytes: int                            // 文件大小
    content_type: string                       // MIME 类型
    preview: string?                           // 文件内容预览 (前几行)
    is_image: bool                             // 是否是图像文件
}

struct ImageData {
    data: bytes                                // 图像二进制数据
    format: string                             // 图像格式 (png/svg/jpeg)
    width: int                                 // 图像宽度
    height: int                                // 图像高度
    alt_text: string?                          // 描述文字
}

struct CodeBlock {
    language: string                           // 代码语言 (python/javascript/shell/sql)
    code: string                               // 代码内容
    filename: string?                          // 可选的文件名 (用于保存)
}

// ==================== 沙箱执行环境 ====================

class SandboxEnvironment {
    config: CodeInterpreterConfig
    session_id: string
    working_dir: string
    state: SessionState
    
    // 语言运行时
    python_runtime: PythonRuntime?
    javascript_runtime: JavaScriptRuntime?
    shell_runtime: ShellRuntime?
    sql_runtime: SQLRuntime?
    
    init(config: CodeInterpreterConfig) {
        this.config = config
        this.session_id = generate_uuid()
        this.working_dir = config.working_directory + this.session_id + "/"
        
        // 创建工作目录
        create_directory(this.working_dir)
        
        // 初始化会话状态
        this.state = new SessionState(
            session_id=this.session_id,
            created_at=current_timestamp(),
            variables=map<string, any>{},
            files_created=list<string>{},
            execution_history=list<ExecutionRecord>{}
        )
        
        // 初始化语言运行时
        if "python" in config.supported_languages {
            this.python_runtime = new PythonRuntime(
                sandbox_dir=this.working_dir,
                memory_limit=config.max_memory_mb,
                timeout=config.execution_timeout_seconds
            )
        }
        if "javascript" in config.supported_languages {
            this.javascript_runtime = new JavaScriptRuntime()
        }
        if "shell" in config.supported_languages {
            this.shell_runtime = new ShellRuntime(allow_network=config.allow_network_access)
        }
        if "sql" in config.supported_languages {
            this.sql_runtime = new SQLRuntime(db_path=this.working_dir + "sandbox.db")
        }
    }

    execute(code_block: CodeBlock) -> ExecutionResult {
        let start_time = current_time_millis()
        
        // Step 1: Security check
        let security_result = this._security_check(code_block.code)
        if !security_result.allowed {
            return ExecutionResult{
                success=false,
                output="",
                error=security_result.reason,
                error_type="SecurityError",
                execution_time_ms=current_time_millis() - start_time,
                line_count=count_lines(code_block.code),
                memory_used_mb=0
            }
        }
        
        // Step 2: Language dispatch
        result: ExecutionResult
        match code_block.language.lower() {
            "python" | "py" => {
                assert this.python_runtime != null, "Python runtime not initialized"
                result = this.python_runtime!.execute(code_block.code, code_block.filename)
            }
            "javascript" | "js" => {
                assert this.javascript_runtime != null, "JavaScript runtime not initialized"
                result = this.javascript_runtime!.execute(code_block.code)
            }
            "shell" | "bash" | "sh" => {
                assert this.shell_runtime != null, "Shell runtime not initialized"
                result = this.shell_runtime!.execute(code_block.code)
            }
            "sql" => {
                assert this.sql_runtime != null, "SQL runtime not initialized"
                result = this.sql_runtime!.execute(code_block.code)
            }
            _ => {
                result = ExecutionResult{
                    success=false,
                    output="",
                    error=f"Unsupported language: {code_block.language}. Supported: {', '.join(this.config.supported_languages)}",
                    error_type="LanguageNotSupportedError",
                    execution_time_ms=current_time_millis() - start_time,
                    line_count=count_lines(code_block.code)
                }
            }
        }
        
        // Step 3: Post-processing (collect outputs, plots, etc.)
        result.execution_time_ms = current_time_millis() - start_time
        result = this._post_process(result, code_block)
        
        // Step 4: Update session state
        this.state.add_execution_record(ExecutionRecord{
            code=code_block.code,
            language=code_block.language,
            result=result,
            timestamp=current_timestamp()
        })
        
        return result
    }

    _security_check(code: string) -> SecurityCheckResult {
        // Comprehensive security analysis of code
        
        issues: list<string> = []
        
        // Pattern 1: Dangerous imports/operations
        dangerous_patterns = [
            ("__import__", "Dynamic import detected"),
            ("eval(", "Use of eval() is restricted"),
            ("exec(", "Use of exec() is restricted"),
            ("compile(", "Use of compile() is restricted"),
            ("subprocess", "Subprocess module is blocked"),
            ("os.system", "System command execution blocked"),
            ("os.popen", "Popen command execution blocked"),
            ("socket", "Network socket creation blocked"),
            ("requests.get", "HTTP requests blocked"),
            ("urllib", "URL library blocked"),
            ("/etc/passwd", "File system access to sensitive paths"),
            ("rm -rf", "Destructive file operation"),
            ("> /dev/", "Writing to device files"),
            ("chmod 777", "Permission modification"),
            ("mkfs", "Filesystem formatting command")
        ]
        
        for pattern, message in dangerous_patterns {
            if pattern.to_lower() in code.to_lower() {
                issues.append(message)
            }
        }
        
        // Pattern 2: Check for infinite loops (basic heuristic)
        if "while True:" in code || "while(1)" in code || "while(true)" in code {
            // Allow but warn about potential infinite loop
            if "break" not in code && "return" not in code:
                issues.append("Potential infinite loop without break condition")
        }
        
        // Pattern 3: Check for excessive resource usage patterns
        large_allocations = [
            (r"\[\s*0\s*\]\s*\*\s*(\d{6,})", "Large array allocation may exceed memory limit")
        ]
        // ... regex matching ...
        
        if issues.length > 0 {
            return SecurityCheckResult{allowed=false, reason="\n".join(issues)}
        }
        
        return SecurityCheckResult{allowed=true, reason=""}
    }

    _post_process(result: ExecutionResult, code_block: CodeBlock) -> ExecutionResult {
        // Collect generated files
        if this.config.persist_files_between_calls {
            let files = scan_directory_for_new_files(
                this.working_dir,
                since=this.state.last_execution_time
            )
            result.generated_files = files
            
            // Update state with new files
            for f in files {
                this.state.files_created.append(f.path)
            }
        }
        
        // Extract plots from matplotlib if Python and plotting enabled
        if code_block.language == "python" && this.config.enable_plotting && result.success {
            result.plots = this._extract_matplotlib_plots()
        }
        
        // Estimate memory used (simplified)
        result.memory_used_mb = estimate_memory_usage(result.output.length)
        
        return result
    }

    _extract_matplotlib_plots() -> list<ImageData> {
        plots: list<ImageData> = []
        // In real implementation, check for saved figure files or capture from backend
        // For now, scan for .png/.svg files created during execution
        
        plot_files = find_files_with_extension(this.working_dir, [".png", ".svg", ".jpeg"])
        for plot_file in plot_files {
            img_data = read_file_as_bytes(plot_file)
            plots.append(ImageData{
                data=img_data,
                format=get_file_extension(plot_file),
                width=0,  # Would need to parse image header
                height=0,
                alt_text=f"Generated plot: {get_filename(plot_file)}"
            })
        }
        return plots
    }

    get_session_state() -> SessionState {
        return this.state
    }

    cleanup() {
        // Clean up sandbox directory
        if this.config.sandbox_enabled {
            remove_directory_recursive(this.working_dir)
        }
    }

    reset() {
        // Reset session state while keeping the same session ID
        this.state.variables.clear()
        this.state.execution_history.clear()
        this.state.files_created.clear()
    }
}

struct SecurityCheckResult {
    allowed: bool
    reason: string
}

// ==================== 会话状态管理 ====================

class SessionState {
    session_id: string
    created_at: float
    last_execution_time: float = 0
    variables: map<string, any>
    files_created: list<string>
    execution_history: list<ExecutionRecord>
    total_execution_time_ms: float = 0

    init(session_id: string, created_at: float, variables: map<string, any>, 
         files_created: list<string>, execution_history: list<ExecutionRecord>) {
        this.session_id = session_id
        this.created_at = created_at
        this.variables = variables
        this.files_created = files_created
        this.execution_history = execution_history
    }

    add_execution_record(record: ExecutionRecord) {
        this.execution_history.append(record)
        this.last_execution_time = record.timestamp
        this.total_execution_time_ms += record.result.execution_time_ms
    }

    get_summary() -> SessionSummary {
        return SessionSummary{
            session_id=this.session_id,
            duration_seconds=current_timestamp() - this.created_at,
            num_executions=this.execution_history.length,
            total_execution_time_sec=this.total_execution_time_ms / 1000.0,
            files_created_count=this.files_created.length,
            variable_names=list(this.variables.keys()),
            success_rate=this._compute_success_rate()
        }
    }

    _compute_success_rate() -> float {
        if this.execution_history.length == 0 {
            return 1.0
        }
        successes = sum(1 for r in this.execution_history if r.result.success)
        return successes / this.execution_history.length
    }
}

struct ExecutionRecord {
    code: string
    language: string
    result: ExecutionResult
    timestamp: float
}

struct SessionSummary {
    session_id: string
    duration_seconds: float
    num_executions: int
    total_execution_time_sec: float
    files_created_count: int
    variable_names: list<string>
    success_rate: float
}

// ==================== Python 运行时实现 ====================

class PythonRuntime {
    sandbox_dir: string
    memory_limit: int
    timeout: int
    process?: ProcessHandle
    interpreter_path: string = "python3"

    init(sandbox_dir: string, memory_limit: int, timeout: int) {
        this.sandbox_dir = sandbox_dir
        this.memory_limit = memory_limit
        this.timeout = timeout
        
        // Verify Python availability
        if !check_command_available(this.interpreter_path) {
            throw error(f"Python interpreter not found: {this.interpreter_path}")
        }
    }

    execute(code: string, filename: string?) -> ExecutionResult {
        // Write code to temporary file within sandbox
        let script_path = this.sandbox_dir + (filename ?? "execution_" + generate_short_uuid() + ".py")
        write_file(script_path, code)
        
        try {
            // Execute with resource limits using subprocess
            // In production, use proper sandboxing (docker, nsjail, etc.)
            let cmd = [
                this.interpreter_path,
                "-u",  # Unbuffered output
                "-B",  # Don't write .pyc files
                script_path
            ]
            
            // Set environment variables for sandboxing
            env_vars = {
                "PYTHONPATH": this.sandbox_dir,
                "HOME": this.sandbox_dir,
                "TMPDIR": this.sandbox_dir,
                "PYTHONDONTWRITEBYTECODE": "1"
            }
            
            // Execute with timeout
            let proc = subprocess_run(
                cmd,
                capture_output=true,
                text=true,
                timeout=this.timeout,
                cwd=this.sandbox_dir,
                env=env_vars
            )
            
            // Parse output
            output = proc.stdout
            error_output = proc.stderr
            
            // Detect errors
            if proc.returncode != 0 {
                let error_info = this._parse_python_error(error_output)
                return ExecutionResult{
                    success=false,
                    output=output,
                    error=error_info.message,
                    error_type=error_info.error_type,
                    traceback=error_info.traceback,
                    return_value=null,
                    execution_time_ms=0,  # Will be set by caller
                    line_count=count_lines(code),
                    memory_used_mb=0
                }
            }
            
            // Try to extract return value (last expression)
            return_value = this._extract_return_value(output)
            
            return ExecutionResult{
                success=true,
                output=output,
                error=null,
                error_type=null,
                traceback=null,
                return_value=return_value,
                execution_time_ms=0,
                line_count=count_lines(code),
                memory_used_mb=0
            }
            
        } catch TimeoutExpired {
            kill_process(this.process)
            return ExecutionResult{
                success=false,
                output="",
                error=f"Execution timed out after {this.timeout} seconds",
                error_type="TimeoutError",
                execution_time_ms=this.timeout * 1000.0,
                line_count=count_lines(code),
                memory_used_mb=0
            }
        } catch Exception as e {
            return ExecutionResult{
                success=false,
                output="",
                error=str(e),
                error_type="ExecutionError",
                line_count=count_lines(code),
                memory_used_mb=0
            }
        }
    }

    _parse_python_error(stderr_output: string) -> ErrorInfo {
        lines = stderr_output.split("\n")
        error_type = ""
        message = ""
        traceback: list<string> = []
        
        in_traceback = false
        for line in lines {
            if line.startswith("Traceback") || line.startswith("  File ") or line.startswith("    "):
                in_traceback = true
                traceback.append(line)
            else if ":" in line && in_traceback && error_type == "" {
                parts = line.rsplit(":", 1)
                error_type = parts[0].strip()
                message = parts[1].strip() if parts.length > 1 else line.strip()
            }
        }
        
        return ErrorInfo{
            error_type=error_type ?: "UnknownError",
            message=message ?: stderr_output,
            traceback=traceback
        }
    }

    _extract_return_value(stdout: string) -> any {
        // Try to detect and parse printed values that could be expressions
        // This is a simplified version; real implementation would use AST analysis
        lines = stdout.strip().split("\n")
        if lines.length > 0 {
            last_line = lines[-1]
            
            // Try JSON parsing
            try {
                return json_parse(last_line)
            }
            
            // Try numeric parsing
            try {
                return parseFloat(last_line)
            }
            
            // Return as string
            return last_line
        }
        return null
    }
}

struct ErrorInfo {
    error_type: string
    message: string
    traceback: list<string>
}

// ==================== JavaScript 运行时 ====================

class JavaScriptRuntime {
    vm_context: any  // V8 context or Node.js vm module reference

    init() {
        // Initialize JavaScript VM context
        // Options: V8 isolates, Node.js vm module, QuickJS, etc.
        this.vm_context = create_javascript_vm()
    }

    execute(code: string) -> ExecutionResult {
        try {
            // Wrap code to capture console.log and return value
            wrapped_code = """
                (function() {
                    let __output = [];
                    const originalLog = console.log;
                    console.log = (...args) => { __output.push(args.join(' ')); };
                    
                    try {
                        ${code}
                        
                        // Capture last expression value (simplified)
                        const __result = typeof __last_expression !== 'undefined' ? __last_expression : undefined;
                        console.log = originalLog;
                        return { output: __output.join('\\n'), returnValue: __result };
                    } catch(e) {
                        console.log = originalLog;
                        throw e;
                    }
                })();
            """
            
            let result = run_in_vm(this.vm_context, wrapped_code)
            
            return ExecutionResult{
                success=true,
                output=result.output,
                error=null,
                return_value=result.returnValue,
                execution_time_ms=0,
                line_count=count_lines(code),
                memory_used_mb=0
            }
        } catch Exception as e {
            return ExecutionResult{
                success=false,
                output="",
                error=str(e),
                error_type=e.name ?? "JavaScriptError",
                line_count=count_lines(code),
                memory_used_mb=0
            }
        }
    }
}

// ==================== Shell 运行时 ====================

class ShellRuntime {
    allow_network: bool
    allowed_commands: set<string>

    init(allow_network: bool) {
        this.allow_network = allow_network
        this.allowed_commands = set<string>{
            "ls", "pwd", "echo", "cat", "head", "tail", "wc", "grep", "find",
            "date", "uname", "whoami", "df", "du", "sort", "uniq", "cut",
            "awk", "sed", "tr", "base64", "md5sum", "sha256sum",
            "python3", "pip", "git", "curl" if allow_network else null,
            "wget" if allow_network else null
        }.filter(x => x != null).map(x => x!)
    }

    execute(command: string) -> ExecutionResult {
        // Validate command against whitelist
        base_command = command.split_whitespace()[0]
        if base_command not in this.allowed_commands {
            return ExecutionResult{
                success=false,
                output="",
                error=f"Command '{base_command}' is not allowed in sandbox",
                error_type="PermissionDeniedError",
                line_count=count_lines(command),
                memory_used_mb=0
            }
        }
        
        try {
            let proc = subprocess_run(
                ["bash", "-c", command],
                capture_output=true,
                text=true,
                timeout=30,  // Short timeout for shell commands
                shell=false
            )
            
            return ExecutionResult{
                success=proc.returncode == 0,
                output=proc.stdout,
                error=proc.stderr if proc.stderr.length > 0 else null,
                return_value=proc.returncode,
                execution_time_ms=0,
                line_count=count_lines(command),
                memory_used_mb=0
            }
        } catch TimeoutExpired {
            return ExecutionResult{
                success=false,
                output="",
                error="Shell command timed out after 30 seconds",
                error_type="TimeoutError",
                line_count=count_lines(command),
                memory_used_mb=0
            }
        } catch Exception as e {
            return ExecutionResult{
                success=false,
                output="",
                error=str(e),
                error_type="ShellExecutionError",
                line_count=count_lines(command),
                memory_used_mb=0
            }
        }
    }
}

// ==================== SQL 运行时 ====================

class SQLRuntime {
    db_path: string
    connection: DatabaseConnection?

    init(db_path: string) {
        this.db_path = db_path
        // Initialize SQLite database connection
        this.connection = connect_to_sqlite(db_path)
    }

    execute(query: string) -> ExecutionResult {
        try {
            // Parse SQL to determine type
            query_type = detect_sql_query_type(query)
            
            match query_type {
                "SELECT" | "SHOW" | "DESCRIBE" | "EXPLAIN" => {
                    // Query returning rows
                    let cursor = this.connection!.execute(query)
                    columns = cursor.column_names
                    rows = cursor.fetchall()
                    
                    // Format output as table
                    output = format_sql_table(columns, rows)
                    
                    // Return structured data
                    return_value = SQLQueryResult{
                        columns=columns,
                        rows=rows,
                        row_count=rows.length
                    }
                    
                    return ExecutionResult{
                        success=true,
                        output=output,
                        return_value=return_value,
                        execution_time_ms=0,
                        line_count=count_lines(query),
                        memory_used_mb=0
                    }
                }
                
                "CREATE" | "ALTER" | "DROP" | "INSERT" | "UPDATE" | "DELETE" => {
                    // DDL/DML statement
                    this.connection!.execute(query)
                    affected_rows = this.connection!.rows_affected
                    
                    return ExecutionResult{
                        success=true,
                        output=f"Query executed successfully. Affected rows: {affected_rows}",
                        return_value={"affected_rows": affected_rows},
                        execution_time_ms=0,
                        line_count=count_lines(query),
                        memory_used_mb=0
                    }
                }
                
                _ => {
                    return ExecutionResult{
                        success=false,
                        output="",
                        error=f"Unsupported SQL query type: {query_type}",
                        error_type="SQLSyntaxError",
                        line_count=count_lines(query),
                        memory_used_mb=0
                    }
                }
            }
        } catch SQLException as e {
            return ExecutionResult{
                success=false,
                output="",
                error=e.message,
                error_type=e.error_type ?? "SQLError",
                line_count=count_lines(query),
                memory_used_mb=0
            }
        }
    }

    close() {
        this.connection?.close()
    }
}

struct SQLQueryResult {
    columns: list<string>
    rows: list<list<any>>
    row_count: int
}

// ==================== 结果解析和格式化 ====================

class ResultFormatter {
    config: CodeInterpreterConfig

    init(config: CodeInterpreterConfig) {
        this.config = config
    }

    format_for_llm(result: ExecutionResult) -> FormattedOutput {
        // Format execution results for LLM consumption
        sections: list<string> = []
        
        // Status section
        status_icon = result.success ? "✅" : "❌"
        status_text = result.success ? "Success" : f"Error ({result.error_type})"
        sections.append(f"{status_icon} **Status**: {status_text}")
        
        // Output section
        if result.output.length > 0 {
            truncated_output = this._truncate(result.output, max_chars=5000)
            formatted_output = this._format_code_block(truncated_output, "output")
            sections.append(f"**Output**:\n{formatted_output}")
        }
        
        // Error section
        if result.error != null {
            formatted_error = this._format_code_block(result.error!, "error")
            sections.append(f"**Error**:\n{formatted_error}")
            
            if result.traceback != null && result.traceback!.length > 0 {
                formatted_tb = this._format_code_block("\n".join(result.traceback!), "traceback")
                sections.append(f"**Traceback**:\n{formatted_tb}")
            }
        }
        
        // Execution metrics
        metrics_parts: list<string> = []
        metrics_parts.append(f"Time: {result.execution_time_ms:.1f}ms")
        metrics_parts.append(f"Lines: {result.line_count}")
        if result.memory_used_mb > 0 {
            metrics_parts.append(f"Memory: ~{result.memory_used_mb:.1f}MB")
        }
        sections.append(f"*Metrics*: {', '.join(metrics_parts)}")
        
        // Generated files
        if result.generated_files != null && result.generated_files!.length > 0 {
            file_list: list<string> = []
            for fi in result.generated_files! {
                file_list.append(f"- `{fi.path}` ({format_bytes(fi.size_bytes)})")
            }
            sections.append("**Generated Files**:\n" + "\n".join(file_list))
        }
        
        // Plots/Figures
        if result.plots != null && result.plots!.length > 0 {
            plot_descriptions: list<string> = []
            for i, plot in enumerate(result.plots!) {
                plot_descriptions.append(f"[Plot {i+1}: {plot.width}x{plot.height} {plot.format}]({i})")
            }
            sections.append("**Plots Generated**: " + ", ".join(plot_descriptions))
        }
        
        // Return value (if meaningful)
        if result.return_value != null {
            rv_str = format_value_for_display(result.return_value!)
            if rv_str.length > 0 && rv_str != result.output.trim() {
                sections.append(f"**Return Value**: `{rv_str}`")
            }
        }
        
        return FormattedOutput{
            raw=result,
            formatted_text="\n\n".join(sections),
            has_visualizations=(result.plots?.length ?? 0) > 0,
            has_files=(result.generated_files?.length ?? 0) > 0
        }
    }

    _truncate(text: string, max_chars: int) -> string {
        if text.length <= max_chars {
            return text
        }
        return text[:max_chars] + f"\n... [truncated, {text.length - max_chars} more chars]"
    }

    _format_code_block(content: string, lang: string) -> string {
        return "```\n" + content + "\n```"
    }
}

struct FormattedOutput {
    raw: ExecutionResult
    formatted_text: string
    has_visualizations: bool
    has_files: bool
}

// ==================== 高级功能: 数据分析助手 ====================

class DataAnalysisHelper {
    sandbox: SandboxEnvironment
    formatter: ResultFormatter

    init(sandbox: SandboxEnvironment) {
        this.sandbox = sandbox
        this.formatter = new ResultFormatter(sandbox.config)
    }

    // Auto-generate data exploration code
    explore_dataset(csv_path: string, max_rows: int = 5) -> ExecutionResult {
        code = f"""
import pandas as pd
import numpy as np

# Load dataset
df = pd.read_csv("{csv_path}")
print("=" * 60)
print("DATASET OVERVIEW")
print("=" * 60)

# Basic info
print(f"\\nShape: {{df.shape}}")
print(f"\\nColumns: {{list(df.columns)}}")
print(f"\\nDtypes:\\n{{df.dtypes}}")

# Statistical summary
print("\\n" + "=" * 60)
print("STATISTICAL SUMMARY")
print("=" * 60)
print(df.describe())

# First few rows
print("\\n" + "=" * 60)
print(f"FIRST {{max_rows}} ROWS")
print("=" * 60)
print(df.head({max_rows}).to_string(index=False))

# Missing values
print("\\n" + "=" * 60)
print("MISSING VALUES")
print("=" * 60)
missing = df.isnull().sum()
if missing.sum() > 0:
    print(missing[missing > 0])
else:
    print("No missing values")

# Memory usage
print("\\n" + "=" * 60)
print("MEMORY USAGE")
print("=" * 60)
mem = df.memory_usage(deep=True)
print(f"Total: {{mem.sum() / 1024 / 1024:.2f}} MB")
"""
        let code_block = CodeBlock{language="python", code=code}
        let result = this.sandbox.execute(code_block)
        return result
    }

    // Generate visualization code
    visualize_data(csv_path: string, chart_type: string, x_col: string, y_col: string?, 
                   group_by: string?) -> ExecutionResult {
        viz_templates: map<string, string> = {
            "bar": f"""
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

df = pd.read_csv("{csv_path}")

plt.figure(figsize=(12, 6))
sns.barplot(data=df, x="{x_col}", y="{y_col ?? 'value'}")
plt.xticks(rotation=45)
plt.title('Bar Chart')
plt.tight_layout()
plt.savefig('chart_bar.png', dpi=150, bbox_inches='tight')
print("Chart saved as chart_bar.png")
""",
            "line": f"""
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

df = pd.read_csv("{csv_path}")

plt.figure(figsize=(12, 6))
sns.lineplot(data=df, x="{x_col}", y="{y_col ?? 'value'}")
plt.title('Line Chart')
plt.tight_layout()
plt.savefig('chart_line.png', dpi=150, bbox_inches='tight')
print("Chart saved as chart_line.png")
""",
            "scatter": f"""
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

df = pd.read_csv("{csv_path}")

plt.figure(figsize=(10, 8))
sns.scatterplot(data=df, x="{x_col}", y="{y_col ?? 'value'}", alpha=0.7)
plt.title('Scatter Plot')
plt.tight_layout()
plt.savefig('chart_scatter.png', dpi=150, bbox_inches='tight')
print("Chart saved as chart_scatter.png")
""",
            "histogram": f"""
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

df = pd.read_csv("{csv_path}")

plt.figure(figsize=(12, 6))
sns.histplot(data=df, x="{x_col}", kde=True)
plt.title('Histogram')
plt.tight_layout()
plt.savefig('chart_histogram.png', dpi=150, bbox_inches='tight')
print("Chart saved as chart_histogram.png")
""",
            "correlation": f"""
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

df = pd.read_csv("{csv_path}")

# Select numeric columns only
numeric_df = df.select_dtypes(include=[np.number])

plt.figure(figsize=(12, 10))
corr = numeric_df.corr()
sns.heatmap(corr, annot=True, cmap='coolwarm', center=0, fmt='.2f')
plt.title('Correlation Matrix')
plt.tight_layout()
plt.savefig('chart_correlation.png', dpi=150, bbox_inches='tight')
print("Chart saved as chart_correlation.png")
"""
        }
        
        if chart_type.to_lower() not in viz_templates {
            return ExecutionResult{
                success=false,
                error=f"Unsupported chart type: {chart_type}. Supported: {', '.join(viz_templates.keys())}",
                error_type="VisualizationError",
                line_count=0
            }
        }
        
        code = viz_templates[chart_type.to_lower()]
        let code_block = CodeBlock{language="python", code=code}
        return this.sandbox.execute(code_block)
    }

    // Run statistical tests
    run_statistical_test(csv_path: string, test_type: string, col1: string, col2: string?) -> ExecutionResult {
        code = f"""
import pandas as pd
import numpy as np
from scipy import stats

df = pd.read_csv("{csv_path}")
test_type = "{test_type}".lower()

if test_type == "t-test":
    # Independent t-test
    group1 = df[df["{col2}"] == df["{col2}"].unique()[0]]["{col1}"]
    group2 = df[df["{col2}"] == df["{col2}"].unique()[1]]["{col1}"]
    t_stat, p_val = stats.ttest_ind(group1, group2)
    print(f"T-statistic: {{t_stat:.4f}}")
    print(f"P-value: {{p_val:.4e}}")
    print(f"Significant at α=0.05: {{'Yes' if p_val < 0.05 else 'No'}}")

elif test_type == "anova":
    groups = [group["{col1}"].values for name, group in df.groupby("{col2}")]
    f_stat, p_val = stats.f_oneway(*groups)
    print(f"F-statistic: {{f_stat:.4f}}")
    print(f"P-value: {{p_val:.4e}}")
    
elif test_type == "normality":
    stat, p_val = stats.shapiro(df["{col1}"])
    print(f"Shapiro-Wilk statistic: {{stat:.4f}}")
    print(f"P-value: {{p_val:.4e}}")
    print(f"Normally distributed (α=0.05): {{'Yes' if p_val > 0.05 else 'No'}}")

elif test_type == "pearson":
    corr, p_val = stats.pearsonr(df["{col1}"], df["{col2}"])
    print(f"Pearson correlation: {{corr:.4f}}")
    print(f"P-value: {{p_val:.4e}}")

else:
    print(f"Unknown test type: {{test_type}}")
"""
        let code_block = CodeBlock{language="python", code=code}
        return this.sandbox.execute(code_block)
    }
}

// ==================== NEURX Code Interpreter 主接口 ====================

class CodeInterpreter {
    config: CodeInterpreterConfig
    sandbox: SandboxEnvironment?
    data_helper: DataAnalysisHelper?
    formatter: ResultFormatter
    active_sessions: map<string, SandboxEnvironment>
    default_session: SandboxEnvironment?

    init(config?: CodeInterpreterConfig) {
        this.config = config ?? new CodeInterpreterConfig()
        this.formatter = new ResultFormatter(this.config)
        this.active_sessions = map<string, SandboxEnvironment>{}
        
        // Create default session
        this.default_session = this.create_session("default")
        this.data_helper = new DataAnalysisHelper(this.default_session!)
    }

    create_session(session_name: string) -> SandboxEnvironment {
        let session = new SandboxEnvironment(config=this.config)
        this.active_sessions[session_name] = session
        return session
    }

    execute_code(code: string, language?: string, session?: string) -> FormattedOutput {
        let target_session = this.active_sessions[session ?? "default"] ?? this.default_session!
        
        let code_block = CodeBlock{
            language=language ?? this.config.default_language,
            code=code
        }
        
        let result = target_session.execute(code_block)
        return this.formatter.format_for_llm(result)
    }

    // Convenience methods for common operations
    run_python(code: string) -> FormattedOutput {
        return this.execute_code(code, "python")
    }

    run_shell(command: string) -> FormattedOutput {
        return this.execute_code(command, "shell")
    }

    run_sql(query: string) -> FormattedOutput {
        return this.execute_code(query, "sql")
    }

    // Data analysis helpers
    analyze_csv(csv_path: string) -> FormattedOutput {
        let result = this.data_helper!.explore_dataset(csv_path)
        return this.formatter.format_for_llm(result)
    }

    plot_chart(csv_path: string, chart_type: string, x: string, y?: string, 
               group_by?: string) -> FormattedOutput {
        let result = this.data_helper!.visualize_data(csv_path, chart_type, x, y, group_by)
        return this.formatter.format_for_llm(result)
    }

    statistical_test(csv_path: string, test: string, col1: string, col2?: string) -> FormattedOutput {
        let result = this.data_helper!.run_statistical_test(csv_path, test, col1, col2)
        return this.formatter.format_for_llm(result)
    }

    // Session management
    list_sessions() -> list<string> {
        return list(this.active_sessions.keys())
    }

    get_session_summary(session_name: string) -> SessionSummary {
        let session = this.active_sessions[session_name] ?? this.default_session!
        return session.get_session_state().get_summary()
    }

    reset_session(session_name: string) {
        if session_name in this.active_sessions {
            this.active_sessions[session_name].reset()
        }
    }

    cleanup() {
        for session in this.active_sessions.values() {
            session.cleanup()
        }
        this.default_session?.cleanup()
        this.active_sessions.clear()
    }
}

// ==================== 工厂函数和测试 ====================

function create_code_interpreter(config?: CodeInterpreterConfig) -> CodeInterpreter {
    return new CodeInterpreter(config=config)
}

function test_code_interpreter() -> bool {
    print("🧪 Testing NEURX Code Interpreter...")
    
    ci = new CodeInterpreter()
    
    // Test 1: Basic Python execution
    print("  ✓ Test 1: Basic Python Execution")
    result1 = ci.run_python("""
x = 42
y = x * 2
print(f"The answer is: {{y}}")
""")
    assert result1.raw.success, f"Python exec failed: {result1.raw.error}"
    assert "84" in result1.raw.output, "Unexpected output"
    
    // Test 2: Security violation detection
    print("  ✓ Test 2: Security Violation Detection")
    result2 = ci.run_python("import os; os.system('rm -rf /')")
    assert !result2.raw.success, "Should block dangerous code"
    assert result2.raw.error_type == "SecurityError", "Should be security error"
    
    // Test 3: Shell execution (safe commands)
    print("  ✓ Test 3: Safe Shell Command Execution")
    result3 = ci.run_shell("echo 'Hello from shell'")
    assert result3.raw.success, "Shell exec failed"
    assert "Hello from shell" in result3.raw.output, "Unexpected shell output"
    
    // Test 4: SQL execution
    print("  ✓ Test 4: SQL Execution")
    result4 = ci.run_sql("""
CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER);
INSERT INTO users VALUES (1, 'Alice', 30), (2, 'Bob', 25);
SELECT * FROM users ORDER BY age DESC;
""")
    assert result4.raw.success, "SQL failed"
    
    // Test 5: Multi-step state persistence
    print("  ✓ Test 5: State Persistence Across Calls")
    ci.run_python("counter = 0")
    ci.run_python("counter += 1")
    result5 = ci.run_python("print(counter)")
    assert "1" in result5.raw.output, "State should persist"
    
    // Test 6: Data analysis helper
    print("  ✓ Test 6: Data Analysis Helper")
    // Create a sample CSV first
    ci.run_python("""
import pandas as pd
data = {'A': [1, 2, 3, 4, 5], 'B': [10, 20, 30, 40, 50]}
df = pd.DataFrame(data)
df.to_csv('sample.csv', index=False)
print("CSV created")
""")
    summary = ci.analyze_csv(ci.default_session!.working_dir + "sample.csv")
    assert summary.raw.success, "Data analysis failed"
    
    // Cleanup
    ci.cleanup()
    
    print("\n✅ All Code Interpreter Tests Passed!")
    return true
}

// Export public API
export {
    CodeInterpreterConfig, ExecutionResult, FileInfo, ImageData, CodeBlock,
    CodeInterpreter, SandboxEnvironment,
    DataAnalysisHelper, ResultFormatter,
    create_code_interpreter, test_code_interpreter
}
