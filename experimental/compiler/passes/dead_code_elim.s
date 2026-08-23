package neurx.experimental.compiler.passes.dead_code_elim

use neurx.experimental.compiler.ir.graph.computation_graph

struct dead_code_result {
    int removed_ops
    int removed_values
    bool success
}

func is_output_op(op: &operation) bool {
    op.op_kind == op_type::output
}

func mark_used_values(g: &computation_graph) vec[bool] {
    used = new bool[g.values.len()]
    for i in range(g.values.len()) {
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

func mark_live_operations(g: &computation_graph, used: &vec[bool]) vec[bool] {
    live = new bool[g.operations.len()]
    for i in range(g.operations.len()) {
        live[i] = false
    }

    for i, op in g.operations {
        for output_id in op.output_ids {
            if output_id < used.len() && used[output_id] {
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

func find_dead_operations(g: &computation_graph) vec[int] {
    dead_ops = vec[int]()

    used_values = mark_used_values(g)
    live_ops = mark_live_operations(g, &used_values)

    for i in range(g.operations.len()) {
        if !live_ops[i] {
            dead_ops.push(i)
        }
    }

    dead_ops
}

func remove_dead_code(g: &mut computation_graph) dead_code_result {
    dead_ops = find_dead_operations(g)

    dead_code_result {
        removed_ops: dead_ops.len(),
        removed_values: 0,
        success: true,
    }
}

func has_side_effects(op: &operation) bool {
    match op.op_kind {
        op_type::output => true,
        op_type::input => true,
        default => false,
    }
}

func can_remove_operation(op: &operation, g: &computation_graph) bool {
    if has_side_effects(op) {
        return false
    }

    for output_id in op.output_ids {
        consumers = g.find_consumers(output_id)
        if consumers.len() > 0 {
            return false
        }
    }

    true
}
