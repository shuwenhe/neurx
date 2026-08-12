module code_interpreter
struct code_interpreter_config {
    execution_timeout_seconds: int = 120
    total_session_timeout: int = 600
    max_memory_mb: int = 512
    max_output_size_bytes: int = 10 * 1024 * 1024
    max_file_size_mb: int = 10
    supported_languages: list<string> = ["python", "javascript", "s", "sql"]
    default_language: string = "python"
    sandbox_enabled: bool = true
    allow_network_access: bool = false
    allowed_modules: list<string> = [
        "math", "random", "datetime", "json", "re", "collections",
        "itertools", "functools", "operator", "statistics",
        "numpy", "pandas", "matplotlib", "scipy"
    ]
    blocked_modules: list<string> = [
        "os", "subprocess", "sys", "importlib", "__import__",
        "eval", "exec", "compile", "open"
    ]
    working_directory: string = "/tmp/code_interpreter_sessions/"
    install_dependencies: bool = true
    persist_files_between_calls: bool = true
    enable_plotting: bool = true
    enable_dataframe_display: bool = true
    image_format: string = "png"
}


struct execution_result {
    success: bool
    output: string
    error: string?
    error_type: string?
    traceback: list<string>?
    return_value: any
    variables: map<string, any>?
    generated_files: list<file_info>?
    plots: list<image_data>?
    execution_time_ms: float
    memory_used_mb: float
    line_count: int
}


struct file_info {
    path: string
    size_bytes: int
    content_type: string
    preview: string?
    is_image: bool
}


struct image_data {
    data: bytes
    format: string
    width: int
    height: int
    alt_text: string?
}


struct code_block {
    language: string
    code: string
    filename: string?
}
class sandbox_environment {
    config: code_interpreter_config
    session_id: string
    working_dir: string
    state: SessionState
    python_runtime: PythonRuntime?
    javascript_runtime: JavaScriptRuntime?
    s_runtime: ShellRuntime?
    sql_runtime: SQLRuntime?
    init(config: code_interpreter_config) {
        this.config = config
        this.session_id = generate_uuid()
        this.working_dir = config.working_directory + this.session_id + "/"
        create_directory(this.working_dir)
        this.state = new session_state(
            session_id=this.session_id,
            created_at=current_timestamp(),
            variables=map<string, any>{},
            files_created=list<string>{},
            execution_history=list<execution_record>{}
        )
        if "python" in config.supported_languages {
            this.python_runtime = new python_runtime(
                sandbox_dir=this.working_dir,
                memory_limit=config.max_memory_mb,
                timeout=config.execution_timeout_seconds
            )
        }
        if "javascript" in config.supported_languages {
            this.javascript_runtime = new java_script_runtime()
        }
        if "s" in config.supported_languages {
            this.s_runtime = new shell_runtime(allow_network=config.allow_network_access)
        }
        if "sql" in config.supported_languages {
            this.sql_runtime = new sql_runtime(db_path=this.working_dir + "sandbox.db")
        }
    }
    execute(code_block: code_block) {
        let start_time = current_time_millis()
        let security_result = this._security_check(code_block.code)
        if !security_result.allowed {
            return execution_result{
                success=false,
                output="",
                error=security_result.reason,
                error_type="SecurityError",
                execution_time_ms=current_time_millis() - start_time,
                line_count=count_lines(code_block.code),
                memory_used_mb=0
            }
        }
        result: execution_result
        match code_block.language.lower() {
            "python" | "py" => {
                assert this.python_runtime != null, "Python runtime not initialized"
                result = this.python_runtime!.execute(code_block.code, code_block.filename)
            }
            "javascript" | "js" => {
                assert this.javascript_runtime != null, "JavaScript runtime not initialized"
                result = this.javascript_runtime!.execute(code_block.code)
            }
            "s" | "bash" | "sh" => {
                assert this.s_runtime != null, "S runtime not initialized"
                result = this.s_runtime!.execute(code_block.code)
            }
            "sql" => {
                assert this.sql_runtime != null, "SQL runtime not initialized"
                result = this.sql_runtime!.execute(code_block.code)
            }
            _ => {
                result = execution_result{
                    success=false,
                    output="",
                    error=f"Unsupported language: {code_block.language}. Supported: {', '.join(this.config.supported_languages)}",
                    error_type="LanguageNotSupportedError",
                    execution_time_ms=current_time_millis() - start_time,
                    line_count=count_lines(code_block.code)
                }
            }
        }
        result.execution_time_ms = current_time_millis() - start_time
        result = this._post_process(result, code_block)
        this.state.add_execution_record(execution_record{
            code=code_block.code,
            language=code_block.language,
            result=result,
            timestamp=current_timestamp()
        })
        return result
    }
    _security_check(code: string) {
        issues: list<string> = []
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
        if "while True:" in code || "while(1)" in code || "while(true)" in code {
            if "break" not in code && "return" not in code:
                issues.append("Potential infinite loop without break condition")
        }
        large_allocations = [
            (r"\[\s*0\s*\]\s*\*\s*(\d{6,})", "Large array allocation may exceed memory limit")
        ]
        if issues.length > 0 {
            return security_check_result{allowed=false, reason="\n".join(issues)}
        }
        return security_check_result{allowed=true, reason=""}
    }
    _post_process(result: execution_result, code_block: code_block) {
        if this.config.persist_files_between_calls {
            let files = scan_directory_for_new_files(
                this.working_dir,
                since=this.state.last_execution_time
            )
            result.generated_files = files
            for f in files {
                this.state.files_created.append(f.path)
            }
        }
        if code_block.language == "python" && this.config.enable_plotting && result.success {
            result.plots = this._extract_matplotlib_plots()
        }
        result.memory_used_mb = estimate_memory_usage(result.output.length)
        return result
    }
    _extract_matplotlib_plots() {
        plots: list<image_data> = []
        plot_files = find_files_with_extension(this.working_dir, [".png", ".svg", ".jpeg"])
        for plot_file in plot_files {
            img_data = read_file_as_bytes(plot_file)
            plots.append(image_data{
                data=img_data,
                format=get_file_extension(plot_file),
                width=0,
                height=0,
                alt_text=f"Generated plot: {get_filename(plot_file)}"
            })
        }
        return plots
    }
    get_session_state() {
        return this.state
    }
    cleanup() {
        if this.config.sandbox_enabled {
            remove_directory_recursive(this.working_dir)
        }
    }
    reset() {
        this.state.variables.clear()
        this.state.execution_history.clear()
        this.state.files_created.clear()
    }
}


struct security_check_result {
    allowed: bool
    reason: string
}
class session_state {
    session_id: string
    created_at: float
    last_execution_time: float = 0
    variables: map<string, any>
    files_created: list<string>
    execution_history: list<execution_record>
    total_execution_time_ms: float = 0
    init(session_id: string, created_at: float, variables: map<string, any>,
         files_created: list<string>, execution_history: list<execution_record>) {
        this.session_id = session_id
        this.created_at = created_at
        this.variables = variables
        this.files_created = files_created
        this.execution_history = execution_history
    }
    add_execution_record(record: execution_record) {
        this.execution_history.append(record)
        this.last_execution_time = record.timestamp
        this.total_execution_time_ms += record.result.execution_time_ms
    }
    get_summary() {
        return session_summary{
            session_id=this.session_id,
            duration_seconds=current_timestamp() - this.created_at,
            num_executions=this.execution_history.length,
            total_execution_time_sec=this.total_execution_time_ms / 1000.0,
            files_created_count=this.files_created.length,
            variable_names=list(this.variables.keys()),
            success_rate=this._compute_success_rate()
        }
    }
    _compute_success_rate() {
        if this.execution_history.length == 0 {
            return 1.0
        }
        successes = sum(1 for r in this.execution_history if r.result.success)
        return successes / this.execution_history.length
    }
}


struct execution_record {
    code: string
    language: string
    result: execution_result
    timestamp: float
}


struct session_summary {
    session_id: string
    duration_seconds: float
    num_executions: int
    total_execution_time_sec: float
    files_created_count: int
    variable_names: list<string>
    success_rate: float
}
class python_runtime {
    sandbox_dir: string
    memory_limit: int
    timeout: int
    process?: ProcessHandle
    interpreter_path: string = "python"
    init(sandbox_dir: string, memory_limit: int, timeout: int) {
        this.sandbox_dir = sandbox_dir
        this.memory_limit = memory_limit
        this.timeout = timeout
        if !check_command_available(this.interpreter_path) {
            throw error(f"Python interpreter not found: {this.interpreter_path}")
        }
    }
    execute(code: string, filename: string?) {
        let script_path = this.sandbox_dir + (filename ?? "execution_" + generate_short_uuid() + ".py")
        write_file(script_path, code)
        try {
            let cmd = [
                this.interpreter_path,
                "-u",
                "-B",
                script_path
            ]
            env_vars = {
                "PYTHONPATH": this.sandbox_dir,
                "HOME": this.sandbox_dir,
                "TMPDIR": this.sandbox_dir,
                "PYTHONDONTWRITEBYTECODE": "1"
            }
            let proc = subprocess_run(
                cmd,
                capture_output=true,
                text=true,
                timeout=this.timeout,
                cwd=this.sandbox_dir,
                env=env_vars
            )
            output = proc.stdout
            error_output = proc.stderr
            if proc.returncode != 0 {
                let error_info = this._parse_python_error(error_output)
                return execution_result{
                    success=false,
                    output=output,
                    error=error_info.message,
                    error_type=error_info.error_type,
                    traceback=error_info.traceback,
                    return_value=null,
                    execution_time_ms=0,
                    line_count=count_lines(code),
                    memory_used_mb=0
                }
            }
            return_value = this._extract_return_value(output)
            return execution_result{
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
        } catch timeout_expired {
            kill_process(this.process)
            return execution_result{
                success=false,
                output="",
                error=f"Execution timed out after {this.timeout} seconds",
                error_type="TimeoutError",
                execution_time_ms=this.timeout * 1000.0,
                line_count=count_lines(code),
                memory_used_mb=0
            }
        } catch exception as e {
            return execution_result{
                success=false,
                output="",
                error=str(e),
                error_type="ExecutionError",
                line_count=count_lines(code),
                memory_used_mb=0
            }
        }
    }
    _parse_python_error(stderr_output: string) {
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
        return error_info{
            error_type=error_type ?: "UnknownError",
            message=message ?: stderr_output,
            traceback=traceback
        }
    }
    _extract_return_value(stdout: string) {
        lines = stdout.strip().split("\n")
        if lines.length > 0 {
            last_line = lines[-1]
            try {
                return json_parse(last_line)
            }
            try {
                return parse_float(last_line)
            }
            return last_line
        }
        return null
    }
}


struct error_info {
    error_type: string
    message: string
    traceback: list<string>
}
class java_script_runtime {
    vm_context: any
    init() {
        this.vm_context = create_javascript_vm()
    }
    execute(code: string) {
        try {
            wrapped_code = """
                (function() {
                    let __output = [];
                    const originalLog = console.log;
                    console.log = (...args) => { __output.push(args.join(' ')); };
                    try {
                        ${code}
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
            return execution_result{
                success=true,
                output=result.output,
                error=null,
                return_value=result.returnValue,
                execution_time_ms=0,
                line_count=count_lines(code),
                memory_used_mb=0
            }
        } catch exception as e {
            return execution_result{
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
class shell_runtime {
    allow_network: bool
    allowed_commands: set<string>
    init(allow_network: bool) {
        this.allow_network = allow_network
        this.allowed_commands = set<string>{
            "ls", "pwd", "echo", "cat", "head", "tail", "wc", "grep", "find",
            "date", "uname", "whoami", "df", "du", "sort", "uniq", "cut",
            "awk", "sed", "tr", "base64", "md5sum", "sha256sum",
            "python", "pip", "git", "curl" if allow_network else null,
            "wget" if allow_network else null
        }.filter(x => x != null).map(x => x!)
    }
    execute(command: string) {
        base_command = command.split_whitespace()[0]
        if base_command not in this.allowed_commands {
            return execution_result{
                success=false,
                output="",
                error=f"command '{base_command}' is not allowed in sandbox",
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
                timeout=30,
                shell=false
            )
            return execution_result{
                success=proc.returncode == 0,
                output=proc.stdout,
                error=proc.stderr if proc.stderr.length > 0 else null,
                return_value=proc.returncode,
                execution_time_ms=0,
                line_count=count_lines(command),
                memory_used_mb=0
            }
        } catch timeout_expired {
            return execution_result{
                success=false,
                output="",
                error="Shell command timed out after 30 seconds",
                error_type="TimeoutError",
                line_count=count_lines(command),
                memory_used_mb=0
            }
        } catch exception as e {
            return execution_result{
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
class sql_runtime {
    db_path: string
    connection: DatabaseConnection?
    init(db_path: string) {
        this.db_path = db_path
        this.connection = connect_to_sqlite(db_path)
    }
    execute(query: string) {
        try {
            query_type = detect_sql_query_type(query)
            match query_type {
                "SELECT" | "SHOW" | "DESCRIBE" | "EXPLAIN" => {
                    let cursor = this.connection!.execute(query)
                    columns = cursor.column_names
                    rows = cursor.fetchall()
                    output = format_sql_table(columns, rows)
                    return_value = sql_query_result{
                        columns=columns,
                        rows=rows,
                        row_count=rows.length
                    }
                    return execution_result{
                        success=true,
                        output=output,
                        return_value=return_value,
                        execution_time_ms=0,
                        line_count=count_lines(query),
                        memory_used_mb=0
                    }
                }
                "CREATE" | "ALTER" | "DROP" | "INSERT" | "UPDATE" | "DELETE" => {
                    this.connection!.execute(query)
                    affected_rows = this.connection!.rows_affected
                    return execution_result{
                        success=true,
                        output=f"Query executed successfully. Affected rows: {affected_rows}",
                        return_value={"affected_rows": affected_rows},
                        execution_time_ms=0,
                        line_count=count_lines(query),
                        memory_used_mb=0
                    }
                }
                _ => {
                    return execution_result{
                        success=false,
                        output="",
                        error=f"Unsupported SQL query type: {query_type}",
                        error_type="SQLSyntaxError",
                        line_count=count_lines(query),
                        memory_used_mb=0
                    }
                }
            }
        } catch sql_exception as e {
            return execution_result{
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


struct sql_query_result {
    columns: list<string>
    rows: list<list<any>>
    row_count: int
}
class result_formatter {
    config: code_interpreter_config
    init(config: code_interpreter_config) {
        this.config = config
    }
    format_for_llm(result: execution_result) {
        sections: list<string> = []
        status_icon = result.success ? "✅" : "❌"
        status_text = result.success ? "Success" : f"Error ({result.error_type})"
        sections.append(f"{status_icon} **status**: {status_text}")
        if result.output.length > 0 {
            truncated_output = this._truncate(result.output, max_chars=5000)
            formatted_output = this._format_code_block(truncated_output, "output")
            sections.append(f"**Output**:\n{formatted_output}")
        }
        if result.error != null {
            formatted_error = this._format_code_block(result.error!, "error")
            sections.append(f"**Error**:\n{formatted_error}")
            if result.traceback != null && result.traceback!.length > 0 {
                formatted_tb = this._format_code_block("\n".join(result.traceback!), "traceback")
                sections.append(f"**Traceback**:\n{formatted_tb}")
            }
        }
        metrics_parts: list<string> = []
        metrics_parts.append(f"Time: {result.execution_time_ms:.1f}ms")
        metrics_parts.append(f"Lines: {result.line_count}")
        if result.memory_used_mb > 0 {
            metrics_parts.append(f"Memory: ~{result.memory_used_mb:.1f}MB")
        }
        sections.append(f"*Metrics*: {', '.join(metrics_parts)}")
        if result.generated_files != null && result.generated_files!.length > 0 {
            file_list: list<string> = []
            for fi in result.generated_files! {
                file_list.append(f"- `{fi.path}` ({format_bytes(fi.size_bytes)})")
            }
            sections.append("**Generated Files**:\n" + "\n".join(file_list))
        }
        if result.plots != null && result.plots!.length > 0 {
            plot_descriptions: list<string> = []
            for i, plot in enumerate(result.plots!) {
                plot_descriptions.append(f"[Plot {i+1}: {plot.width}x{plot.height} {plot.format}]({i})")
            }
            sections.append("**Plots Generated**: " + ", ".join(plot_descriptions))
        }
        if result.return_value != null {
            rv_str = format_value_for_display(result.return_value!)
            if rv_str.length > 0 && rv_str != result.output.trim() {
                sections.append(f"**Return Value**: `{rv_str}`")
            }
        }
        return formatted_output{
            raw=result,
            formatted_text="\n\n".join(sections),
            has_visualizations=(result.plots?.length ?? 0) > 0,
            has_files=(result.generated_files?.length ?? 0) > 0
        }
    }
    _truncate(text: string, max_chars: int) {
        if text.length <= max_chars {
            return text
        }
        return text[:max_chars] + f"\n... [truncated, {text.length - max_chars} more chars]"
    }
    _format_code_block(content: string, lang: string) {
        return "```\n" + content + "\n```"
    }
}


struct formatted_output {
    raw: execution_result
    formatted_text: string
    has_visualizations: bool
    has_files: bool
}
class data_analysis_helper {
    sandbox: SandboxEnvironment
    formatter: ResultFormatter
    init(sandbox: SandboxEnvironment) {
        this.sandbox = sandbox
        this.formatter = new result_formatter(sandbox.config)
    }
    explore_dataset(csv_path: string, max_rows: int = 5) {
        code = f"""
import pandas as pd
import numpy as np
df = pd.read_csv("{csv_path}")
print("=" * 60)
print("DATASET OVERVIEW")
print("=" * 60)
print(f"\\n_shape: {{df.shape}}")
print(f"\\n_columns: {{list(df.columns)}}")
print(f"\\n_dtypes:\\n{{df.dtypes}}")
print("\\n" + "=" * 60)
print("STATISTICAL SUMMARY")
print("=" * 60)
print(df.describe())
print("\\n" + "=" * 60)
print(f"FIRST {{max_rows}} ROWS")
print("=" * 60)
print(df.head({max_rows}).to_string(index=False))
print("\\n" + "=" * 60)
print("MISSING VALUES")
print("=" * 60)
missing = df.isnull().sum()
if missing.sum() > 0:
    print(missing[missing > 0])
else:
    print("no missing values")
print("\\n" + "=" * 60)
print("MEMORY USAGE")
print("=" * 60)
mem = df.memory_usage(deep=True)
print(f"total: {{mem.sum() / 1024 / 1024:.2f}} MB")
"""
        let code_block = code_block{language="python", code=code}
        let result = this.sandbox.execute(code_block)
        return result
    }
    visualize_data(csv_path: string, chart_type: string, x_col: string, y_col: string?,
                   group_by: string?) {
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
numeric_df = df.select_dtypes(include=[np.number])
plt.figure(figsize=(12, 10))
corr = numeric_df.corr()
sns.heatmap(corr, annot=True, cmap='coolwarm', center=0, fmt='.2f')
plt.title('Correlation matrix')
plt.tight_layout()
plt.savefig('chart_correlation.png', dpi=150, bbox_inches='tight')
print("Chart saved as chart_correlation.png")
"""
        }
        if chart_type.to_lower() not in viz_templates {
            return execution_result{
                success=false,
                error=f"unsupported chart type: {chart_type}. Supported: {', '.join(viz_templates.keys())}",
                error_type="visualization_error",
                line_count=0
            }
        }
        code = viz_templates[chart_type.to_lower()]
        let code_block = code_block{language="python", code=code}
        return this.sandbox.execute(code_block)
    }
    run_statistical_test(csv_path: string, test_type: string, col1: string, col2: string?) {
        code = f"""
import pandas as pd
import numpy as np
from scipy import stats
df = pd.read_csv("{csv_path}")
test_type = "{test_type}".lower()
if test_type == "t-test":
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
        let code_block = code_block{language="python", code=code}
        return this.sandbox.execute(code_block)
    }
}
class CodeInterpreter {
    config: code_interpreter_config
    sandbox: SandboxEnvironment?
    data_helper: DataAnalysisHelper?
    formatter: ResultFormatter
    active_sessions: map<string, SandboxEnvironment>
    default_session: SandboxEnvironment?
    init(config?: code_interpreter_config) {
        this.config = config ?? new code_interpreter_config()
        this.formatter = new ResultFormatter(this.config)
        this.active_sessions = map<string, SandboxEnvironment>{}
        this.default_session = this.create_session("default")
        this.data_helper = new DataAnalysisHelper(this.default_session!)
    }
    create_session(session_name: string) {
        let session = new SandboxEnvironment(config=this.config)
        this.active_sessions[session_name] = session
        return session
    }
    execute_code(code: string, language?: string, session?: string) {
        let target_session = this.active_sessions[session ?? "default"] ?? this.default_session!
        let code_block = code_block{
            language=language ?? this.config.default_language,
            code=code
        }
        let result = target_session.execute(code_block)
        return this.formatter.format_for_llm(result)
    }
    run_python(code: string) {
        return this.execute_code(code, "python")
    }
    run_s(command: string) {
        return this.execute_code(command, "s")
    }
    run_shell(command: string) {
        return this.run_s(command)
    }
    run_sql(query: string) {
        return this.execute_code(query, "sql")
    }
    analyze_csv(csv_path: string) {
        let result = this.data_helper!.explore_dataset(csv_path)
        return this.formatter.format_for_llm(result)
    }
    plot_chart(csv_path: string, chart_type: string, x: string, y?: string,
               group_by?: string) {
        let result = this.data_helper!.visualize_data(csv_path, chart_type, x, y, group_by)
        return this.formatter.format_for_llm(result)
    }
    statistical_test(csv_path: string, test: string, col1: string, col2?: string) {
        let result = this.data_helper!.run_statistical_test(csv_path, test, col1, col2)
        return this.formatter.format_for_llm(result)
    }
    list_sessions() {
        return list(this.active_sessions.keys())
    }
    get_session_summary(session_name: string) {
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
function create_code_interpreter(config?: code_interpreter_config) {
    return new CodeInterpreter(config=config)
}
function test_code_interpreter() {
    print("🧪 testing NEURX code interpreter...")
    ci = new CodeInterpreter()
    print("  ✓ test 1: Basic python execution")
    result1 = ci.run_python("""
x = 42
y = x * 2
print(f"The answer is: {{y}}")
""")
    assert result1.raw.success, f"python exec failed: {result1.raw.error}"
    assert "84" in result1.raw.output, "unexpected output"
    print("  ✓ test 2: Security violation detection")
    result2 = ci.run_python("import os; os.system('rm -rf /')")
    assert !result2.raw.success, "should block dangerous code"
    assert result2.raw.error_type == "security_error", "should be security error"
    print("  ✓ test 3: Safe shell command execution")
    result3 = ci.run_s("echo 'Hello from s'")
    assert result3.raw.success, "S exec failed"
    assert "hello from s" in result3.raw.output, "unexpected s output"
    print("  ✓ test 4: SQL execution")
    result4 = ci.run_sql("""
CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER);
INSERT INTO users VALUES (1, 'Alice', 30), (2, 'Bob', 25);
SELECT * FROM users ORDER BY age DESC;
""")
    assert result4.raw.success, "SQL failed"
    print("  ✓ test 5: State persistence across calls")
    ci.run_python("counter = 0")
    ci.run_python("counter += 1")
    result5 = ci.run_python("print(counter)")
    assert "1" in result5.raw.output, "state should persist"
    print("  ✓ test 6: Data analysis helper")
    ci.run_python("""
import pandas as pd
data = {'A': [1, 2, 3, 4, 5], 'B': [10, 20, 30, 40, 50]}
df = pd.DataFrame(data)
df.to_csv('sample.csv', index=False)
print("CSV created")
""")
    summary = ci.analyze_csv(ci.default_session!.working_dir + "sample.csv")
    assert summary.raw.success, "data analysis failed"
    ci.cleanup()
    print("\n✅ all code interpreter tests passed!")
    return true
}
export {
    code_interpreter_config, execution_result, file_info, image_data, code_block,
    CodeInterpreter, SandboxEnvironment,
    DataAnalysisHelper, ResultFormatter,
    create_code_interpreter, test_code_interpreter
}

