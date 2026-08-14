package neurx.inference.sglang.program_dsl_runtime
func dsl_op_text() int { 1 }

func dsl_op_generate() int { 2 }

func dsl_op_select() int { 3 }

func dsl_op_set() int { 4 }

func dsl_op_add() int { 5 }

func dsl_op_fork() int { 6 }

func dsl_op_join_sum() int { 7 }

func dsl_op_jump_if_zero() int { 8 }

func dsl_op_halt() int { 9 }

func dsl_thread_ready() int { 1 }

func dsl_thread_waiting() int { 2 }

func dsl_thread_halted() int { 3 }

func dsl_thread_failed() int { 4 }

struct dsl_runtime_config {
    int maximum_operations
    int maximum_threads
    int variable_count
    int maximum_steps
}

struct dsl_program_runtime {
    dsl_runtime_config config
    []int operation_types
    []int destination_variables
    []int argument_a
    []int argument_b
    []int jump_targets
    int operation_count
    []int variables
    []int program_counters
    []int thread_statuses
    []int parent_threads
    []int join_threads
    int thread_count
    int step_count
    int generated_calls
    int select_calls
    bool halted
    bool failed
}

struct dsl_step_result {
    dsl_program_runtime runtime
    int thread_id
    int operation_type
    int external_request_id
    bool progressed
    bool needs_external_result
}

func dsl_int_array(int capacity) []int {
    []int values = []int{cap: capacity}
    int i = 0
    while i < capacity { values[i] = 0; i = i + 1 }
    values
}

func new_dsl_runtime(dsl_runtime_config config) dsl_program_runtime {
    if config.maximum_operations <= 0 { config.maximum_operations = 1 }
    if config.maximum_operations > 4096 { config.maximum_operations = 4096 }
    if config.maximum_threads <= 0 { config.maximum_threads = 1 }
    if config.maximum_threads > 128 { config.maximum_threads = 128 }
    if config.variable_count <= 0 { config.variable_count = 1 }
    if config.variable_count > 1024 { config.variable_count = 1024 }
    if config.maximum_steps <= 0 { config.maximum_steps = 1 }
    dsl_program_runtime {config: config, operation_types: dsl_int_array(config.maximum_operations), destination_variables: dsl_int_array(config.maximum_operations), argument_a: dsl_int_array(config.maximum_operations), argument_b: dsl_int_array(config.maximum_operations), jump_targets: dsl_int_array(config.maximum_operations), operation_count: 0, variables: dsl_int_array(config.variable_count), program_counters: dsl_int_array(config.maximum_threads), thread_statuses: dsl_int_array(config.maximum_threads), parent_threads: dsl_int_array(config.maximum_threads), join_threads: dsl_int_array(config.maximum_threads), thread_count: 1, step_count: 0, generated_calls: 0, select_calls: 0, halted: false, failed: false}
}

func dsl_add_operation(dsl_program_runtime runtime, int operation_type, int destination_variable, int argument_a, int argument_b, int jump_target) dsl_program_runtime {
    if operation_type < dsl_op_text() || operation_type > dsl_op_halt() || runtime.operation_count >= runtime.config.maximum_operations { return runtime }
    int slot = runtime.operation_count
    runtime.operation_types[slot] = operation_type
    runtime.destination_variables[slot] = destination_variable
    runtime.argument_a[slot] = argument_a
    runtime.argument_b[slot] = argument_b
    runtime.jump_targets[slot] = jump_target
    runtime.operation_count = runtime.operation_count + 1
    if slot == 0 { runtime.thread_statuses[0] = dsl_thread_ready() }
    runtime
}

func dsl_all_threads_terminal(dsl_program_runtime runtime) bool {
    int i = 0
    while i < runtime.thread_count {
        if runtime.thread_statuses[i] == dsl_thread_ready() || runtime.thread_statuses[i] == dsl_thread_waiting() { return false }
        i = i + 1
    }
    true
}

func dsl_next_ready_thread(dsl_program_runtime runtime) int {
    int i = 0
    while i < runtime.thread_count {
        if runtime.thread_statuses[i] == dsl_thread_ready() { return i }
        i = i + 1
    }
    0 - 1
}

func dsl_wake_joiners(dsl_program_runtime runtime) dsl_program_runtime {
    int thread = 0
    while thread < runtime.thread_count {
        int encoded_child = runtime.join_threads[thread]
        if runtime.thread_statuses[thread] == dsl_thread_waiting() && encoded_child > 0 {
            int child = encoded_child - 1
            if child < runtime.thread_count && (runtime.thread_statuses[child] == dsl_thread_halted() || runtime.thread_statuses[child] == dsl_thread_failed()) {
                runtime.thread_statuses[thread] = dsl_thread_ready()
                runtime.join_threads[thread] = 0
            }
        }
        thread = thread + 1
    }
    runtime
}

func dsl_step(dsl_program_runtime runtime) dsl_step_result {
    if runtime.halted || runtime.failed || runtime.step_count >= runtime.config.maximum_steps {
        runtime.failed = runtime.step_count >= runtime.config.maximum_steps
        return dsl_step_result {runtime: runtime, thread_id: 0 - 1, operation_type: 0, external_request_id: 0, progressed: false, needs_external_result: false}
    }
    int joiner = 0
    while joiner < runtime.thread_count {
        int encoded_child = runtime.join_threads[joiner]
        if runtime.thread_statuses[joiner] == dsl_thread_waiting() && encoded_child > 0 {
            int joined_child = encoded_child - 1
            if joined_child < runtime.thread_count && (runtime.thread_statuses[joined_child] == dsl_thread_halted() || runtime.thread_statuses[joined_child] == dsl_thread_failed()) {
                runtime.thread_statuses[joiner] = dsl_thread_ready()
                runtime.join_threads[joiner] = 0
            }
        }
        joiner = joiner + 1
    }
    int thread = dsl_next_ready_thread(runtime)
    if thread < 0 {
        runtime.halted = dsl_all_threads_terminal(runtime)
        return dsl_step_result {runtime: runtime, thread_id: thread, operation_type: 0, external_request_id: 0, progressed: false, needs_external_result: false}
    }
    int pc = runtime.program_counters[thread]
    if pc < 0 || pc >= runtime.operation_count {
        runtime.thread_statuses[thread] = dsl_thread_halted()
        return dsl_step_result {runtime: runtime, thread_id: thread, operation_type: 0, external_request_id: 0, progressed: true, needs_external_result: false}
    }
    int operation = runtime.operation_types[pc]
    int destination = runtime.destination_variables[pc]
    int a = runtime.argument_a[pc]
    int b = runtime.argument_b[pc]
    runtime.step_count = runtime.step_count + 1
    if operation == dsl_op_generate() || operation == dsl_op_select() {
        runtime.thread_statuses[thread] = dsl_thread_waiting()
        if operation == dsl_op_generate() { runtime.generated_calls = runtime.generated_calls + 1 } else { runtime.select_calls = runtime.select_calls + 1 }
        return dsl_step_result {runtime: runtime, thread_id: thread, operation_type: operation, external_request_id: thread * 100000 + pc + 1, progressed: true, needs_external_result: true}
    }
    if operation == dsl_op_text() || operation == dsl_op_set() { if destination >= 0 && destination < runtime.config.variable_count { runtime.variables[destination] = a } }
    if operation == dsl_op_add() { if destination >= 0 && destination < runtime.config.variable_count && a >= 0 && a < runtime.config.variable_count { runtime.variables[destination] = runtime.variables[a] + b } }
    if operation == dsl_op_jump_if_zero() && a >= 0 && a < runtime.config.variable_count && runtime.variables[a] == 0 {
        runtime.program_counters[thread] = runtime.jump_targets[pc]
        return dsl_step_result {runtime: runtime, thread_id: thread, operation_type: operation, external_request_id: 0, progressed: true, needs_external_result: false}
    }
    if operation == dsl_op_fork() {
        if runtime.thread_count >= runtime.config.maximum_threads {
            runtime.failed = true
            runtime.thread_statuses[thread] = dsl_thread_failed()
        } else {
            int child = runtime.thread_count
            runtime.program_counters[child] = runtime.jump_targets[pc]
            runtime.thread_statuses[child] = dsl_thread_ready()
            runtime.parent_threads[child] = thread + 1
            runtime.thread_count = runtime.thread_count + 1
        }
    }
    if operation == dsl_op_join_sum() {
        int child_index = a
        if child_index >= 0 && child_index < runtime.thread_count && runtime.thread_statuses[child_index] != dsl_thread_halted() {
            runtime.thread_statuses[thread] = dsl_thread_waiting()
            runtime.join_threads[thread] = child_index + 1
            return dsl_step_result {runtime: runtime, thread_id: thread, operation_type: operation, external_request_id: 0, progressed: true, needs_external_result: false}
        }
        if destination >= 0 && destination < runtime.config.variable_count && b >= 0 && b < runtime.config.variable_count { runtime.variables[destination] = runtime.variables[destination] + runtime.variables[b] }
    }
    if operation == dsl_op_halt() { runtime.thread_statuses[thread] = dsl_thread_halted() }
    else { runtime.program_counters[thread] = runtime.program_counters[thread] + 1 }
    runtime.halted = dsl_all_threads_terminal(runtime)
    dsl_step_result {runtime: runtime, thread_id: thread, operation_type: operation, external_request_id: 0, progressed: true, needs_external_result: false}
}

func dsl_resume_external(dsl_program_runtime runtime, int thread_id, int value) dsl_program_runtime {
    if thread_id < 0 || thread_id >= runtime.thread_count || runtime.thread_statuses[thread_id] != dsl_thread_waiting() { return runtime }
    int pc = runtime.program_counters[thread_id]
    int destination = runtime.destination_variables[pc]
    if destination >= 0 && destination < runtime.config.variable_count { runtime.variables[destination] = value }
    runtime.program_counters[thread_id] = pc + 1
    runtime.thread_statuses[thread_id] = dsl_thread_ready()
    runtime
}
