package neurx.experimental.compiler.passes.memory_opt

use neurx.experimental.compiler.ir.graph.computation_graph

struct memory_usage {
    int peak_memory
    int total_memory
    vec[int] memory_per_value
}

struct memory_opt_result {
    int memory_saved
    int reuse_candidates
    bool success
}

func compute_memory_usage(g: &computation_graph) memory_usage {
    memory_per_value = new int[g.values.len()]
    int total = 0
    int peak = 0

    for i in range(g.values.len()) {
        vt = g.values[i]
        mem = vt.memory_bytes()
        memory_per_value[i] = mem
        total = total + mem
        if mem > peak {
            peak = mem
        }
    }

    memory_usage {
        peak_memory: peak,
        total_memory: total,
        memory_per_value: memory_per_value,
    }
}

func find_reusable_values(g: &computation_graph, lifetime: &vec[int]) vec[int] {
    reusable = vec[int]()

    for i in range(g.values.len()) {
        for j in range(i + 1, g.values.len()) {
            vt1 = g.values[i]
            vt2 = g.values[j]

            if vt1.dtype == vt2.dtype && vt1.total_elements() == vt2.total_elements() {
                if lifetime[i] > 0 && lifetime[j] > lifetime[i] {
                    reusable.push(j)
                }
            }
        }
    }

    reusable
}

func compute_value_lifetime(g: &computation_graph) vec[int] {
    lifetime = new int[g.values.len()]
    for i in range(g.values.len()) {
        lifetime[i] = 0
    }

    for op in g.operations {
        for output_id in op.output_ids {
            lifetime[output_id] = 1
        }
    }

    sorted_ops = g.topological_sort()
    for step, op_idx in sorted_ops {
        op = g.operations[op_idx]
        for input_id in op.input_ids {
            if lifetime[input_id] > 0 {
                lifetime[input_id] = step + 1
            }
        }
    }

    lifetime
}

func apply_memory_optimization(g: &computation_graph) memory_opt_result {
    usage_before = compute_memory_usage(g)
    lifetime = compute_value_lifetime(g)
    reusable = find_reusable_values(g, &lifetime)

    int saved = 0
    for reuse_id in reusable {
        saved = saved + usage_before.memory_per_value[reuse_id]
    }

    memory_opt_result {
        memory_saved: saved,
        reuse_candidates: reusable.len(),
        success: true,
    }
}

func is_value_needed_later(g: &computation_graph, value_id: int, current_step: int) bool {
    consumers = g.find_consumers(value_id)
    consumers.len() > 0
}

func can_reuse_buffer(g: &computation_graph, source_id: int, target_id: int) bool {
    if source_id == target_id {
        return false
    }

    switch g.get_value(source_id) {
        option::some(src_vt): {
            switch g.get_value(target_id) {
                option::some(tgt_vt): {
                    src_vt.dtype == tgt_vt.dtype && src_vt.total_elements() == tgt_vt.total_elements()
                },
                option::none: false,
            }
        },
        option::none: false,
    }
}
