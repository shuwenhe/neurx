package neurx.experimental.compiler.compiler.graph_compiler

use neurx.experimental.compiler.ir.graph.computation_graph
use neurx.experimental.compiler.compiler.pass_manager.{pass_pipeline, default_optimization_pipeline, run_pass_pipeline}
use neurx.experimental.compiler.compiler.compilation_unit.{compilation_unit, compilation_config, compilation_stats, default_compilation_config, new_compilation_unit}

struct compiler_options {
    bool enable_constant_folding
    bool enable_op_fusion
    bool enable_dead_code_elim
    bool enable_memory_opt
}

func default_compiler_options() compiler_options {
    compiler_options {
        enable_constant_folding: true,
        enable_op_fusion: true,
        enable_dead_code_elim: true,
        enable_memory_opt: true,
    }
}

struct graph_compiler {
    compilation_config config
    compiler_options options
}

func new_graph_compiler(compilation_config cfg) graph_compiler {
    graph_compiler {
        config: cfg,
        options: default_compiler_options(),
    }
}

func new_graph_compiler_default() graph_compiler {
    graph_compiler {
        config: default_compilation_config(),
        options: default_compiler_options(),
    }
}

func (graph_compiler* compiler) get_optimization_level() int {
    match compiler.config.opt_level {
        "O0": 0,
        "O1": 1,
        "O2": 2,
        "O3": 3,
        default: 2,
    }
}

func (graph_compiler* compiler) compile(*computation_graph g) compilation_unit {
    unit = new_compilation_unit("compiled_graph", g)

    unit.stats.original_op_count = g.operation_count()
    unit.stats.original_memory = g.total_memory_bytes()

    unit.pipeline = default_optimization_pipeline()
    unit.pass_results = run_pass_pipeline(*unit.optimized_graph, *unit.pipeline)

    unit.stats.optimized_op_count = unit.optimized_graph.operation_count()
    unit.stats.optimized_memory = unit.optimized_graph.total_memory_bytes()

    unit
}

func (graph_compiler* compiler) compile_with_pipeline(*computation_graph g, *pass_pipeline pipeline) compilation_unit {
    unit = new_compilation_unit("compiled_graph", g)

    unit.stats.original_op_count = g.operation_count()
    unit.stats.original_memory = g.total_memory_bytes()

    unit.pass_results = run_pass_pipeline(*unit.optimized_graph, pipeline)

    unit.stats.optimized_op_count = unit.optimized_graph.operation_count()
    unit.stats.optimized_memory = unit.optimized_graph.total_memory_bytes()

    unit
}

func (graph_compiler* compiler) compile_with_config(*computation_graph g, string unit_name, *compilation_config cfg) compilation_unit {
    unit = new_compilation_unit(unit_name, g)

    unit.stats.original_op_count = g.operation_count()
    unit.stats.original_memory = g.total_memory_bytes()

    opt_level = cfg.opt_level

    if opt_level == "O0" {
        unit.pass_results = vec[pass_result]()
    } else if opt_level == "O1" {
        unit.pass_results = run_pass_pipeline(*unit.optimized_graph, *minimal_optimization_pipeline())
    } else if opt_level == "O2" {
        unit.pass_results = run_pass_pipeline(*unit.optimized_graph, *default_optimization_pipeline())
    } else if opt_level == "O3" {
        unit.pass_results = run_pass_pipeline(*unit.optimized_graph, *aggressive_optimization_pipeline())
    }

    if cfg.enable_validation {
        if !unit.optimized_graph.is_valid() {
            return unit
        }
    }

    unit.stats.optimized_op_count = unit.optimized_graph.operation_count()
    unit.stats.optimized_memory = unit.optimized_graph.total_memory_bytes()

    unit
}

func (graph_compiler* compiler) dump_compilation_stats(*compilation_unit unit) string {
    s = ""
    s = s + "=== Compilation Statistics ===\n"
    s = s + "Unit: " + unit.unit_name + "\n"
    s = s + "Original operations: " + unit.stats.original_op_count as string + "\n"
    s = s + "Optimized operations: " + unit.stats.optimized_op_count as string + "\n"
    s = s + "Ops reduced: " + (unit.stats.original_op_count - unit.stats.optimized_op_count) as string + "\n"
    s = s + "Optimization ratio: " + (unit.get_optimization_ratio() * 100.0) as int as string + "%\n"
    s = s + "\n"
    s = s + "Original memory: " + unit.stats.original_memory as string + " bytes\n"
    s = s + "Optimized memory: " + unit.stats.optimized_memory as string + " bytes\n"
    s = s + "Memory saved: " + (unit.stats.original_memory - unit.stats.optimized_memory) as string + " bytes\n"
    s = s + "Memory saving ratio: " + (unit.get_memory_saving_ratio() * 100.0) as int as string + "%\n"
    s = s + "\n"
    s = s + "Estimated speedup: " + unit.speedup_estimate() as string + "x\n"
    s = s + "Optimization time: " + unit.stats.optimization_time_ms as string + " ms\n"
    s
}
