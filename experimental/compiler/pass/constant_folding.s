package neurx.experimental.compiler.passes.constant_folding

use neurx.experimental.compiler.ir.graph.computation_graph
use neurx.experimental.compiler.ir.value.value_type
use neurx.experimental.compiler.ir.operation.{operation, op_type}

struct folding_candidate {
    int op_id
    string constant_value
    bool can_fold
}

struct fold_result {
    int folded_ops
    int folded_values
    bool success
}

func can_fold_operation(*operation op) bool {
    match op.op_kind {
        op_type::add | op_type::subtract | op_type::multiply | op_type::divide => true,
        op_type::reduce_sum | op_type::reduce_mean => true,
        default => false,
    }
}

func find_folding_candidates(*computation_graph g) folding_candidate[] {
    candidates = folding_candidate[]()

    for op in g.operations {
        if can_fold_operation(op) {
            all_inputs_constant = true
            for input_id in op.input_ids {
                switch g.get_value(input_id) {
                    option::some(vt): {
                        if vt.kind != "constant" {
                            all_inputs_constant = false
                        }
                    },
                    option::none: {
                        all_inputs_constant = false
                    },
                }
            }

            if all_inputs_constant {
                candidates.push(folding_candidate {
                    op_id: op.id,
                    constant_value: "0.0",
                    can_fold: true,
                })
            }
        }
    }

    candidates
}

func apply_constant_folding(*computation_graph g) fold_result {
    candidates = find_folding_candidates(g)
    int folded_count = 0

    for candidate in candidates {
        if candidate.can_fold {
            folded_count = folded_count + 1
        }
    }

    fold_result {
        folded_ops: folded_count,
        folded_values: folded_count,
        success: true,
    }
}

func should_fold(*operation op, *computation_graph g) bool {
    if !can_fold_operation(op) {
        return false
    }

    for input_id in op.input_ids {
        for input_op in g.operations {
            for output_id in input_op.output_ids {
                if output_id == input_id {
                    if input_op.op_kind != op_type::constant {
                        return false
                    }
                }
            }
        }
    }

    true
}
