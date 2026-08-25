package neurx.experimental.compiler.passes.op_fusion

use neurx.experimental.compiler.ir.graph.computation_graph
use neurx.experimental.compiler.ir.operation.op_type


    conv_bn,
    conv_relu,
    linear_relu,
    bn_relu,
    fc_gelu,
}

struct fusion_candidate {
    int first_op_id
    int second_op_id
    fusion_pattern pattern
}

struct fusion_result {
    int fused_ops
    vec[int] removed_ops
    bool success
}

func can_fuse_ops(op_type first_op, op_type second_op) bool {
    match (first_op, second_op) {
        (op_type::convolution, op_type::batch_norm): true,
        (op_type::convolution, op_type::relu): true,
        (op_type::matrix_multiply, op_type::relu): true,
        (op_type::batch_norm, op_type::relu): true,
        (op_type::matrix_multiply, op_type::gelu): true,
        default: false,
    }
}

func get_fusion_pattern(op_type first_op, op_type second_op) option[fusion_pattern] {
    match (first_op, second_op) {
        (op_type::convolution, op_type::batch_norm): option::some(fusion_pattern::conv_bn),
        (op_type::convolution, op_type::relu): option::some(fusion_pattern::conv_relu),
        (op_type::matrix_multiply, op_type::relu): option::some(fusion_pattern::linear_relu),
        (op_type::batch_norm, op_type::relu): option::some(fusion_pattern::bn_relu),
        (op_type::matrix_multiply, op_type::gelu): option::some(fusion_pattern::fc_gelu),
        default: option::none,
    }
}

func find_fusion_candidates(*computation_graph g) vec[fusion_candidate] {
    candidates = vec[fusion_candidate]()

    for i in range(g.operations.len() - 1) {
        first_op = g.operations[i]

        for j in range(i + 1, g.operations.len()) {
            second_op = g.operations[j]

            if can_fuse_ops(first_op.op_kind, second_op.op_kind) {
                consumers = g.find_consumers(first_op.output_ids[0])

                for consumer in consumers {
                    if consumer.id == second_op.id {
                        if get_fusion_pattern(first_op.op_kind, second_op.op_kind) is option::some(pattern) {
                            candidates.push(fusion_candidate {
                                first_op_id: first_op.id,
                                second_op_id: second_op.id,
                                pattern: pattern,
                            })
                        }
                    }
                }
            }
        }
    }

    candidates
}

func apply_op_fusion(*mut computation_graph g) fusion_result {
    candidates = find_fusion_candidates(g)
    removed = vec[int]()

    for candidate in candidates {
        removed.push(candidate.second_op_id)
    }

    fusion_result {
        fused_ops: candidates.len(),
        removed_ops: removed,
        success: true,
    }
}

func should_fuse_before_activation(op_type op_kind) bool {
    match op_kind {
        op_type::relu | op_type::gelu => true,
        default => false,
    }
}

func is_memory_efficient_to_fuse(*computation_graph g, int first_id, int second_id) bool {
    switch g.get_operation(first_id) {
        option::some(first_op): {
            switch g.get_operation(second_id) {
                option::some(second_op): {
                    if first_op.output_ids.len() == 1 && second_op.input_ids.len() == 1 {
                        output_id = first_op.output_ids[0]
                        return g.find_consumers(output_id).len() == 1
                    }
                    false
                },
                option::none: false,
            }
        },
        option::none: false,
    }
}
