package neurx.compile.compiler
use neurx.platform.errors.{platform_error_state, new_configuration_error, clear_error, platform_error_active}
use neurx.compile.pipeline
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


func make_compile_result(compiled_module_state state, bool ok, platform_error_state error) compile_result {
    compile_result {
        state: state,
        ok: ok,
        error: error,
    }
}


func is_valid_backend(string backend) bool {
    backend == "eager" || backend == "aot"
}


func is_valid_mode(string mode) bool {
    mode == "default" || mode == "reduce-overhead" || mode == "max-autotune"
}


func validate_compile_options(compile_options options) platform_error_state {
    if !is_valid_backend(options.backend) {
        return new_configuration_error("compile backend must be one of {eager,aot}")
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
        compiled: options.backend == "aot",
        lowered: options.backend == "aot",
        executed: false,
        graph_ready: true,
        graph_node_count: 1,
        graph_edge_count: 0,
        pass_count: 0,
        cache_key: "",
    }
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
    }
}


func compile_module(string module_name, compile_options options) compile_result {
    platform_error_state err = validate_compile_options(options)
    compiled_module_state state = new_compiled_module_state(module_name, options)
    if platform_error_active(err) {
        make_compile_result(state, false, err)
    } else {
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
    }
}


func compiled_module_state_dict(compiled_module_state state) compiled_module_state {
    state
}


func compiled_module_load_state_dict(compiled_module_state state, compiled_module_state other) compiled_module_state {
    other
}

