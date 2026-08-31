package neurx.compile.compiler
use neurx.platform.errors.{platform_error_state, new_configuration_error, clear_error, platform_error_active}
use neurx.compile.pipeline
use neurx.compile.ir.{ir_graph_state, new_ir_graph_state, ir_add_input, ir_add_output, ir_add_node, ir_add_edge, make_ir_node_state, ir_graph_to_text}
use neurx.compile.backend.direct_codegen.{direct_codegen_plan_state, new_direct_codegen_plan_state, direct_codegen_compile_ir, direct_codegen_result_state, machine_code_blob_state, direct_codegen_write_blob, direct_codegen_write_object_file, direct_codegen_link_executable}
use neurx.runtime.io.{runtime_env_get, runtime_make_dirs, runtime_write_text_file}
struct compile_options {
    string backend
    string mode
    bool fullgraph
    bool dynamic
    bool debug
}

struct compiled_module_state {
    string module_name
    compile_options options
    bool compiled
    bool lowered
    bool executed
    bool graph_ready
    int graph_node_count
    int graph_edge_count
    int pass_count
    string cache_key
    machine_code_blob_state native_blob
}

struct compile_result {
    compiled_module_state state
    bool ok
    platform_error_state error
}

func new_compile_options() compile_options {
    compile_options {
        backend: "eager",
        mode: "default",
        fullgraph: false,
        dynamic: false,
        debug: false,
    }
}

func make_compile_result(compiled_module_state state, bool ok, error platform_error_state) compile_result {
    compile_result {
        state: state,
        ok: ok,
        error: error,
    }
}

func is_valid_backend(string backend) bool {
    backend == "eager" || backend == "aot" || backend == "native"
}

func is_valid_mode(string mode) bool {
    mode == "default" || mode == "reduce-overhead" || mode == "max-autotune"
}

func validate_compile_options(compile_options options) platform_error_state {
    if !is_valid_backend(options.backend) {
        return new_configuration_error("compile backend must be one of {eager,aot,native}")
    }
    if !is_valid_mode(options.mode) {
        return new_configuration_error("compile mode must be one of {default,reduce-overhead,max-autotune}")
    }
    clear_error()
}

func new_compiled_module_state(string module_name, compile_options options) compiled_module_state {
    compiled_module_state {
        module_name: module_name,
        options: options,
        compiled: options.backend == "aot" || options.backend == "native",
        lowered: options.backend == "aot" || options.backend == "native",
        executed: false,
        graph_ready: true,
        graph_node_count: 1,
        graph_edge_count: 0,
        pass_count: 0,
        cache_key: "",
        native_blob: new_machine_code_blob_state(module_name),
    }
}

func module_name_to_native_graph(string module_name) ir_graph_state {
    ir_graph_state graph = new_ir_graph_state(module_name)
    graph = ir_add_input(graph, "input")
    graph = ir_add_node(graph, make_ir_node_state(module_name + "_entry", "module_entry", ["input"], ["hidden"]))
    graph = ir_add_node(graph, make_ir_node_state(module_name + "_exit", "module_exit", ["hidden"], ["output"]))
    graph = ir_add_output(graph, "output")
    graph = ir_add_edge(graph, module_name + "_entry." + module_name + "_exit")
    graph
}

func pipeline_to_compiled_state(compile_pipeline_state pipeline, string module_name, compile_options options) compiled_module_state {
    compiled_module_state {
        module_name: module_name,
        options: options,
        compiled: pipeline.state.compiled,
        lowered: pipeline.state.lowered,
        executed: pipeline.state.executed,
        graph_ready: pipeline.state.ready,
        graph_node_count: len(pipeline.state.nodes),
        graph_edge_count: len(pipeline.state.edges),
        pass_count: len(pipeline.state.passes),
        cache_key: pipeline.cache_key,
        native_blob: pipeline.state.native_blob,
    }
}

func compile_module(string module_name, compile_options options) compile_result {
    platform_error_state err = validate_compile_options(options)
    compiled_module_state state = new_compiled_module_state(module_name, options)
    if platform_error_active(err) {
        make_compile_result(state, false, err)
    } else {
        if options.backend == "native" {
            direct_codegen_plan_state plan = new_direct_codegen_plan_state("x86_64", module_name)
            ir_graph_state graph = module_name_to_native_graph(module_name)
            direct_codegen_result_state native_result = direct_codegen_compile_ir(graph, plan)
            if !native_result.ok {
                return make_compile_result(state, false, new_configuration_error(native_result.error_message))
            }
            state.compiled = true
            state.lowered = true
            state.native_blob = native_result.blob
            string native_ir_dir = runtime_env_get("NEURX_NATIVE_IR_DIR", "./build/native-ir")
            string native_object_dir = runtime_env_get("NEURX_NATIVE_OBJECT_DIR", "./build/native-object")
            runtime_make_dirs(native_ir_dir)
            runtime_write_text_file(native_ir_dir + "/" + module_name + ".native.ir", ir_graph_to_text(graph))
            direct_codegen_write_blob(native_object_dir, module_name, state.native_blob)
            string native_object_path = direct_codegen_write_object_file(native_object_dir, module_name, native_result.instructions, "main")
            direct_codegen_link_executable(native_object_dir, module_name, native_object_path)
            state.pass_count = 3
            state.graph_node_count = len(graph.nodes)
            state.graph_edge_count = len(graph.edges)
            return make_compile_result(state, true, clear_error())
        }
        compile_pipeline_state pipeline = run_compile_pipeline(
            module_name,
            options.backend,
            options.mode,
            options.dynamic,
            options.fullgraph,
            options.debug
        )
        make_compile_result(pipeline_to_compiled_state(pipeline, module_name, options), true, clear_error())
    }
}

func compiled_module_execute(compiled_module_state state) compiled_module_state {
    compile_pipeline_state pipeline = run_compile_execute_pipeline(
        state.module_name,
        state.options.backend,
        state.options.mode,
        state.options.dynamic,
        state.options.fullgraph,
        state.options.debug
    )
    compiled_module_state {
        module_name: state.module_name,
        options: state.options,
        compiled: pipeline.state.compiled,
        lowered: pipeline.state.lowered,
        executed: pipeline.state.executed,
        graph_ready: pipeline.state.ready,
        graph_node_count: len(pipeline.state.nodes),
        graph_edge_count: len(pipeline.state.edges),
        pass_count: len(pipeline.state.passes),
        cache_key: pipeline.cache_key,
        native_blob: pipeline.state.native_blob,
    }
}

func compiled_module_state_dict(compiled_module_state state) compiled_module_state {
    compiled_module_state {
        module_name: state.module_name,
        options: state.options,
        compiled: state.compiled,
        lowered: state.lowered,
        executed: state.executed,
        graph_ready: state.graph_ready,
        graph_node_count: state.graph_node_count,
        graph_edge_count: state.graph_edge_count,
        pass_count: state.pass_count,
        cache_key: state.cache_key,
        native_blob: state.native_blob,
    }
}

func compiled_module_load_state_dict(compiled_module_state state, compiled_module_state other) compiled_module_state {
    compiled_module_state {
        module_name: other.module_name,
        options: other.options,
        compiled: other.compiled,
        lowered: other.lowered,
        executed: other.executed,
        graph_ready: other.graph_ready,
        graph_node_count: other.graph_node_count,
        graph_edge_count: other.graph_edge_count,
        pass_count: other.pass_count,
        cache_key: other.cache_key,
        native_blob: other.native_blob,
    }
}
