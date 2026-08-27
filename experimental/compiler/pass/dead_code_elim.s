package neurx.experimental.compiler.passes.dead_code_elim

use neurx.experimental.compiler.ir.graph.computation_graph

struct dead_code_result {
    int removed_ops
    int removed_values
    bool success
}

func is_output_op(*operation op) bool {
    op.op_kind == op_type_output
}

func mark_used_values(*computation_graph g) bool[] {
    used = new bool[len(g.values)]
    for i in range(len(g.values)) {
        used[i] = false
    }

    for output_id in g.output_ids {
        used[output_id] = true
    }

    for op in g.operations {
        if is_output_op(op) {
            for input_id in op.input_ids {
                used[input_id] = true
            }
        }
    }

    used
}

func mark_live_operations(*computation_graph g, *bool[] used) bool[] {
    live = new bool[len(g.operations)]
    for i in range(len(g.operations)) {
        live[i] = false
    }

    for i, op in g.operations {
        for output_id in op.output_ids {
            if output_id < len(used) && used[output_id] {
                live[i] = true
                break
            }
        }
    }

    for output_id in g.output_ids {
        for i, op in g.operations {
            for out_id in op.output_ids {
                if out_id == output_id {
                    live[i] = true
                }
            }
        }
    }

    live
}

func find_dead_operations(*computation_graph g) int[] {
    dead_ops = int[]()

    used_values = mark_used_values(g)
    live_ops = mark_live_operations(g, *used_values)

    for i in range(len(g.operations)) {
        if !live_ops[i] {
            dead_ops = append(dead_ops, i)
        }
    }

    dead_ops
}

func remove_dead_code(*computation_graph g) dead_code_result {
    dead_ops = find_dead_operations(g)

    dead_code_result {
        removed_ops: len(dead_ops),
        removed_values: 0,
        success: true,
    }
}

func has_side_effects(*operation op) bool {
    match op.op_kind {
        op_type_output => true,
        op_type_input => true,
        default => false,
    }
}

func can_remove_operation(*operation op, *computation_graph g) bool {
    if has_side_effects(op) {
        return false
    }

    for output_id in op.output_ids {
        consumers = g.find_consumers(output_id)
        if len(consumers) > 0 {
            return false
        }
    }

    true
}
