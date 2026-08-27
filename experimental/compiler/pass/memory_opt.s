package neurx.experimental.compiler.passes.memory_opt

use neurx.experimental.compiler.ir.graph.computation_graph

struct memory_usage {
    int peak_memory
    int total_memory
    int[] memory_per_value
}

struct memory_opt_result {
    int memory_saved
    int reuse_candidates
    bool success
}

func compute_memory_usage(*computation_graph g) memory_usage {
    memory_per_value = new int[len(g.values)]
    int total = 0
    int peak = 0

    for i in range(len(g.values)) {
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

func find_reusable_values(*computation_graph g, *int[] lifetime) int[] {
    reusable = int[]()

    for i in range(len(g.values)) {
        for j in range(i + 1, len(g.values)) {
            vt1 = g.values[i]
            vt2 = g.values[j]

            if vt1.dtype == vt2.dtype && vt1.total_elements() == vt2.total_elements() {
                if lifetime[i] > 0 && lifetime[j] > lifetime[i] {
                    reusable = append(reusable, j)
                }
            }
        }
    }

    reusable
}

func compute_value_lifetime(*computation_graph g) int[] {
    lifetime = new int[len(g.values)]
    for i in range(len(g.values)) {
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

func apply_memory_optimization(*computation_graph g) memory_opt_result {
    usage_before = compute_memory_usage(g)
    lifetime = compute_value_lifetime(g)
    reusable = find_reusable_values(g, *lifetime)

    int saved = 0
    for reuse_id in reusable {
        saved = saved + usage_before.memory_per_value[reuse_id]
    }

    memory_opt_result {
        memory_saved: saved,
        reuse_candidates: len(reusable),
        success: true,
    }
}

func is_value_needed_later(*computation_graph g, int value_id, int current_step) bool {
    consumers = g.find_consumers(value_id)
    len(consumers) > 0
}

func can_reuse_buffer(*computation_graph g, int source_id, int target_id) bool {
    if source_id == target_id {
        return false
    }

    switch g.get_value(source_id) {
        some(src_vt): {
            switch g.get_value(target_id) {
                some(tgt_vt): {
                    src_vt.dtype == tgt_vt.dtype && src_vt.total_elements() == tgt_vt.total_elements()
                },
                nil: false,
            }
        },
        nil: false,
    }
}
