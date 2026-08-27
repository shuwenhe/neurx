package neurx.experimental.compiler.compiler.pass_manager

use neurx.experimental.compiler.ir.graph.computation_graph
use neurx.experimental.compiler.passes.constant_folding.{apply_constant_folding, fold_result}
use neurx.experimental.compiler.passes.op_fusion.{apply_op_fusion, fusion_result}
use neurx.experimental.compiler.passes.dead_code_elim.{remove_dead_code, dead_code_result}
use neurx.experimental.compiler.passes.memory_opt.{apply_memory_optimization, memory_opt_result}


    constant_folding,
    op_fusion,
    dead_code_elim,
    memory_opt,
}

struct pass_config {
    pass_type pass_kind
    bool enabled
    int priority
    string description
}

struct pass_result {
    pass_type pass_kind
    bool success
    string message
}

struct pass_pipeline {
    string name
    pass_config[] passes
}

func default_optimization_pipeline() pass_pipeline {
    passes = pass_config[]()

    passes.push(pass_config {
        pass_kind: pass_type::constant_folding,
        enabled: true,
        priority: 1,
        description: "fold constant expressions",
    })

    passes.push(pass_config {
        pass_kind: pass_type::op_fusion,
        enabled: true,
        priority: 2,
        description: "fuse compatible operations",
    })

    passes.push(pass_config {
        pass_kind: pass_type::dead_code_elim,
        enabled: true,
        priority: 3,
        description: "eliminate dead code",
    })

    passes.push(pass_config {
        pass_kind: pass_type::memory_opt,
        enabled: true,
        priority: 4,
        description: "optimize memory usage",
    })

    pass_pipeline {
        name: "default_optimization",
        passes: passes,
    }
}

func aggressive_optimization_pipeline() pass_pipeline {
    passes = pass_config[]()

    passes.push(pass_config {
        pass_kind: pass_type::constant_folding,
        enabled: true,
        priority: 1,
        description: "fold constant expressions",
    })

    passes.push(pass_config {
        pass_kind: pass_type::op_fusion,
        enabled: true,
        priority: 2,
        description: "fuse compatible operations",
    })

    passes.push(pass_config {
        pass_kind: pass_type::memory_opt,
        enabled: true,
        priority: 3,
        description: "optimize memory usage",
    })

    passes.push(pass_config {
        pass_kind: pass_type::dead_code_elim,
        enabled: true,
        priority: 4,
        description: "eliminate dead code",
    })

    pass_pipeline {
        name: "aggressive_optimization",
        passes: passes,
    }
}

func minimal_optimization_pipeline() pass_pipeline {
    passes = pass_config[]()

    passes.push(pass_config {
        pass_kind: pass_type::constant_folding,
        enabled: true,
        priority: 1,
        description: "fold constant expressions",
    })

    pass_pipeline {
        name: "minimal_optimization",
        passes: passes,
    }
}

func apply_pass(*computation_graph g, pass_type pass_kind) pass_result {
    match pass_kind {
        pass_type::constant_folding: {
            result = apply_constant_folding(g)
            pass_result {
                pass_kind: pass_kind,
                success: result.success,
                message: "folded " + result.folded_ops as string + " operations",
            }
        },
        pass_type::op_fusion: {
            result = apply_op_fusion(g)
            pass_result {
                pass_kind: pass_kind,
                success: result.success,
                message: "fused " + result.fused_ops as string + " operations",
            }
        },
        pass_type::dead_code_elim: {
            result = remove_dead_code(g)
            pass_result {
                pass_kind: pass_kind,
                success: result.success,
                message: "removed " + result.removed_ops as string + " dead operations",
            }
        },
        pass_type::memory_opt: {
            result = apply_memory_optimization(g)
            pass_result {
                pass_kind: pass_kind,
                success: result.success,
                message: "saved " + result.memory_saved as string + " bytes of memory",
            }
        },
    }
}

func run_pass_pipeline(*computation_graph g, *pass_pipeline pipeline) pass_result[] {
    results = pass_result[]()

    for pass_cfg in pipeline.passes {
        if pass_cfg.enabled {
            result = apply_pass(g, pass_cfg.pass_kind)
            results = append(results, result)
        }
    }

    results
}
