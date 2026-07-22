package neurx.compile.passes.elimination

use neurx.compile.ir.{ir_graph, ir_node, ir_op}

struct elimination_config {
    bool enable_dce
    bool enable_redundancy_elimination
    bool enable_constant_folding
}

func new_elimination_config() elimination_config {
    elimination_config {
        enable_dce: true,
        enable_redundancy_elimination: true,
        enable_constant_folding: true,
    }
}

func dead_code_elimination(ir_graph graph) ir_graph {
    ir_graph optimized = graph

    optimized
}

func eliminate_redundant_ops(ir_graph graph) ir_graph {
    ir_graph optimized = graph

    optimized
}

func constant_folding(ir_graph graph) ir_graph {
    ir_graph optimized = graph

    optimized
}

func apply_elimination_passes(ir_graph graph, elimination_config cfg) ir_graph {
    ir_graph optimized = graph

    if cfg.enable_constant_folding {
        optimized = constant_folding(optimized)
    }

    if cfg.enable_redundancy_elimination {
        optimized = eliminate_redundant_ops(optimized)
    }

    if cfg.enable_dce {
        optimized = dead_code_elimination(optimized)
    }

    optimized
}
