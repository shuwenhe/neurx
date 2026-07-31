package neurx.compile.pipeline
use neurx.runtime.compile
use neurx.compile.ir
use neurx.compile.pass_manager
use neurx.compile.lowering
use neurx.compile.executor
use neurx.compile.cache
struct compile_pipeline_state {
    compile_state state
    ir_graph_state graph
    pass_plan_state pass_plan
    lowering_plan_state lowering_plan
    executor_plan_state executor_plan
    compile_cache_state cache
    string cache_key
}
func new_compile_pipeline_state(string module_name, string backend, string mode, bool dynamic, bool fullgraph, bool debug) compile_pipeline_state {
    compile_state base = new_compile_state(module_name, backend, mode)
    base = compile_set_dynamic(base, dynamic)
    base = compile_set_fullgraph(base, fullgraph)
    base = compile_set_debug(base, debug)
    compile_pipeline_state {
        state: base,
        graph: new_ir_graph_state(module_name),
        pass_plan: new_pass_plan_state(mode, dynamic, fullgraph),
        lowering_plan: new_lowering_plan_state(backend),
        executor_plan: new_executor_plan_state(backend),
        cache: new_compile_cache_state(),
        cache_key: make_cache_key(module_name, backend, mode, dynamic, fullgraph, debug),
    }
}

func pipeline_capture_module(compile_pipeline_state pipeline) compile_pipeline_state {
    ir_graph_state graph = ir_add_input(pipeline.graph, "input")
    graph = ir_add_node(graph, make_ir_node_state(pipeline.state.name + "_entry", "module_entry", ["input"], ["hidden"]))
    graph = ir_add_node(graph, make_ir_node_state(pipeline.state.name + "_exit", "module_exit", ["hidden"], ["output"]))
    graph = ir_add_output(graph, "output")
    graph = ir_add_edge(graph, pipeline.state.name + "_entry->" + pipeline.state.name + "_exit")
    compile_state next = pipeline.state
    next = compile_set_captured(next, true)
    next = compile_add_node_with_io(next, pipeline.state.name + "_entry", "module_entry", [], ["input"], ["hidden"])
    next = compile_add_node_with_io(next, pipeline.state.name + "_exit", "module_exit", [], ["hidden"], ["output"])
    next = compile_add_edge(next, pipeline.state.name + "_entry->" + pipeline.state.name + "_exit")
    compile_pipeline_state {
        state: next,
        graph: graph,
        pass_plan: pipeline.pass_plan,
        lowering_plan: pipeline.lowering_plan,
        executor_plan: pipeline.executor_plan,
        cache: pipeline.cache,
        cache_key: pipeline.cache_key,
    }
}

func pipeline_optimize(compile_pipeline_state pipeline) compile_pipeline_state {
    compile_state next = apply_pass_plan(pipeline.state, pipeline.pass_plan)
    compile_pipeline_state {
        state: next,
        graph: pipeline.graph,
        pass_plan: pipeline.pass_plan,
        lowering_plan: pipeline.lowering_plan,
        executor_plan: pipeline.executor_plan,
        cache: pipeline.cache,
        cache_key: pipeline.cache_key,
    }
}

func pipeline_lower(compile_pipeline_state pipeline) compile_pipeline_state {
    compile_state next = lower_compile_state(pipeline.state, pipeline.lowering_plan)
    lowering_plan_state plan = mark_lowered(pipeline.lowering_plan, true, next.compiled)
    compile_pipeline_state {
        state: next,
        graph: pipeline.graph,
        pass_plan: pipeline.pass_plan,
        lowering_plan: plan,
        executor_plan: pipeline.executor_plan,
        cache: pipeline.cache,
        cache_key: pipeline.cache_key,
    }
}

func pipeline_compile_cache(compile_pipeline_state pipeline) compile_pipeline_state {
    compile_cache_state cache_state = pipeline.cache
    if cache_has_key(cache_state, pipeline.cache_key) {
        cache_state = cache_hit(cache_state)
    } else {
        cache_state = cache_put(cache_state, pipeline.cache_key, pipeline.state.name + ":compiled")
    }
    compile_state next = compile_add_cache_key(pipeline.state, pipeline.cache_key)
    compile_pipeline_state {
        state: next,
        graph: pipeline.graph,
        pass_plan: pipeline.pass_plan,
        lowering_plan: pipeline.lowering_plan,
        executor_plan: pipeline.executor_plan,
        cache: cache_state,
        cache_key: pipeline.cache_key,
    }
}

func pipeline_execute(compile_pipeline_state pipeline) compile_pipeline_state {
    compile_state next = execute_compile_state(pipeline.state, pipeline.executor_plan)
    executor_plan_state plan = executor_mark_launch(pipeline.executor_plan)
    compile_pipeline_state {
        state: next,
        graph: pipeline.graph,
        pass_plan: pipeline.pass_plan,
        lowering_plan: pipeline.lowering_plan,
        executor_plan: plan,
        cache: pipeline.cache,
        cache_key: pipeline.cache_key,
    }
}

func run_compile_pipeline(string module_name, string backend, string mode, bool dynamic, bool fullgraph, bool debug) compile_pipeline_state {
    compile_pipeline_state pipeline = new_compile_pipeline_state(module_name, backend, mode, dynamic, fullgraph, debug)
    pipeline = pipeline_capture_module(pipeline)
    pipeline = pipeline_optimize(pipeline)
    pipeline = pipeline_lower(pipeline)
    pipeline_compile_cache(pipeline)
}

func run_compile_execute_pipeline(string module_name, string backend, string mode, bool dynamic, bool fullgraph, bool debug) compile_pipeline_state {
    compile_pipeline_state pipeline = run_compile_pipeline(module_name, backend, mode, dynamic, fullgraph, debug)
    pipeline_execute(pipeline)
}

func compile_pipeline_state_dict(compile_pipeline_state pipeline) compile_pipeline_state {
    pipeline
}

func compile_pipeline_load_state_dict(compile_pipeline_state pipeline, compile_pipeline_state other) compile_pipeline_state {
    other
}
