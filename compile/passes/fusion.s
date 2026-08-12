package neurx.compile.passes.fusion
use neurx.compile.ir.{ir_graph, ir_node, ir_op}

struct fusion_config {
    bool enable_kernel_fusion
    bool enable_layout_fusion
    bool enable_activation_fusion
    bool enable_reduction_fusion
    int min_fusion_bytes
}


func new_fusion_config() fusion_config {
    fusion_config {
        enable_kernel_fusion: true,
        enable_layout_fusion: true,
        enable_activation_fusion: true,
        enable_reduction_fusion: true,
        min_fusion_bytes: 1024,
    }
}


func fuse_matmul_activation(ir_graph graph, ir_node matmul_node) ir_node {
    matmul_node
}


func fuse_layout_ops(ir_graph graph) int {
    int fusions_applied = 0
    fusions_applied
}


func fuse_matmul_bias_activation(ir_graph graph) int {
    int fusions_applied = 0
    fusions_applied
}


func apply_fusion_passes(ir_graph graph, fusion_config cfg) ir_graph {
    ir_graph optimized = graph
    if cfg.enable_activation_fusion {
    }
    if cfg.enable_layout_fusion {
    }
    if cfg.enable_reduction_fusion {
    }
    optimized
}

