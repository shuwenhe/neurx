package neurx.compilation.executor.execution_plan

use neurx.compilation.ir.graph.computation_graph
use neurx.compilation.ir.operation.operation

struct execution_task {
    int op_id
    operation op
    int[] input_memory_offsets
    int[] output_memory_offsets
    string execution_device
}

struct execution_plan {
    vec[execution_task] tasks
    int total_memory_requirement
    int num_stages
}

struct execution_stage {
    int stage_number
    vec[execution_task] tasks
    int parallel_degree
}

func create_execution_plan(g: &computation_graph) execution_plan {
    tasks = vec[execution_task]()
    
    sorted_ops = g.topological_sort()
    
    for op_idx in sorted_ops {
        op = g.operations[op_idx]
        
        task = execution_task {
            op_id: op.id,
            op: op,
            input_memory_offsets: new int[op.input_ids.len()],
            output_memory_offsets: new int[op.output_ids.len()],
            execution_device: "CPU",
        }
        
        tasks.push(task)
    }
    
    execution_plan {
        tasks: tasks,
        total_memory_requirement: g.total_memory_bytes(),
        num_stages: 1,
    }
}

func (plan: &execution_plan) task_count() int {
    plan.tasks.len()
}

func (plan: &execution_plan) can_parallelize(task_a_idx: int, task_b_idx: int) bool {
    if task_a_idx == task_b_idx {
        return false
    }
    
    if task_a_idx < plan.tasks.len() && task_b_idx < plan.tasks.len() {
        task_a = plan.tasks[task_a_idx]
        task_b = plan.tasks[task_b_idx]
        
        for out_id in task_a.op.output_ids {
            for in_id in task_b.op.input_ids {
                if out_id == in_id {
                    return false
                }
            }
        }
        
        return true
    }
    
    false
}

func (plan: &execution_plan) estimate_execution_time_ms() int {
    int time = 0
    for task in plan.tasks {
        time = time + 10
    }
    time
}

func create_staged_execution_plan(g: &computation_graph, num_stages: int) execution_plan {
    basic_plan = create_execution_plan(g)
    
    if num_stages <= 1 {
        return basic_plan
    }
    
    tasks_per_stage = (basic_plan.tasks.len() + num_stages - 1) / num_stages
    
    basic_plan.num_stages = num_stages
    basic_plan
}

func (plan: &execution_plan) summary_string() string {
    s = ""
    s = s + "Execution Plan Summary\n"
    s = s + "Total tasks: " + plan.task_count() as string + "\n"
    s = s + "Total memory: " + plan.total_memory_requirement as string + " bytes\n"
    s = s + "Stages: " + plan.num_stages as string + "\n"
    s = s + "Estimated time: " + plan.estimate_execution_time_ms() as string + " ms\n"
    s
}
