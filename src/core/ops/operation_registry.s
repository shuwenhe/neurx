package ops
    element_wise
    reduction
    matmul
    gemm
    attention
    normalization
    activation
    fusion
    custom
}
    sm_70
    sm_75
    sm_80
    sm_90
    mi100
    mi200
    cpu
}

struct operation_metadata {
    string op_name
    operation_type op_type
    string[] input_types
    string[] output_types
    bool supports_fused_ops
    compute_capability[] supported_hardware
    int estimated_flops
}

struct operation_kernel {
    string kernel_id
    string kernel_name
    compute_capability target_hardware
    string kernel_code
    int register_count
    int shared_memory_size
    int num_threads_per_block
}

struct fused_operation {
    string fused_op_id
    string[] component_ops
    string fusion_name
    int estimated_flops_saved
    int estimated_memory_saved
}

struct custom_operation {
    string op_id
    string op_name
    operation_type op_type
    operation_metadata metadata
    operation_kernel[] kernels
    bool is_registered
    int64 registration_time
}

struct operation_registry {
    map[string, custom_operation] operations
    map[string, fused_operation] fused_ops
    int operation_count
    int fused_op_count
    string default_hardware
}

func new_operation_metadata(string name, operation_type op_type) operation_metadata {
    operation_metadata {
        op_name: name,
        op_type: op_type,
        input_types: string[]{},
        output_types: string[]{},
        supports_fused_ops: false,
        supported_hardware: compute_capability[]{},
        estimated_flops: 0,
    }
}

func new_operation_kernel(string kernel_id, string kernel_name, compute_capability hw) operation_kernel {
    operation_kernel {
        kernel_id: kernel_id,
        kernel_name: kernel_name,
        target_hardware: hw,
        kernel_code: "",
        register_count: 0,
        shared_memory_size: 0,
        num_threads_per_block: 256,
    }
}

func new_custom_operation(string op_id, string op_name, operation_type op_type) custom_operation {
    custom_operation {
        op_id: op_id,
        op_name: op_name,
        op_type: op_type,
        metadata: new_operation_metadata(op_name, op_type),
        kernels: operation_kernel[]{},
        is_registered: false,
        registration_time: 0,
    }
}

func new_operation_registry(string default_hw) operation_registry {
    operation_registry {
        operations: map[string, custom_operation]{},
        fused_ops: map[string, fused_operation]{},
        operation_count: 0,
        fused_op_count: 0,
        default_hardware: default_hw,
    }
}

func (custom_operation* op) add_kernel(operation_kernel kernel) bool {
    op.kernels = append(op.kernels, kernel)
    true
}

func (custom_operation* op) add_input_type(string input_type) () {
    op.metadata.input_types = append(op.metadata.input_types, input_type)
}

func (custom_operation* op) add_output_type(string output_type) () {
    op.metadata.output_types = append(op.metadata.output_types, output_type)
}

func (custom_operation* op) add_supported_hardware(compute_capability hw) () {
    op.metadata.supported_hardware = append(op.metadata.supported_hardware, hw)
}

func (custom_operation* op) set_metadata(operation_metadata meta) () {
    op.metadata = meta
}

func (custom_operation* op) get_kernel_for_hardware(compute_capability hw) operation_kernel {
    i := 0
    for i < len(op.kernels) {
        if op.kernels[i].target_hardware == hw {
            op.kernels[i]
        }
        i = i + 1
    }
    new_operation_kernel("", "", hw)
}

func (operation_registry* reg) register_operation(custom_operation op) bool {
    if op.op_id in reg.operations {
        false
    }
    reg.operations[op.op_id] = op
    reg.operation_count = reg.operation_count + 1
    true
}

func (operation_registry* reg) unregister_operation(string op_id) bool {
    if op_id in reg.operations {
        del reg.operations[op_id]
        reg.operation_count = reg.operation_count - 1
        true
    }
    false
}

func (operation_registry* reg) has_operation(string op_id) bool {
    op_id in reg.operations
}

func (operation_registry* reg) get_operation(string op_id) custom_operation {
    if op_id in reg.operations {
        reg.operations[op_id]
    }
    new_custom_operation("", "", operation_type_custom)
}

func (operation_registry* reg) register_fused_operation(string fused_id, string[] component_ops, string fusion_name) bool {
    if fused_id in reg.fused_ops {
        false
    }
    fused := fused_operation {
        fused_op_id: fused_id,
        component_ops: component_ops,
        fusion_name: fusion_name,
        estimated_flops_saved: 0,
        estimated_memory_saved: 0,
    }
    reg.fused_ops[fused_id] = fused
    reg.fused_op_count = reg.fused_op_count + 1
    true
}

func (operation_registry* reg) has_fused_operation(string fused_id) bool {
    fused_id in reg.fused_ops
}

func (operation_registry* reg) get_fused_operation(string fused_id) fused_operation {
    if fused_id in reg.fused_ops {
        reg.fused_ops[fused_id]
    }
    fused_operation {
        fused_op_id: "",
        component_ops: string[]{},
        fusion_name: "",
        estimated_flops_saved: 0,
        estimated_memory_saved: 0,
    }
}

func (operation_registry* reg) list_operations() string[] {
    result := string[]{}
    for op_id in reg.operations.keys() {
        result = append(result, op_id)
    }
    result
}

func (operation_registry* reg) list_fused_operations() string[] {
    result := string[]{}
    for fused_id in reg.fused_ops.keys() {
        result = append(result, fused_id)
    }
    result
}

func (operation_registry* reg) find_operations_by_type(operation_type op_type) string[] {
    result := string[]{}
    for op_id in reg.operations.keys() {
        op := reg.get_operation(op_id)
        if op.op_type == op_type {
            result = append(result, op_id)
        }
    }
    result
}

func (operation_registry* reg) find_operations_for_hardware(compute_capability hw) string[] {
    result := string[]{}
    for op_id in reg.operations.keys() {
        op := reg.get_operation(op_id)
        i := 0
        for i < len(op.metadata.supported_hardware) {
            if op.metadata.supported_hardware[i] == hw {
                result = append(result, op_id)
            }
            i = i + 1
        }
    }
    result
}

func (operation_registry* reg) get_stats() string {
    stats := "Total Operations: " + string(reg.operation_count) + "\n"
    stats = stats + "Total Fused Operations: " + string(reg.fused_op_count)
    stats
}
