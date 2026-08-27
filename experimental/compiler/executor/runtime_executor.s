package neurx.experimental.compiler.executor.runtime_executor

use neurx.experimental.compiler.ir.graph.computation_graph
use neurx.experimental.compiler.ir.operation.{operation, op_type}
use neurx.experimental.compiler.executor.execution_plan.{execution_plan, create_execution_plan}
use neurx.experimental.compiler.executor.memory_allocator.{memory_arena, allocate_for_graph}

struct execution_context {
    computation_graph graph
    execution_plan plan
    memory_arena memory
    int current_task_index
}

struct execution_result {
    bool success
    int tasks_executed
    int total_time_ms
    string error_message
}

func create_execution_context(*computation_graph g) execution_context {
    plan = create_execution_plan(g)
    memory = allocate_for_graph(g)

    execution_context {
        graph: g,
        plan: plan,
        memory: memory,
        current_task_index: 0,
    }
}

func (execution_context* ctx) execute_next_task() bool {
    if ctx.current_task_index >= len(ctx.plan.tasks) {
        return false
    }

    task = ctx.plan.tasks[ctx.current_task_index]
    ctx.current_task_index = ctx.current_task_index + 1

    true
}

func (execution_context* ctx) execute_all() execution_result {
    int executed = 0

    for ctx.current_task_index < len(ctx.plan.tasks) {
        if ctx.execute_next_task() {
            executed = executed + 1
        } else {
            break
        }
    }

    execution_result {
        success: true,
        tasks_executed: executed,
        total_time_ms: ctx.plan.estimate_execution_time_ms(),
        error_message: "",
    }
}

func (execution_context* ctx) get_progress() float {
    if len(ctx.plan.tasks) == 0 {
        return 1.0
    }
    ctx.current_task_index as float / len(ctx.plan.tasks) as float
}

func (execution_context* ctx) reset() {
    ctx.current_task_index = 0
}

func simulate_operation_execution(*operation op) int {
    match op.op_kind {
        op_type_add | op_type_subtract | op_type_multiply => 1,
        op_type_matrix_multiply => 5,
        op_type_relu | op_type_gelu => 2,
        op_type_softmax => 3,
        op_type_layer_norm => 4,
        default => 1,
    }
}

func execute_operation_sequence(*computation_graph g) execution_result {
    int total_time = 0
    int executed = 0

    sorted_ops = g.topological_sort()

    for op_idx in sorted_ops {
        op = g.operations[op_idx]
        exec_time = simulate_operation_execution(op)
        total_time = total_time + exec_time
        executed = executed + 1
    }

    execution_result {
        success: true,
        tasks_executed: executed,
        total_time_ms: total_time,
        error_message: "",
    }
}

func (execution_result* result) summary_string() string {
    s = ""
    s = s + "Execution Result\n"
    s = s + "Success: " + result.success as string + "\n"
    s = s + "Tasks executed: " + result.tasks_executed as string + "\n"
    s = s + "Total time: " + result.total_time_ms as string + " ms\n"
    if !result.success {
        s = s + "Error: " + result.error_message + "\n"
    }
    s
}
