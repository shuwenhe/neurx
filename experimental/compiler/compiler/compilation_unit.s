package neurx.experimental.compiler.compiler.compilation_unit

use neurx.experimental.compiler.ir.graph.computation_graph
use neurx.experimental.compiler.compiler.pass_manager.{pass_pipeline, pass_result}

struct compilation_stats {
    int original_op_count
    int optimized_op_count
    int original_memory
    int optimized_memory
    int optimization_time_ms
}

struct compilation_unit {
    string unit_name
    computation_graph original_graph
    computation_graph optimized_graph
    pass_pipeline pipeline
    pass_result[] pass_results
    compilation_stats stats
}

struct compilation_config {
    string opt_level
    bool enable_profiling
    bool enable_validation
    int max_optimization_iterations
}

func default_compilation_config() compilation_config {
    compilation_config {
        opt_level: "O2",
        enable_profiling: false,
        enable_validation: true,
        max_optimization_iterations: 5,
    }
}

func new_compilation_unit(string name, computation_graph g) compilation_unit {
    compilation_unit {
        unit_name: name,
        original_graph: g,
        optimized_graph: g,
        pipeline: pass_result[](),
        pass_results: pass_result[](),
        stats: compilation_stats {
            original_op_count: 0,
            optimized_op_count: 0,
            original_memory: 0,
            optimized_memory: 0,
            optimization_time_ms: 0,
        },
    }
}

func (compilation_unit* cu) get_optimization_ratio() float {
    if cu.stats.original_op_count == 0 {
        return 1.0
    }
    (cu.stats.original_op_count - cu.stats.optimized_op_count) as float / cu.stats.original_op_count as float
}

func (compilation_unit* cu) get_memory_saving_ratio() float {
    if cu.stats.original_memory == 0 {
        return 0.0
    }
    (cu.stats.original_memory - cu.stats.optimized_memory) as float / cu.stats.original_memory as float
}

func (compilation_unit* cu) speedup_estimate() float {
    ratio = cu.get_optimization_ratio()
    if ratio < 0.1 {
        return 1.5
    } else if ratio < 0.3 {
        return 1.3
    } else {
        return 1.1
    }
}

func (compilation_unit* cu) is_valid() bool {
    cu.optimized_graph.is_valid()
}

func (compilation_unit* cu) summary_string() string {
    s = ""
    s = s + "Compilation Unit: " + cu.unit_name + "\n"
    s = s + "Original ops: " + cu.stats.original_op_count as string + "\n"
    s = s + "Optimized ops: " + cu.stats.optimized_op_count as string + "\n"
    s = s + "Optimization ratio: " + cu.get_optimization_ratio() as string + "\n"
    s = s + "Memory saved: " + (cu.stats.original_memory - cu.stats.optimized_memory) as string + " bytes\n"
    s = s + "Estimated speedup: " + cu.speedup_estimate() as string + "x\n"
    s
}
