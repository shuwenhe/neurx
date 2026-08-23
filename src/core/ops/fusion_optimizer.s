package ops

struct kernel_fusion_opportunity {
    string opportunity_id
    vec[string] fusible_ops
    int potential_memory_reduction
    int potential_flops_reduction
    float fusion_benefit_ratio
}

struct operation_dependency {
    string producer_op
    string consumer_op
    int output_size
}

struct operation_fusion_graph {
    vec[string] nodes
    vec[operation_dependency] edges
    int num_nodes
    int num_edges
}

struct fused_kernel_config {
    string fused_op_name
    vec[string] component_ops
    int total_flops
    int total_memory_access
    int estimated_latency_us
    bool memory_bound
    float compute_bound_ratio
}

func detect_fusion_opportunities(operation_registry reg, vec[string] operation_sequence) vec[kernel_fusion_opportunity] {
    opportunities := vec[kernel_fusion_opportunity]{}

    i := 0
    while i < operation_sequence.len() - 1 {
        op_id1 := operation_sequence[i]
        op_id2 := operation_sequence[i + 1]

        if reg.has_operation(op_id1) && reg.has_operation(op_id2) {
            op1 := reg.get_operation(op_id1)
            op2 := reg.get_operation(op_id2)

            can_fuse := false
            if op1.op_type == operation_type::element_wise && op2.op_type == operation_type::element_wise {
                can_fuse = true
            }
            if op1.op_type == operation_type::normalization && op2.op_type == operation_type::activation {
                can_fuse = true
            }

            if can_fuse {
                component_ops := vec[string]{op_id1, op_id2}
                opp := kernel_fusion_opportunity {
                    opportunity_id: op_id1 + "_" + op_id2,
                    fusible_ops: component_ops,
                    potential_memory_reduction: 1000,
                    potential_flops_reduction: 100,
                    fusion_benefit_ratio: 1.2,
                }
                opportunities.push(opp)
            }
        }

        i = i + 1
    }

    opportunities
}

struct operation_scheduler {
    operation_registry registry
    vec[string] operation_queue
    operation_fusion_graph fusion_graph
    int num_scheduled_ops
    bool optimization_enabled
}

func new_operation_scheduler(operation_registry reg) operation_scheduler {
    operation_scheduler {
        registry: reg,
        operation_queue: vec[string]{},
        fusion_graph: operation_fusion_graph {
            nodes: vec[string]{},
            edges: vec[operation_dependency]{},
            num_nodes: 0,
            num_edges: 0,
        },
        num_scheduled_ops: 0,
        optimization_enabled: true,
    }
}

func (operation_scheduler* sched) add_operation(string op_id) bool {
    if sched.registry.has_operation(op_id) {
        sched.operation_queue.push(op_id)
        sched.fusion_graph.nodes.push(op_id)
        sched.fusion_graph.num_nodes = sched.fusion_graph.num_nodes + 1
        true
    }

    false
}

func (operation_scheduler* sched) add_dependency(string producer_op, string consumer_op, int output_size) bool {
    dep := operation_dependency {
        producer_op: producer_op,
        consumer_op: consumer_op,
        output_size: output_size,
    }

    sched.fusion_graph.edges.push(dep)
    sched.fusion_graph.num_edges = sched.fusion_graph.num_edges + 1
    true
}

func (operation_scheduler* sched) optimize_schedule() vec[string] {
    if !sched.optimization_enabled {
        sched.operation_queue
    }

    optimized_schedule := vec[string]{}

    opportunities := detect_fusion_opportunities(sched.registry, sched.operation_queue)

    i := 0
    while i < opportunities.len() {
        fused_idx := ""
        for op_id in opportunities[i].fusible_ops {
            if fused_idx == "" {
                fused_idx = op_id
            }
        }

        if fused_idx != "" {
            optimized_schedule.push(fused_idx)
        }

        i = i + 1
    }

    if optimized_schedule.len() == 0 {
        sched.operation_queue
    }

    optimized_schedule
}

func (operation_scheduler* sched) execute_schedule(compute_capability hw) bool {
    schedule := sched.optimize_schedule()

    i := 0
    while i < schedule.len() {
        op_id := schedule[i]
        op := sched.registry.get_operation(op_id)

        kernel := op.get_kernel_for_hardware(hw)
        if kernel.kernel_id == "" {
            false
        }

        sched.num_scheduled_ops = sched.num_scheduled_ops + 1
        i = i + 1
    }

    true
}

func (operation_scheduler* sched) get_schedule_stats() string {
    stats := "Scheduled Operations: " + string(sched.num_scheduled_ops) + "\n"
    stats = stats + "Total Operations: " + string(sched.operation_queue.len()) + "\n"
    stats = stats + "Dependencies: " + string(sched.fusion_graph.num_edges)
    stats
}
